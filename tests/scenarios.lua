-- Scenario tests. The plain harness drives the happy path; this drives the
-- states the addon actually has to survive: a class with nothing to give, a
-- dead player, combat lockdown, a client that makes everything secret, a
-- profile full of nonsense, and the modes that disable casting.
--
-- Anything that throws here would, in game, be a silent failure: a timer that
-- stops running, or a prompt that sits there doing nothing.

local dir, extras = ...
local failures = {}
local function fail(scenario, msg) failures[#failures + 1] = scenario .. ": " .. msg end

dofile(dir .. "/tests/mockapi.lua")

local function load(scenario)
	local ns = {}
	for _, file in ipairs({ "Flavour.lua", "Buffs.lua", "Core.lua", "Prompt.lua", "Options.lua" }) do
		local chunk, err = loadfile(dir .. "/" .. file)
		if not chunk then
			fail(scenario, "load " .. file .. ": " .. tostring(err))
			return nil
		end
		local ok, runErr = pcall(chunk, "Manners", ns)
		if not ok then
			fail(scenario, "run " .. file .. ": " .. tostring(runErr))
			return nil
		end
	end
	return ns
end

local function drive(scenario, ns, extra)
	local steps = {
		{ "OnInitialize", function() ns.addon:OnInitialize() end },
		{ "OnEnable", function() ns.addon:OnEnable() end },
		{ "PLAYER_ENTERING_WORLD", function() ns.addon:PLAYER_ENTERING_WORLD() end },
		{ "BuildQueue", function() return ns.BuildQueue() end },
		{ "Tick", function() ns.addon:Tick() end },
		{ "Tick again", function() ns.addon:Tick() end },
		{ "ApplyStyle", function() ns.Prompt:ApplyStyle() end },
		{ "Refresh", function() ns.Prompt:Refresh() end },
		{ "ScanOwnBuffs", function() ns.ScanOwnBuffs() end },
		{ "UNIT_AURA", function() ns.addon:UNIT_AURA(nil, "player") end },
		{ "debug", function() ns.addon:HandleSlash("debug") end },
		{ "PreClick", function()
			local pre = ns.Prompt:GetButton().scripts.PreClick
			if pre then pre(ns.Prompt:GetButton()) end
		end },
		{ "PostClick", function()
			local post = ns.Prompt:GetButton().scripts.PostClick
			if post then post(ns.Prompt:GetButton(), "LeftButton", false) end
		end },
		{ "OnEnter", function()
			local fn = ns.Prompt:GetButton().scripts.OnEnter
			if fn then fn(ns.Prompt:GetButton()) end
		end },
		{ "ToggleTest on", function() ns.Prompt:ToggleTest() end },
		{ "Refresh in test", function() ns.Prompt:Refresh() end },
		{ "ToggleTest off", function() ns.Prompt:ToggleTest() end },
		{ "macro", function() ns.CreateClickMacro() end },
	}
	if extra then table.insert(steps, 1, extra) end
	for _, step in ipairs(steps) do
		local ok, err = pcall(step[2])
		if not ok then fail(scenario, step[1] .. " -> " .. tostring(err)) end
	end
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- ------------------------------------------------------------------ 1
Mock.reset()
local ns = load("baseline")
if ns then drive("baseline", ns) end

-- ------------------------------------------------------------------ 2
-- A class with nothing to cast on anyone else.
Mock.reset()
Mock.class = "ROGUE"
ns = load("rogue")
if ns then drive("rogue", ns) end

-- ------------------------------------------------------------------ 3
-- Dead. Nothing should be offered and nothing should throw.
Mock.reset()
Mock.dead = true
ns = load("dead")
if ns then
	drive("dead", ns)
	if ns.BuildQueue and #ns.BuildQueue() > 0 then fail("dead", "offered somebody while dead") end
end

-- ------------------------------------------------------------------ 4
-- Combat: secure frames are frozen, so nothing may be set.
Mock.reset()
Mock.inCombat = true
ns = load("combat")
if ns then drive("combat", ns) end

-- ------------------------------------------------------------------ 5
-- Everything secret. This client can withhold any of it.
Mock.reset()
Mock.allSecret = true
ns = load("all secret")
if ns then drive("all secret", ns) end

-- ------------------------------------------------------------------ 6
-- Every API missing. An older or stripped client.
Mock.reset()
Mock.stripped = true
ns = load("stripped client")
if ns then drive("stripped client", ns) end

-- ------------------------------------------------------------------ 7
-- A profile full of values no slider could produce.
Mock.reset()
ns = load("garbage profile")
if ns then
	-- The profile only exists once OnInitialize has run, so it is poisoned
	-- after the addon is up and then driven again.
	drive("garbage profile", ns)

	local ok, err = pcall(function()
		local p = ns.db.profile
		p.timing.scanInterval = -5
		p.timing.graceSeconds = "banana"
		p.prompt.width = 0
		p.prompt.height = nil
		p.prompt.fontSize = 9999
		p.prompt.format = ""
		p.prompt.queueRows = 99
		p.filters.whenBuffed = "nonsense"
		p.filters.proximity = "arm's length"
		p.filters.refreshUnder = -1
		p.speech.channel = "NOWHERE"
		p.buff.choice = "does-not-exist"
		p.prompt.style = "chrome"
		p.prompt.accentMode = "everywhere"
		p.prompt.flashStyle = "strobe"
		p.prompt.point = "MIDDLEISH"
		p.prompt.relPoint = 42
		p.prompt.fontColor = "red"
		p.prompt.bgColor = { "a", "b", "c" }
		p.prompt.accentColor = nil
		ns.ClampSettings()
	end)
	if not ok then fail("garbage profile", "clamping threw: " .. tostring(err)) end

	-- and everything has to keep working on the clamped values
	for _, step in ipairs({
		{ "BuildQueue after clamp", function() return ns.BuildQueue() end },
		{ "ApplyStyle after clamp", function() ns.Prompt:ApplyStyle() end },
		{ "Refresh after clamp", function() ns.Prompt:Refresh() end },
		{ "Tick after clamp", function() ns.addon:Tick() end },
		{ "ResolveBuff after clamp", function() return ns.ResolveBuff(true) end },
	}) do
		local stepOk, stepErr = pcall(step[2])
		if not stepOk then fail("garbage profile", step[1] .. " -> " .. tostring(stepErr)) end
	end

	local p = ns.db.profile
	if p.timing.scanInterval < 0.1 then fail("garbage profile", "scanInterval not clamped") end
	if p.prompt.width < 80 then fail("garbage profile", "width not clamped") end
	if type(p.prompt.height) ~= "number" then fail("garbage profile", "height not restored") end
	if p.prompt.format == "" then fail("garbage profile", "empty format not replaced") end
	if p.filters.whenBuffed ~= "skip" then fail("garbage profile", "whenBuffed not reset") end
	-- A distance nothing implements falls through every branch that reads it,
	-- and the one it lands in is "measure nothing" -- so an unrepaired profile
	-- is the noisy queue back again with a setting that says otherwise.
	if p.filters.proximity ~= "near" then
		fail("garbage profile", "proximity not reset, it is " .. tostring(p.filters.proximity))
	end
	if not ns.CHANNEL_COMMANDS[p.speech.channel] then fail("garbage profile", "channel not reset") end
	if p.buff.choice ~= "auto" then fail("garbage profile", "unknown buff choice kept") end
	if p.prompt.style ~= "glass" then fail("garbage profile", "style not reset") end
	if p.prompt.accentMode ~= "icon" then fail("garbage profile", "accentMode not reset") end
	if p.prompt.flashStyle ~= "pulse" then fail("garbage profile", "flashStyle not reset") end
	if p.prompt.point ~= "CENTER" then fail("garbage profile", "anchor not reset") end
	if p.prompt.relPoint ~= "CENTER" then fail("garbage profile", "relative anchor not reset") end
	for _, key in ipairs({ "fontColor", "bgColor", "accentColor" }) do
		local c = p.prompt[key]
		if type(c) ~= "table" or type(c[1]) ~= "number" then
			fail("garbage profile", key .. " not restored to a usable colour")
		end
	end
end

-- ------------------------------------------------------------------ 11
-- A pinned buff belonging to a different class is somebody else's, not nonsense.
--
-- Every character on the account starts on the one shared profile, so a mage's
-- pin is what the priest alt reads as well. It used to be reset to Automatic on
-- the priest's login -- written into the shared profile, so the mage who set it
-- came back to find it gone. The reset stood in for the walk not knowing what a
-- foreign pin means; it means Automatic, and the walk now says so itself.
Mock.reset()
Mock.class = "PRIEST"
local realKnown11, realPlayer11 = IsSpellKnown, IsPlayerSpell
IsSpellKnown = function() return true end
IsPlayerSpell = IsSpellKnown
ns = load("pinned buff from another class")
if ns then
	local scenario = "pinned buff from another class"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.tried)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.buff.choice = "intellect" -- a mage buff, on a priest
	ns.ClampSettings()
	if ns.db.profile.buff.choice ~= "intellect" then
		fail(scenario, "a priest logging in wiped the mage's pin from the profile both"
			.. " of them share: " .. tostring(ns.db.profile.buff.choice))
	end
	local ok, q = pcall(ns.BuildQueue)
	if not ok then
		fail(scenario, "BuildQueue threw: " .. tostring(q))
	elseif not (q[1] and q[1].buff and q[1].buff.class == "PRIEST") then
		fail(scenario, "under another class's pin the priest offered nothing, instead of"
			.. " walking their own list")
	end
	-- And the options page reads it the same way: Automatic, not a blank box.
	local choice = ns.optionsTable and ns.optionsTable.args.who.args.choice
	if choice and choice.get and choice.get({ "choice" }) ~= "auto" then
		fail(scenario, "the dropdown shows " .. tostring(choice.get({ "choice" }))
			.. " for a pin the walk is not honouring")
	end
end
IsSpellKnown, IsPlayerSpell = realKnown11, realPlayer11

-- ------------------------------------------------------------------ 12
-- Names the client could plausibly return, none of which may throw or leak
-- into macro text as something that breaks it.
Mock.reset()
ns = load("odd names")
if ns then
	drive("odd names", ns)
	Mock.advance(60)
	for _, pair in ipairs({
		{ "Petra", "Stonewell" }, { "Petra", "" }, { "Petra", nil },
		{ "Ûmlaut", "Nàme" }, { "A", "B" },
		{ "Nameof", "Averylongsurnamethatgoesonandonandon" },
	}) do
		Mock.unitName = { pair[1], pair[2] }
		Mock.advance(60)
		local entry
		local ok, err = pcall(function()
			local queue = ns.BuildQueue()
			if #queue == 0 then error("no candidates for this name", 0) end
			entry = queue[1]
			ns.Prompt:ApplyTarget(queue[1])
			ns.Prompt:Refresh()
		end)
		if not ok then
			fail("odd names", tostring(pair[1]) .. "/" .. tostring(pair[2]) .. " -> " .. tostring(err))
		end
		-- The macro is legitimately multi-line now (/target, /cast, optional
		-- speech, /targetlasttarget). What matters is that every line is a
		-- real slash command and nothing has been injected between them.
		local macro = ns.lastMacro
		if macro and not macro:find("^%[") then
			local lineCount = 0
			for line in macro:gmatch("[^\r\n]+") do
				lineCount = lineCount + 1
				if not line:find("^/%a") then
					fail("odd names", "macro line is not a command: '" .. line .. "'")
				end
			end
			if lineCount == 0 then fail("odd names", "macro is empty") end
			if #macro > ns.MACRO_LIMIT then
				fail("odd names", "macro over the 255 limit: " .. #macro)
			end
			if not macro:find("/cast ") then
				fail("odd names", "macro does not cast anything")
			end
		end

		-- Exactly one targeting line, whatever shape the name is, and the full
		-- name is what goes in it -- this client joins a surname with a space
		-- and nothing comes off it. Offering the bare first name underneath as
		-- well reads as belt and braces, but /targetlasttarget hands you back
		-- the target the line before last set -- so a second targeting line
		-- makes "restore my target" mean "whoever the first name found", and
		-- two people sharing a first name is all that takes.
		if macro and entry and entry.buff and not entry.buff.selfCast then
			local cmd = ns.TargetCommand()
			local targets = {}
			for line in macro:gmatch("[^\r\n]+") do
				if line:find("^" .. cmd .. " ") then targets[#targets + 1] = line end
			end
			local label = tostring(pair[1]) .. "/" .. tostring(pair[2])
			local full = pair[1] .. ((pair[2] and pair[2] ~= "") and (" " .. pair[2]) or "")
			if #targets ~= 1 then
				fail("odd names", label .. ": " .. #targets .. " " .. cmd .. " lines, not 1")
			elseif targets[1] ~= cmd .. " " .. full then
				fail("odd names", label .. ": the target line is '" .. targets[1] .. "'")
			end
		end
	end
	Mock.unitName = { "Petra", "Stonewell" }
end

-- ------------------------------------------------------------------ 8
-- Unlocked and disabled must never arm the button.
Mock.reset()
ns = load("must not cast")
if ns then
	drive("must not cast", ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()

	ns.db.profile.prompt.locked = false
	ns.Prompt:Refresh()
	local pre = button.scripts.PreClick
	if pre then pcall(pre, button) end
	if button:GetAttribute("type1") ~= nil then
		fail("must not cast", "unlocked prompt armed type1=" .. tostring(button:GetAttribute("type1")))
	end

	-- Off beats unlocked. The unlocked branch used to return first, so
	-- /manners unlock followed by /manners off painted "Drag to move" and put
	-- the button back on screen on the spot, and every tick repainted it.
	ns.db.profile.prompt.locked = false
	ns.db.profile.enabled = true
	ns.Prompt:Refresh()
	if not button:IsShown() then
		fail("must not cast", "the unlocked prompt was never shown, so the next check proves nothing")
	end
	ns.db.profile.enabled = false
	ns.Prompt:Refresh()
	if button:IsShown() then
		fail("must not cast", "a disabled prompt stayed on screen because it was unlocked")
	end

	ns.db.profile.prompt.locked = true
	ns.db.profile.enabled = false
	ns.Prompt:Refresh()
	if pre then pcall(pre, button) end
	if button:GetAttribute("type1") ~= nil then
		fail("must not cast", "disabled prompt armed type1=" .. tostring(button:GetAttribute("type1")))
	end
end

-- ------------------------------------------------------------------ 9
-- Speech must never emit a line that would break the macro.
Mock.reset()
ns = load("speech")
if ns then
	drive("speech", ns)
	ns.db.profile.speech.enabled = true
	ns.db.profile.speech.onlyWhenReturning = false
	ns.db.profile.speech.phrases = table.concat({
		"line with ] bracket",
		"line with | pipe",
		string.rep("x", 400),
		"",
		"   ",
		"good {name} line",
	}, "\n")
	local entry = { short = "Petra Stonewell", name = "Petra Stonewell", reason = "owed",
		buff = ns.FindBuff("MAGE", "intellect") }
	for _ = 1, 60 do
		local ok, phrase = pcall(ns.PickPhrase, entry, 180)
		if not ok then
			fail("speech", "PickPhrase threw: " .. tostring(phrase))
			break
		end
		if phrase then
			if #phrase > 180 then fail("speech", "phrase over budget: " .. #phrase) end
			if phrase:find("[\r\n]") then fail("speech", "phrase contains a newline") end
		end
	end
end

-- ------------------------------------------------------------------ 10
-- A name with a space, which is what this client actually produces.
Mock.reset()
Mock.unitName = { "Petra", "Stonewell" }
ns = load("surnames")
if ns then
	drive("surnames", ns)
	Mock.advance(60)
	local queue = ns.BuildQueue()
	if #queue == 0 then fail("surnames", "SKIPPED -- no candidates to name") end
	if #queue > 0 then
		local got = queue[1].name
		if got ~= "Petra Stonewell" then fail("surnames", "built name '" .. tostring(got) .. "'") end
	end
end

-- ------------------------------------------------------------------ 13
-- An emptied queue must disarm the button. PreClick nils appliedKey and then
-- calls ApplyTarget, so a clear guarded by `appliedKey ~= nil` never ran and
-- the previous person's macro stayed armed -- clicking cast at them.
Mock.reset()
ns = load("emptied queue disarms")
if ns then
	drive("emptied queue disarms", ns)
	local button = ns.Prompt:GetButton()

	-- drive() clicked, which puts that candidate into the retry cooldown.
	Mock.advance(60)

	local queue = ns.BuildQueue()
	-- A scenario that silently skips is worse than no scenario: it reports
	-- green for a check that never ran.
	if #queue == 0 then
		fail("emptied queue disarms", "SKIPPED -- BuildQueue returned nothing to arm")
	end
	if #queue > 0 then
		ns.Prompt:ApplyTarget(queue[1])
		if not button:GetAttribute("macrotext1") and not button:GetAttribute("spell1") then
			fail("emptied queue disarms", "nothing armed for a real candidate")
		end

		-- exactly what PreClick does before handing over an empty queue
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(nil)

		for _, attr in ipairs({ "type1", "macrotext1", "spell1", "unit1",
			"type", "macrotext", "spell", "unit" }) do
			if button:GetAttribute(attr) ~= nil then
				fail("emptied queue disarms",
					attr .. " still set to " .. tostring(button:GetAttribute(attr)))
			end
		end
	end
end

-- ------------------------------------------------------------------ 14
-- The test console: arbitrary macro text, token expansion, unit inspection.
-- These run arbitrary user input through the macro builder, so they are worth
-- driving rather than merely compiling.
Mock.reset()
ns = load("test console")
if ns then
	drive("test console", ns)
	Mock.advance(60)

	local cases = {
		"/cast [@{unit}] {spell}",
		"/target {name}" .. string.char(10) .. "/cast {spell}",
		"/cast {spell}",
		"/cast [@party1] {spell}",
		"{name}{unit}{aim}{first}{spell}{id}",
		"",
	}
	for _, text in ipairs(cases) do
		local ok, err = pcall(function()
			if text ~= "" then
				ns.addon:HandleSlash("try " .. text)
			else
				ns.addon:HandleSlash("try")
			end
			local queue = ns.BuildQueue()
			ns.Prompt:ApplyTarget(queue[1])
			ns.Prompt:Refresh()
		end)
		if not ok then fail("test console", "try '" .. text .. "' -> " .. tostring(err)) end
	end

	ns.addon:HandleSlash("try")
	if ns.tryMacro ~= nil then fail("test console", "bare /manners try did not clear") end

	for _, cmd in ipairs({ "look", "look target", "look nameplate1", "look nosuchunit", "forms" }) do
		local ok, err = pcall(function() ns.addon:HandleSlash(cmd) end)
		if not ok then fail("test console", cmd .. " -> " .. tostring(err)) end
	end

	-- the command word is case-insensitive, the macro text must not be
	ns.addon:HandleSlash("TRY /cast [@Mixed Case Name] Arcane Intellect")
	if not ns.tryMacro or not ns.tryMacro:find("Mixed Case Name") then
		fail("test console", "macro text was mangled: " .. tostring(ns.tryMacro))
	end
	ns.addon:HandleSlash("try")
end

-- ------------------------------------------------------------------ 15
-- Every class, every buff. Only Mage has ever cast in game, so the least that
-- can be done for the rest is to drive their cast path here and check the
-- macro it produces is well formed. Warrior matters most: Battle Shout is
-- selfCast and builds a structurally different macro with no /target at all.
local CLASS_BUFFS = {
	MAGE = { "intellect" },
	PRIEST = { "fortitude", "spirit", "shadow" },
	DRUID = { "motw", "thorns" },
	PALADIN = { "wisdom", "might", "kings", "salvation", "light", "sanctuary" },
	WARLOCK = { "breath" },
	WARRIOR = { "battleshout" },
}

for class, keys in pairs(CLASS_BUFFS) do
	for _, key in ipairs(keys) do
		local label = "cast path " .. class .. "/" .. key

		Mock.reset()
		Mock.class = class
		-- Battle Shout is partyOnly, so the warrior path only exists in a
		-- group. Everything else is tested solo, which is the common case.
		Mock.groupSize = (class == "WARRIOR") and 3 or 0
		local cns = load(label)
		if cns then
			-- Every rank of this buff is known, so the path is reachable.
			local target = cns.FindBuff(class, key)
			if not target then
				fail(label, "buff is not defined for this class")
			else
				local known = {}
				for _, id in ipairs(target.ranks) do known[id] = true end
				local realIsSpellKnown = IsSpellKnown
				IsSpellKnown = function(id) return known[id] == true end
				IsPlayerSpell = function(id) return known[id] == true end

				drive(label, cns)
				Mock.advance(60)

				cns.db.profile.buff.choice = key
				cns.ClampSettings()
				cns.Guard("probe", cns.ProbeCapabilities)

				local queue = cns.BuildQueue()
				if #queue == 0 then
					fail(label, "SKIPPED -- nothing to offer, path never exercised")
				else
					local entry = queue[1]
					if entry.buff.key ~= key then
						fail(label, "resolved to " .. tostring(entry.buff.key) .. " instead")
					end
					cns.Prompt:InvalidateMacro()
					cns.Prompt:ApplyTarget(entry)

					local macro = cns.lastMacro
					if type(macro) ~= "string" or macro == "" then
						fail(label, "no macro was built")
					else
						-- Whichever command the client's probe settled on, so this
						-- reads the macro the addon builds rather than the one
						-- this scenario was written against.
						local cmd = cns.TargetCommand()
						local lineCount, castLine, targetLine = 0, false, false
						local targets = {}
						for line in macro:gmatch("[^\r\n]+") do
							lineCount = lineCount + 1
							if not line:find("^/%a") then
								fail(label, "not a command: '" .. line .. "'")
							end
							if line:find("^/cast ") then castLine = true end
							if line:find("^" .. cmd .. " ") then
								targetLine = true
								targets[#targets + 1] = line
							end
						end
						if not castLine then fail(label, "macro never casts") end
						if #macro > cns.MACRO_LIMIT then
							fail(label, "macro is " .. #macro .. " characters, over the limit")
						end

						-- Battle Shout reaches the party from you; targeting
						-- somebody would be wrong, not merely unnecessary.
						if target.selfCast then
							if targetLine then fail(label, "selfCast buff still built a targeting line") end
							if lineCount ~= 1 then
								fail(label, "selfCast macro should be one line, got " .. lineCount)
							end
						else
							if not targetLine then
								fail(label, "no targeting line for a targeted buff")
							end
							-- Exactly one, carrying the spelling the entry says it
							-- aims at. A second spelling offered alongside it is
							-- what /targetlasttarget costs: it hands back your
							-- PREVIOUS target, which with two targeting lines in
							-- front of it is whoever the first one resolved. And
							-- a bare first name names the wrong player whenever
							-- somebody standing there shares it. Both were tried
							-- and both are gone; this is the check that says so.
							local aim = entry.targetName or entry.name
							if #targets > 1 then
								fail(label, "more than one targeting line: "
									.. table.concat(targets, " | "))
							elseif targets[1] and targets[1] ~= cmd .. " " .. aim then
								fail(label, ("the targeting line does not carry the name it aims"
									.. " at: %s for %s"):format(targets[1], aim))
							end
						end
					end
				end

				IsSpellKnown = realIsSpellKnown
				IsPlayerSpell = realIsSpellKnown
			end
		end
	end
end

-- ------------------------------------------------------------------ 15b
-- A solo warrior has nothing to give: Battle Shout reaches the party and
-- nobody else. Offering a stranger would be a button that does nothing for
-- them. Pinned here so it reads as a decision rather than an accident.
Mock.reset()
Mock.class = "WARRIOR"
Mock.groupSize = 0
ns = load("solo warrior offers nobody")
if ns then
	local known = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("solo warrior offers nobody", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	if #ns.BuildQueue() > 0 then
		fail("solo warrior offers nobody", "offered somebody Battle Shout cannot reach")
	end

	-- and in a party it must work
	Mock.groupSize = 3
	Mock.advance(60)
	if #ns.BuildQueue() == 0 then
		fail("solo warrior offers nobody", "still offers nobody once in a party")
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 16
-- Paladin picks Wisdom for anyone with mana and Might for everyone else. That
-- switch has never run in game either.
Mock.reset()
Mock.class = "PALADIN"
ns = load("paladin auto")
if ns then
	local known = {}
	for _, key in ipairs({ "wisdom", "might" }) do
		for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("paladin auto", ns)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.buff.choice = "auto"

	local withMana = ns.ResolveBuff(true)
	local without = ns.ResolveBuff(false)
	if not withMana or withMana.key ~= "wisdom" then
		fail("paladin auto", "mana user got " .. tostring(withMana and withMana.key))
	end
	if not without or without.key ~= "might" then
		fail("paladin auto", "non-mana user got " .. tostring(without and without.key))
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 17
-- A class with no mana bar must still be offered people. Guarding the whole
-- queue on the player's current mana looked like sensible hardening and meant
-- every warrior was offered nobody, ever -- a whole class silently dead.
Mock.reset()
Mock.class = "WARRIOR"
Mock.groupSize = 3
ns = load("no mana bar still works")
if ns then
	local known = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("no mana bar still works", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	if UnitPowerMax("player") ~= 0 then
		fail("no mana bar still works", "the mock is not simulating a mana-less class")
	end
	if #ns.BuildQueue() == 0 then
		fail("no mana bar still works", "offered nobody despite having a buff to give")
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 18
-- A pinned buff has to survive a login. ClampSettings validates it against
-- caps.class, so running it before the probe reset every pinned choice.
Mock.reset()
ns = load("pinned buff survives login")
if ns then
	drive("pinned buff survives login", ns)
	ns.db.profile.buff.choice = "intellect"

	-- The order OnInitialize uses: probe, then clamp.
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.ClampSettings()
	if ns.db.profile.buff.choice ~= "intellect" then
		fail("pinned buff survives login",
			"reset to " .. tostring(ns.db.profile.buff.choice))
	end

	-- And the fail-safe: if the probe has not run, or failed, caps.class is
	-- nil and nothing is known about which buffs are valid. Clamping must
	-- leave the stored choice alone rather than quietly rewriting it, which
	-- is what happened on every login when the order was the other way round.
	ns.db.profile.buff.choice = "intellect"
	local realClass = ns.caps.class
	ns.caps.class = nil
	ns.ClampSettings()
	ns.caps.class = realClass
	if ns.db.profile.buff.choice ~= "intellect" then
		fail("pinned buff survives login",
			"an unknown class discarded the pinned buff")
	end
end

-- ------------------------------------------------------------------ 19
-- A right-press skips whoever is offered. It must postpone the offer and
-- nothing else: no cast, no settle waiting on a cast that never happened, and
-- above all no repayment -- the debt is still owed to the person skipped.
Mock.reset()
ns = load("a right-press skips without casting")
if ns then
	drive("a right-press skips without casting", ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local queue = ns.BuildQueue()
	if #queue == 0 then
		fail("a right-press skips without casting", "SKIPPED -- nobody to offer")
	else
		ns.Prompt:ApplyTarget(queue[1])
		local name = queue[1].name
		local buffKey = queue[1].buff.key

		-- drive() already clicked once, which left this name blocked and a
		-- settle outstanding. Clear both so what follows measures the
		-- right-press and nothing else.
		ns.tried[name .. "\0" .. buffKey] = nil
		ns.tried[name .. "\0*"] = nil
		ns.pendingClick = nil
		ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
		local clickedAt = ns.lastClickTime

		local post = button.scripts.PostClick
		if post then pcall(post, button, "RightButton", true) end

		if not ns.owed[name] then
			fail("a right-press skips without casting", "a right-press cleared the favour")
		end
		if ns.pendingClick then
			fail("a right-press skips without casting",
				"a right-press left a settle waiting on a cast that never happened")
		end
		if ns.lastClickTime ~= clickedAt then
			fail("a right-press skips without casting",
				"a right-press claimed the next cast failure as ours")
		end
		local blocked = ns.tried[name .. "\0*"]
		if not blocked or blocked <= GetTime() then
			fail("a right-press skips without casting",
				"the offer was not postponed: " .. tostring(blocked))
		end

		-- Skipped, not forgotten. "This one, not now" has to come back once the
		-- retry cooldown is out, or a misclick loses the person for good.
		Mock.advance(60)
		local back = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == name then back = true end
		end
		if not back then
			fail("a right-press skips without casting", "a skipped person never came back")
		end
	end
end

-- ------------------------------------------------------------------ 20
-- Arming the button must leave every other mouse button inert. The unsuffixed
-- type/macrotext are the fallback for all of them, so without this a
-- right-press to turn the camera fires the buff with none of the bookkeeping.
Mock.reset()
ns = load("other mouse buttons are inert")
if ns then
	drive("other mouse buttons are inert", ns)
	Mock.advance(60)
	local queue = ns.BuildQueue()
	if #queue == 0 then
		fail("other mouse buttons are inert", "SKIPPED -- nobody to arm against")
	else
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(queue[1])
		local button = ns.Prompt:GetButton()
		if button:GetAttribute("type1") ~= "macro" then
			fail("other mouse buttons are inert", "the left button was not armed")
		end
		for index = 2, 5 do
			if button:GetAttribute("type" .. index) ~= "none" then
				fail("other mouse buttons are inert",
					"button " .. index .. " is " ..
					tostring(button:GetAttribute("type" .. index)) .. ", not none")
			end
		end
	end
end

-- ------------------------------------------------------------------ 21
-- A priest has three buffs to give and used to offer only the first. Worse,
-- the default "leave them alone if they have it" then dropped the person
-- entirely once they held that one -- so being partly buffed made you
-- invisible to the addon.
Mock.reset()
Mock.class = "PRIEST"
ns = load("priest walks its buff list")
if ns then
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("priest walks its buff list", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local function offered()
		local q = ns.BuildQueue()
		return q[1] and q[1].buff and q[1].buff.key or nil
	end

	-- nothing held: the first in list order
	if offered() ~= "fortitude" then
		fail("priest walks its buff list", "first offer was " .. tostring(offered()))
	end

	-- holding Fortitude must NOT make them invisible; Spirit is next
	Mock.held = {}
    for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do Mock.held[id] = true end
	Mock.advance(10)
	local second = offered()
	if second == nil then
		fail("priest walks its buff list", "a partly buffed player was dropped entirely")
	elseif second ~= "spirit" then
		fail("priest walks its buff list", "expected spirit, got " .. tostring(second))
	end

	-- holding two: the third
	for _, id in ipairs(ns.FindBuff("PRIEST", "spirit").ranks) do Mock.held[id] = true end
	Mock.advance(10)
	if offered() ~= "shadow" then
		fail("priest walks its buff list", "expected shadow, got " .. tostring(offered()))
	end

	-- holding all three: nothing left to give
	for _, id in ipairs(ns.FindBuff("PRIEST", "shadow").ranks) do Mock.held[id] = true end
	Mock.advance(10)
	if offered() ~= nil then
		fail("priest walks its buff list",
			"offered " .. tostring(offered()) .. " to somebody fully buffed")
	end

	Mock.held = nil
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 22
-- Blessings overwrite each other, so a paladin must never walk: holding any
-- one of yours means covered. Offering a second would replace the first.
Mock.reset()
Mock.class = "PALADIN"
ns = load("paladin does not walk")
if ns then
	local known = {}
	for _, key in ipairs({ "wisdom", "might", "kings" }) do
		for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("paladin does not walk", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	if #ns.BuildQueue() == 0 then
		fail("paladin does not walk", "offered nobody with three blessings available")
	end

	-- holding Wisdom means covered: a second blessing would replace it
	Mock.held = {}
	for _, id in ipairs(ns.FindBuff("PALADIN", "wisdom").ranks) do Mock.held[id] = true end
	Mock.advance(10)
	if #ns.BuildQueue() > 0 then
		fail("paladin does not walk",
			"offered a second blessing to somebody already holding one")
	end

	Mock.held = nil
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 23
-- A pin means "only ever this one", so it must not walk either.
Mock.reset()
Mock.class = "PRIEST"
ns = load("a pinned buff does not walk")
if ns then
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("a pinned buff does not walk", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.buff.choice = "spirit"

	local q = ns.BuildQueue()
	if not q[1] or q[1].buff.key ~= "spirit" then
		fail("a pinned buff does not walk",
			"pinned spirit, offered " .. tostring(q[1] and q[1].buff.key))
	end

	-- holding the pinned buff means nothing to offer, not "try another"
	Mock.held = {}
	for _, id in ipairs(ns.FindBuff("PRIEST", "spirit").ranks) do Mock.held[id] = true end
	Mock.advance(10)
	if #ns.BuildQueue() > 0 then
		fail("a pinned buff does not walk", "fell through to another buff")
	end

	Mock.held = nil
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 24
-- The grace-window fallback is the addon's main case: somebody who buffed you
-- in passing and left no unit token behind. It used to resolve one buff for
-- everybody, outside the loop and with mana assumed, so it offered buffs the
-- user had switched off and never consulted a filter at all.
Mock.reset()
Mock.class = "PRIEST"
ns = load("the owed fallback obeys the same filters")
if ns then
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("the owed fallback obeys the same filters", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	ns.db.profile.buff.skip = { fortitude = true }
	-- A name no unit token carries, so only the fallback can queue it.
	ns.owed["Vann Locke"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }

	local found
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == "Vann Locke" then found = entry end
	end

	if not found then
		fail("the owed fallback obeys the same filters",
			"the tokenless favour was not offered at all")
	else
		if found.buff.key ~= "spirit" then
			fail("the owed fallback obeys the same filters",
				"offered " .. tostring(found.buff.key) .. ", which the user switched off")
		end
		if found.class ~= "PRIEST" then
			fail("the owed fallback obeys the same filters",
				"entry carries class " .. tostring(found.class) .. ", so it cannot be coloured")
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 25
-- The same path, judged on the only thing it has: the class captured when the
-- favour arrived. A warrior cannot use Arcane Intellect -- but a class that
-- could not be read must still mean "offer", not "drop".
Mock.reset()
ns = load("the owed fallback reads the source's class")
if ns then
	drive("the owed fallback reads the source's class", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local function offered(name)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == name then return entry end
		end
	end

	ns.owed["Vann Locke"] = { expires = GetTime() + 100, at = GetTime(), class = "WARRIOR" }
	local warrior = offered("Vann Locke")
	if warrior then
		fail("the owed fallback reads the source's class",
			"offered " .. tostring(warrior.buff.key) .. " to a warrior")
	end

	ns.owed["Vann Locke"] = { expires = GetTime() + 100, at = GetTime() }
	if not offered("Vann Locke") then
		fail("the owed fallback reads the source's class",
			"dropped a favour whose class could not be read")
	end
end

-- ------------------------------------------------------------------ 26
-- The fallback can only judge on what was captured at the time, so the class
-- has to be part of the record.
Mock.reset()
Mock.unitClass = "WARRIOR"
ns = load("a favour remembers who gave it")
if ns then
	drive("a favour remembers who gave it", ns)

	wipe(ns.owed)
	Mock.extraAura = true
	ns.addon:UNIT_AURA(nil, "player")

	local name, entry = next(ns.owed)
	if not entry then
		fail("a favour remembers who gave it", "no favour was recorded at all")
	elseif entry.class ~= "WARRIOR" then
		fail("a favour remembers who gave it",
			tostring(name) .. " was recorded with class " .. tostring(entry.class))
	end
	Mock.extraAura = false
end

-- ------------------------------------------------------------------ 27
-- A loading screen can hand back an aura list that is not readable yet, and a
-- baseline taken from that is an empty one: everything already on you then
-- arrives looking like a gift from whoever is standing next to you.
Mock.reset()
ns = load("a loading screen cannot invent favours")
if ns then
	drive("a loading screen cannot invent favours", ns)
	wipe(ns.owed)

	-- Unreadable is not the same as empty.
	Mock.auraBlackout = true
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.auraBlackout = false
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail("a loading screen cannot invent favours",
			"an unreadable aura list invented a favour from " .. tostring(next(ns.owed)))
	end

	-- A zone also renumbers instance ids, which makes the old baseline a list
	-- of ids that will never be seen again.
	wipe(ns.owed)
	Mock.auraIdBase = 500
	ns.addon:PLAYER_ENTERING_WORLD()
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail("a loading screen cannot invent favours",
			"renumbered aura ids invented a favour from " .. tostring(next(ns.owed)))
	end

	-- None of which may cost us a buff that really did arrive.
	wipe(ns.owed)
	Mock.extraAura = true
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail("a loading screen cannot invent favours", "a real favour went unnoticed")
	end

	Mock.extraAura = false
	Mock.auraIdBase = 0
end

-- ------------------------------------------------------------------ 28
-- Speech died silently on any new, copied or reset profile: the backfill only
-- ran at login, and those three arrive through RefreshConfig instead.
Mock.reset()
ns = load("a fresh profile still has phrases")
if ns then
	drive("a fresh profile still has phrases", ns)

	ns.db.profile.speech.phrases = ""
	ns.addon:RefreshConfig()
	if #ns.db.profile.speech.phrases == 0 then
		fail("a fresh profile still has phrases", "the phrase box came back empty")
	end

	ns.db.profile.speech.enabled = true
	local sample = { short = "Vann", name = "Vann Locke", reason = "owed" }
	local line = ns.PickPhrase(sample, ns.PhraseBudget(sample))
	if type(line) ~= "string" or not line:match("^/say ") then
		fail("a fresh profile still has phrases",
			"the macro would go out with no spoken line: " .. tostring(line))
	end

	-- Refilled from the set the dropdown is naming, not a hardcoded one.
	ns.db.profile.speech.presetChoice = "quiet"
	ns.db.profile.speech.phrases = ""
	ns.addon:RefreshConfig()
	if ns.db.profile.speech.phrases ~= ns.PhraseSetText("quiet") then
		fail("a fresh profile still has phrases",
			"refilled with a set the dropdown does not name")
	end
end

-- ------------------------------------------------------------------ 29
-- Nothing recorded here can ever reach the prompt with the source switched
-- off, so recording it promised a prompt that could not appear.
Mock.reset()
ns = load("a source that is off records nothing")
if ns then
	drive("a source that is off records nothing", ns)

	-- The mirror first: a mock that notices nothing would pass the real case
	-- without proving anything.
	wipe(ns.owed)
	ns.db.profile.sources.owed = true
	Mock.extraAura = 3003
	ns.addon:UNIT_AURA(nil, "player")
	local count = 0
	for _ in pairs(ns.owed) do count = count + 1 end
	if count ~= 1 then
		fail("a source that is off records nothing",
			"with the source on, " .. count .. " favours were recorded, not 1")
	end

	wipe(ns.owed)
	ns.db.profile.sources.owed = false
	Mock.extraAura = 3004
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail("a source that is off records nothing",
			"recorded a favour the prompt can never pay back")
	end

	Mock.extraAura = false
end

-- ------------------------------------------------------------------ 30
-- The fallback holds no unit token, so it cannot repeat any of the judgements
-- the main path just made about the same person. Somebody turned down there
-- came straight back through it at priority 1.
Mock.reset()
ns = load("the fallback does not undo a rejection")
if ns then
	drive("the fallback does not undo a rejection", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local function offered(name)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == name then return entry end
		end
	end

	-- Petra Stonewell is level 12 in the mock and holds a unit token, so the
	-- main path can check her age where the fallback never could.
	ns.owed["Petra Stonewell"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
	ns.db.profile.filters.minLevel = 20
	if offered("Petra Stonewell") then
		fail("the fallback does not undo a rejection",
			"offered somebody the level filter had already refused")
	end

	ns.db.profile.filters.minLevel = 1
	Mock.inRange = false
	if offered("Petra Stonewell") then
		fail("the fallback does not undo a rejection",
			"offered somebody the range filter had already refused")
	end
	Mock.inRange = true
end

-- ------------------------------------------------------------------ 31
-- The pulse is a claim that somebody is still owed a buff. Refresh returned at
-- the combat check before anything could withdraw that claim, so a debt that
-- expired or was settled during a fight left the prompt breathing at nobody
-- until the fight ended.
Mock.reset()
ns = load("the pulse stops when the debt does")
if ns then
	drive("the pulse stops when the debt does", ns)
	Mock.advance(60)
	local queue = ns.BuildQueue()
	if #queue == 0 then
		fail("the pulse stops when the debt does", "SKIPPED -- nobody to owe")
	else
		local name = queue[1].name
		ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
		ns.Prompt:Refresh()

		-- The mock cannot see an animation -- IsPlaying is hardcoded false and
		-- SetAlpha does nothing -- so count the calls instead.
		local stops = 0
		local real = ns.Prompt.StopAttention
		ns.Prompt.StopAttention = function(self) stops = stops + 1 return real(self) end

		Mock.inCombat = true
		ns.owed[name] = nil
		ns.Prompt:Refresh()
		if stops == 0 then
			fail("the pulse stops when the debt does",
				"the debt went and the pulse kept breathing through the fight")
		end

		-- And the other way round, or the fix is just a pulse that never runs
		-- in combat -- which is the one place the feature is for.
		ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
		stops = 0
		ns.Prompt:Refresh()
		if stops > 0 then
			fail("the pulse stops when the debt does",
				"stopped the pulse while the favour was still outstanding")
		end

		ns.Prompt.StopAttention = real
		Mock.inCombat = false
	end
end

-- ------------------------------------------------------------------ 32
-- The keybinding is the client's own CLICK form now, so there is no Lua body
-- left to explain an empty prompt -- and a press that does nothing looks
-- exactly like a binding that does not work, which is what this one was.
Mock.reset()
ns = load("a press with nobody on the prompt says so")
if ns then
	drive("a press with nobody on the prompt says so", ns)
	local button = ns.Prompt:GetButton()
	local pre = button.scripts.PreClick

	-- Nobody about. Switching the addon off used to be the cheap way to empty
	-- the prompt, and it is a different answer now: a press while switched off
	-- says so (scenario 236). The fuse keeps a panel up for a moment after the
	-- queue empties, so it is given time to come down.
	local realExists = UnitExists
	UnitExists = function(unit) return unit == "player" end
	wipe(ns.owed)
	ns.Prompt:Refresh()
	Mock.advance(1)
	ns.Prompt:Refresh()
	if button:IsShown() then
		fail("a press with nobody on the prompt says so",
			"the prompt is still on screen, so the next check proves nothing")
	end

	Mock.printed = {}
	-- Past PreClick's own 0.25 s debounce: drive() has already pressed once.
	Mock.advance(1)
	local ok = pcall(pre, button, "LeftButton", true)
	if not ok then
		fail("a press with nobody on the prompt says so", "PreClick threw on an empty prompt")
	end
	local said = false
	for _, line in ipairs(Mock.printed) do
		if line:find("nobody to buff", 1, true) then said = true end
	end
	if not said then
		fail("a press with nobody on the prompt says so", "the press was silent")
	end
	UnitExists = realExists
end

-- ------------------------------------------------------------------ 33
-- LibDBIcon keeps the table it was handed at Register, and AceDB hands out a
-- fresh one per profile: after a switch the checkbox read the new table while
-- the button obeyed -- and a drag saved into -- the old one.
Mock.reset()
ns = load("the minimap button follows the profile")
if ns then
	drive("the minimap button follows the profile", ns)
	if Mock.iconDb ~= ns.db.profile.minimap then
		fail("the minimap button follows the profile",
			"SKIPPED -- the icon was never registered against this profile")
	else
		-- What AceDB's SetProfile does: the old sub-table is stripped and the
		-- new profile is given one of its own.
		ns.db.profile.minimap = { hide = true }
		ns.addon:RefreshConfig()
		if Mock.iconDb ~= ns.db.profile.minimap then
			fail("the minimap button follows the profile",
				"the button is still bound to the old profile's table")
		end
	end
end

-- ------------------------------------------------------------------ 34
-- "Play a sound" defaulted to LibSharedMedia's only sound, "None", whose value
-- is the number 1. PlaySoundFile accepts it and plays nothing, so the toggle
-- did nothing at all and read as a broken addon.
Mock.reset()
ns = load("ticking play a sound makes a sound")
if ns then
	drive("ticking play a sound makes a sound", ns)
	Mock.advance(60)

	if ns.db.profile.sound.file == "None" then
		fail("ticking play a sound makes a sound", "the default sound is the silent one")
	end

	ns.db.profile.sound.enabled = true
	-- This scenario is about the toggle making a noise at all, and the person
	-- the mock puts in the queue is a passer-by. The reason filter defaults on
	-- -- the sound follows the flash now -- so it is switched off here and
	-- proved separately.
	ns.db.profile.sound.owedOnly = false
	if #ns.BuildQueue() == 0 then
		fail("ticking play a sound makes a sound", "SKIPPED -- nobody to announce")
	else
		-- Off then on clears the last top, so the candidate counts as new --
		-- which is what the sound is tied to.
		ns.db.profile.enabled = false
		ns.Prompt:Refresh()
		ns.db.profile.enabled = true
		Mock.sounds = {}
		ns.Prompt:Refresh()
		if #Mock.sounds == 0 then
			fail("ticking play a sound makes a sound", "the toggle is on and nothing was played")
		end
	end

	-- A sound whose pack is not registered -- uninstalled, or simply not loaded
	-- yet. Fetch falls back to "None" for a key it does not know, which is the
	-- same silence again, and the number 1 -- so the addon would "play" a sound
	-- nobody can hear. Ours plays instead.
	--
	-- And the setting is left alone. It used to be rewritten at load, which is
	-- before any pack sorting after this addon has registered anything, so a
	-- sound chosen from SharedMedia or WeakAuras was reset on every login.
	ns.db.profile.sound.file = "Gone With The Addon"
	ns.ClampSettings()
	if ns.db.profile.sound.file ~= "Gone With The Addon" then
		fail("ticking play a sound makes a sound",
			"a sound not registered yet was rewritten to " .. tostring(ns.db.profile.sound.file))
	end
	Mock.sounds = {}
	ns.PlayPromptSound("Gone With The Addon")
	if Mock.sounds[1] ~= ns.SOUND_FILE then
		fail("ticking play a sound makes a sound",
			"played " .. tostring(Mock.sounds[1]) .. " for a sound that is not installed,"
				.. " rather than our own")
	end
	ns.db.profile.sound.file = ns.SOUND_KEY

	-- HashTable maps key -> file and AceConfig labels each item with the value,
	-- so the dropdown listed a single entry called "1".
	--
	-- On the Prompt tab beside the flash setting, not on General: the two are
	-- one job -- getting you to look up -- and being two tabs apart is how they
	-- came to disagree about who is worth interrupting for.
	local panel = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
	local file = panel and panel.args and panel.args.soundFile
	if not (file and file.values) then
		fail("ticking play a sound makes a sound", "SKIPPED -- no sound dropdown to read")
	else
		local values = file.values()
		if values["None"] ~= "None" then
			fail("ticking play a sound makes a sound",
				"the sound dropdown labels None as " .. tostring(values["None"]))
		end

		-- Picking one plays it. Without that the only way to find out a sound
		-- is silent is to wait for somebody to buff you.
		--
		-- Moved off a value it already held, so this reads the control writing
		-- rather than agreeing. The dropdown is on the Prompt tab now under a
		-- key of its own, and a get or set that reads the profile field off
		-- that key instead of naming it is a silent reset for everybody who had
		-- already chosen a sound.
		ns.db.profile.sound.file = "None"
		Mock.sounds = {}
		file.set({ "soundFile" }, ns.SOUND_KEY)
		if ns.db.profile.sound.file ~= ns.SOUND_KEY then
			fail("ticking play a sound makes a sound", "picking a sound did not store it")
		end
		if file.get({ "soundFile" }) ~= ns.SOUND_KEY then
			fail("ticking play a sound makes a sound",
				"the dropdown reads back " .. tostring(file.get({ "soundFile" }))
					.. " for a sound that was just chosen")
		end
		if #Mock.sounds == 0 then
			fail("ticking play a sound makes a sound", "picking a sound played nothing")
		end
	end
end

-- ------------------------------------------------------------------ 35
-- Targeting somebody is the plainest statement of intent there is, and it used
-- to count for nothing: a deliberately chosen stranger ranked "nearby" and lost
-- to every outstanding debt. It outranks them now -- but only on real evidence
-- that they are actually missing the buff.
Mock.reset()
ns = load("your target wins")
if ns then
	-- The mock answers every non-player token with the same name, so without
	-- this they all collapse into one and only the first unit visited -- the
	-- target -- is ever queued, which would prove nothing about ordering.
	local realName = UnitName
	UnitName = function(u)
		if u == "player" then return "Mort", "Defrette" end
		if u == "target" then return "Petra", "Stonewell" end
		return "Yorick", "Vane"
	end

	drive("your target wins", ns)
	-- Past the retry cooldown drive()'s own click wrote.
	Mock.advance(60)

	local function find(queue, name)
		for _, entry in ipairs(queue) do
			if entry.name == name then return entry end
		end
	end

	wipe(ns.owed)
	ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }

	local q = ns.BuildQueue()
	if not q[1] then
		fail("your target wins", "SKIPPED -- nothing was queued at all")
	else
		if q[1].name ~= "Petra Stonewell" or q[1].reason ~= "target" or q[1].priority ~= 0 then
			fail("your target wins", ("the top of the queue was %s/%s/%s, not the target"):format(
				tostring(q[1].name), tostring(q[1].reason), tostring(q[1].priority)))
		end
		-- Outranked, not discarded: the debt is still owed and still on the list.
		if not find(q, "Yorick Vane") then
			fail("your target wins", "the outstanding debt was dropped rather than outranked")
		end
	end

	-- Evidence, not intent: somebody already carrying it is nobody to offer.
	Mock.held = {}
	for _, id in ipairs(ns.FindBuff("MAGE", "intellect").auraIds) do Mock.held[id] = true end
	Mock.advance(10)
	if find(ns.BuildQueue(), "Petra Stonewell") then
		fail("your target wins", "offered the target a buff they are already carrying")
	end

	-- And with the aura check switched off there is no evidence to promote on,
	-- so the target has to stay where an unchecked stranger belongs.
	Mock.held = nil
	ns.db.profile.filters.whenBuffed = "always"
	Mock.advance(10)
	local guessed = find(ns.BuildQueue(), "Petra Stonewell")
	if not guessed then
		fail("your target wins", "SKIPPED -- the target vanished with whenBuffed=always")
	elseif guessed.reason ~= "nearby" or guessed.priority ~= 3 then
		fail("your target wins", ("promoted a guess: %s at priority %s"):format(
			tostring(guessed.reason), tostring(guessed.priority)))
	end
	ns.db.profile.filters.whenBuffed = "skip"

	-- Mouseover is left out on purpose: at a 0.4 s scan the prompt would
	-- flicker as the cursor crossed the screen.
	UnitName = function(u)
		if u == "player" then return "Mort", "Defrette" end
		if u == "target" then return nil end
		return "Yorick", "Vane"
	end
	wipe(ns.owed)
	Mock.advance(10)
	local hovered = find(ns.BuildQueue(), "Yorick Vane")
	if not hovered then
		fail("your target wins", "SKIPPED -- nobody was offered under the cursor")
	elseif hovered.reason ~= "nearby" or hovered.priority ~= 3 then
		fail("your target wins", ("a mouseover was promoted like a target: %s at %s"):format(
			tostring(hovered.reason), tostring(hovered.priority)))
	end

	-- Somebody who both buffed you and happens to be your target keeps the
	-- amber wording and the pulse: the debt is the more specific fact, and the
	-- owed path never reads their auras, so there is no evidence to promote on.
	UnitName = function(u)
		if u == "player" then return "Mort", "Defrette" end
		return "Yorick", "Vane"
	end
	wipe(ns.owed)
	ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }
	Mock.advance(10)
	local both = ns.BuildQueue()
	if not both[1] then
		fail("your target wins", "SKIPPED -- the owed target was not offered")
	elseif both[1].reason ~= "owed" or both[1].priority ~= 1 then
		fail("your target wins", ("an owed target lost the amber wording: %s at %s"):format(
			tostring(both[1].reason), tostring(both[1].priority)))
	end

	wipe(ns.owed)
	UnitName = realName
end

-- ------------------------------------------------------------------ 36
-- A favour used to live only in memory, so a /reload -- the thing this client
-- makes you do constantly -- wiped every debt. The trap is the clock: GetTime()
-- is the machine's uptime, so it starts again near zero after a reboot and a
-- debt stored in those units comes back either already expired or hours long.
-- This models the reboot, the worst case; a plain /reload keeps the uptime.
Mock.reset()
Mock.sv = {}
local a = load("debts survive a reload")
if a then
	drive("debts survive a reload", a)

	wipe(a.owed)
	a.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime(), class = "PRIEST" }
	-- One that will have run out by the time we come back.
	a.owed["Vann Locke"] = { expires = GetTime() + 10, at = GetTime() }
	-- One that was already old when it was written, and whose remaining time is
	-- longer than the window allows -- so both halves of the rebasing have to be
	-- real arithmetic rather than a stamp taken at save time.
	a.owed["Mira Tallow"] = { expires = GetTime() + 300, at = GetTime() - 50 }

	-- Fired the way AceDB fires it, so the wiring is under test and not just
	-- the two functions behind it.
	local shutdown = Mock.dbCallbacks["OnDatabaseShutdown"]
	if not shutdown then
		fail("debts survive a reload", "nothing is listening for the logout flush")
	else
		local ok = pcall(function() shutdown.target[shutdown.method](shutdown.target) end)
		if not ok then fail("debts survive a reload", "the logout flush threw") end
	end

	-- Thirty seconds pass on both clocks, then the computer reboots: the wall
	-- clock carries on and GetTime() begins again near zero.
	Mock.advance(30)
	Mock.now = 5

	local b = load("debts survive a reload")
	if b then
		-- The restore runs in OnInitialize, and drive()'s first Tick sweeps
		-- anything already expired -- so read the table before driving, or a
		-- debt that was wrongly resurrected is tidied away unnoticed.
		if not pcall(function() b.addon:OnInitialize() end) then
			fail("debts survive a reload", "the second session would not initialise")
		end
		if b.owed["Vann Locke"] then
			fail("debts survive a reload", "a debt that ran out while logged off came back")
		end

		drive("debts survive a reload", b)

		local entry = b.owed["Yorick Vane"]
		if not entry then
			fail("debts survive a reload", "the debt did not survive the reload at all")
		else
			local left = entry.expires - GetTime()
			if left < 85 or left > 95 then
				fail("debts survive a reload",
					("the debt came back with %s seconds left, not about 90"):format(
						tostring(math.floor(left))))
			end
			-- `at` matters as much as `expires`: it is what the grace window
			-- reads, and a debt that comes back looking brand new is offered
			-- long after the person has walked away.
			local age = GetTime() - entry.at
			if age < 25 or age > 35 then
				fail("debts survive a reload",
					("the debt came back %s seconds old, not about 30"):format(
						tostring(math.floor(age))))
			end
			if entry.class ~= "PRIEST" then
				fail("debts survive a reload",
					"the class went missing, so the fallback cannot judge what to offer")
			end
		end

		local old = b.owed["Mira Tallow"]
		if not old then
			fail("debts survive a reload", "the older debt did not survive at all")
		else
			-- Clamped to the window as it stands now, so a file written under a
			-- longer one cannot be used to out-wait the current setting -- and
			-- counted from the favour, not from the login: eighty seconds old
			-- against a window of 120 is forty left. It used to come back with
			-- the whole 120, which is the window restarted by a reload.
			local left = old.expires - GetTime()
			if left < 35 or left > 45 then
				fail("debts survive a reload",
					("an over-long debt came back with %s seconds left, not the 40 the window allows")
						:format(tostring(math.floor(left))))
			end
			local age = GetTime() - old.at
			if age < 75 or age > 85 then
				fail("debts survive a reload",
					("a debt that was already 50 seconds old came back %s seconds old, not about 80")
						:format(tostring(math.floor(age))))
			end
		end

		-- And the point of all of it: the restored debt is still offerable,
		-- rather than arriving stale.
		b.db.profile.filters.reachableOnly = true
		b.db.profile.timing.graceSeconds = 45
		local offered = false
		for _, e in ipairs(b.BuildQueue()) do
			if e.name == "Yorick Vane" then offered = true end
		end
		if not offered then
			fail("debts survive a reload", "the restored debt was stale on arrival")
		end

		-- Settling has to be written through too, or a reload undoes work this
		-- session already did.
		b.pendingClick = { name = "Yorick Vane", at = GetTime() }
		b.addon:UNIT_SPELLCAST_SENT(nil, "player", "Yorick Vane", nil, 1459)
		if b.owed["Yorick Vane"] then
			fail("debts survive a reload", "SKIPPED -- the cast did not settle the debt")
		else
			local c = load("debts survive a reload")
			if c then
				if not pcall(function() c.addon:OnInitialize() end) then
					fail("debts survive a reload", "the third session would not initialise")
				end
				if c.owed["Yorick Vane"] then
					fail("debts survive a reload",
						"a debt settled last session came back after the reload")
				end
			end

			-- The client only writes the file at logout, so what is on disk is
			-- always behind what the session has done. Every zone and instance
			-- door fires PLAYER_ENTERING_WORLD, and a restore living there would
			-- read that stale file and raise a debt already dealt with.
			Mock.sv.char.debts = {
				["Yorick Vane"] = { expires = time() + 60, at = time() },
			}
			b.owed["Yorick Vane"] = nil
			b.addon:PLAYER_ENTERING_WORLD()
			if b.owed["Yorick Vane"] then
				fail("debts survive a reload",
					"walking through a door raised a debt out of the last saved file")
			end
		end
	end
end

-- ------------------------------------------------------------------ 37
-- "Something was cast" is not evidence that the favour was returned. A /target
-- the game cannot resolve is a no-op, so the spell lands on whoever you already
-- had; and anything else sitting on a bar can beat the macro's own /cast to the
-- click. Both had the debt marked repaid to somebody who got nothing.
Mock.reset()
ns = load("a cast that missed does not settle the debt")
if ns then
	drive("a cast that missed does not settle the debt", ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local queue = ns.BuildQueue()
	if #queue == 0 then
		fail("a cast that missed does not settle the debt", "SKIPPED -- nobody to arm against")
	else
		local name = queue[1].name
		local buffKey = queue[1].buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]

		-- A clean press each time: past PostClick's own debounce, with both
		-- blocks cleared and the debt standing again.
		local function arm()
			Mock.advance(1)
			ns.tried[name .. "\0" .. buffKey] = nil
			ns.tried[name .. "\0*"] = nil
			ns.pendingClick = nil
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:ApplyTarget(queue[1])
			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail("a cast that missed does not settle the debt",
					"SKIPPED -- the press left nothing to settle")
			end
		end

		arm()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Someone Else", nil, ours)
		if not ns.owed[name] then
			fail("a cast that missed does not settle the debt",
				"a cast that landed on somebody else counted as the favour returned")
		end
		if ns.pendingClick then
			fail("a cast that missed does not settle the debt",
				"the settle was left outstanding after the game had answered")
		end
		local person = ns.tried[name .. "\0*"]
		if not person or person <= GetTime() then
			fail("a cast that missed does not settle the debt",
				"nothing stopped the prompt marching straight down the rest of the list")
		end
		-- PostClick writes the full retry cooldown for a buff it assumes landed.
		-- It did not land, so that block has to be cut back to the same couple
		-- of seconds -- otherwise the buff is off the table for twelve.
		local perBuff = ns.tried[name .. "\0" .. buffKey]
		if not perBuff or perBuff > GetTime() + 3 then
			fail("a cast that missed does not settle the debt",
				("the buff stayed blocked for %s seconds after a cast that never reached them")
					:format(tostring(perBuff and math.floor(perBuff - GetTime()))))
		end

		arm()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, 999999)
		if not ns.owed[name] then
			fail("a cast that missed does not settle the debt",
				"a different spell going out counted as the favour returned")
		end

		-- The mirror, or none of the above proves anything: a cast that really
		-- did reach them has to clear the debt.
		arm()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
		if ns.owed[name] then
			fail("a cast that missed does not settle the debt",
				"a cast that did reach them left the debt standing")
		end

		-- The macro offers the bare first name as well as the full one, so the
		-- game reporting that back is our own cast, not a stranger's.
		arm()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ns.FirstName(name), nil, ours)
		if ns.owed[name] then
			fail("a cast that missed does not settle the debt",
				"the first name the macro itself offers was treated as somebody else")
		end

		-- And a cross-realm suffix is not part of what comes back either.
		local far = name .. "-Ravencrest"
		ns.owed[far] = { expires = GetTime() + 100, at = GetTime() }
		ns.pendingClick = { name = far, at = GetTime(), buffKey = buffKey }
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
		if ns.owed[far] then
			fail("a cast that missed does not settle the debt",
				"the realm suffix made the recipient look like a stranger")
		end

		-- Unverifiable must never mean "never clear the debt": a client that
		-- withholds the target or the spell would otherwise make every favour
		-- permanent, which is worse than the bug.
		arm()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, nil)
		if ns.owed[name] then
			fail("a cast that missed does not settle the debt",
				"a client that would not say who or what made the debt permanent")
		end
	end
end

-- ------------------------------------------------------------------ 38
-- The whole point of keying the block per buff: casting Fortitude has to move
-- the walk along to Divine Spirit, not take the person off the prompt. Nothing
-- pinned that end to end, so re-keying it to the bare name -- which is what it
-- used to be -- went unnoticed by every suite.
Mock.reset()
Mock.class = "PRIEST"
ns = load("a click moves the walk along, not off the person")
if ns then
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive("a click moves the walk along, not off the person", ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local queue = ns.BuildQueue()
	if #queue == 0 or queue[1].buff.key ~= "fortitude" then
		fail("a click moves the walk along, not off the person",
			"SKIPPED -- fortitude was not the first offer")
	else
		local name = queue[1].name
		local button = ns.Prompt:GetButton()
		ns.Prompt:ApplyTarget(queue[1])
		Mock.advance(1)
		-- drive() presses the button itself and leaves that record parked; no
		-- tick has run since, so it is still sitting there a minute later. The
		-- press below would then be abandoning a record as well as making one,
		-- and abandoning one costs the person a two-second block -- which is
		-- correct, and is scenario 46's subject, and is not this one's. One
		-- click, cleanly.
		ns.pendingClick = nil
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end

		local after
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == name then after = entry end
		end
		if not after then
			fail("a click moves the walk along, not off the person",
				"one click took the whole person off the prompt")
		elseif after.buff.key ~= "spirit" then
			fail("a click moves the walk along, not off the person",
				"the next offer was " .. tostring(after.buff.key) .. ", not spirit")
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 39
-- The queue and the favour recorder each had their own copy of "what is this
-- player called", with the same two rejections written out twice. That is how
-- they drifted; one spelling now, and these are the cases it has to get right.
Mock.reset()
ns = load("one spelling of a player's name")
if ns then
	drive("one spelling of a player's name", ns)
	local realName = UnitName

	-- A one-word name: no surname, and above all no trailing space -- a macro
	-- /target with one resolves nothing.
	UnitName = function() return "Solo", "" end
	if ns.UnitFullName("target") ~= "Solo" then
		fail("one spelling of a player's name",
			"an empty surname left '" .. tostring(ns.UnitFullName("target")) .. "'")
	end

	-- The second return is a surname on this client, not a realm, so it joins
	-- with a space. A hyphen invents a name nothing can target.
	UnitName = function() return "Petra", "Stonewell" end
	if ns.UnitFullName("target") ~= "Petra Stonewell" then
		fail("one spelling of a player's name",
			"the surname came back as " .. tostring(ns.UnitFullName("target")))
	end

	-- Names go into macro text, so anything that could break out of it is
	-- refused here rather than by whichever caller happens to remember.
	UnitName = function() return "Bad|Name", "Here" end
	if ns.UnitFullName("target") ~= nil then
		fail("one spelling of a player's name",
			"a name that cannot go into macro text was accepted")
	end

	UnitName = function() return nil, nil end
	if ns.UnitFullName("target") ~= nil then
		fail("one spelling of a player's name", "a name the client withheld was accepted")
	end

	UnitName = realName
end

-- ------------------------------------------------------------------ 40
-- Reading auras is the expensive part of a scan, and the scan runs two and a
-- half times a second. The answers are cached per player, a UNIT_AURA for that
-- player throws the whole player away, and nobody is examined twice in one pass
-- however many tokens the client happens to hold for them.
Mock.reset()
ns = load("the client is asked once, not once per token")
if ns then
	drive("the client is asked once, not once per token", ns)
	Mock.advance(60)
	-- Two nameplates on top of target/mouseover/focus, all the same person.
	ns.nameplateUnits["nameplate1"] = true
	ns.nameplateUnits["nameplate2"] = true

	Mock.counts.auraRead = 0
	ns.BuildQueue()
	local first = Mock.counts.auraRead
	if first == 0 then
		fail("the client is asked once, not once per token",
			"SKIPPED -- no auras were read at all, so nothing here is measured")
	else
		-- A second pass inside the three-second window must ask nothing.
		Mock.counts.auraRead = 0
		ns.BuildQueue()
		if Mock.counts.auraRead > 0 then
			fail("the client is asked once, not once per token",
				Mock.counts.auraRead .. " aura reads on a pass that should have been cached")
		end

		-- Until their auras change, at which point the whole player goes.
		ns.addon:UNIT_AURA(nil, "target")
		Mock.counts.auraRead = 0
		ns.BuildQueue()
		if Mock.counts.auraRead ~= first then
			fail("the client is asked once, not once per token",
				("after UNIT_AURA the re-read was %s calls, not the %s of a cold pass")
					:format(tostring(Mock.counts.auraRead), tostring(first)))
		end
	end

	-- A person turned down is a person judged: the range check and its API
	-- calls must not be paid for again when the next token names them too.
	Mock.advance(10)
	Mock.inRange = false
	ns.db.profile.filters.requireInRange = true
	Mock.counts.range = 0
	ns.BuildQueue()
	if Mock.counts.range == 0 then
		fail("the client is asked once, not once per token",
			"SKIPPED -- the range check never ran")
	elseif Mock.counts.range > 1 then
		fail("the client is asked once, not once per token",
			("one person, five tokens, %s range checks"):format(tostring(Mock.counts.range)))
	end
	Mock.inRange = true
end

-- ------------------------------------------------------------------ 41
-- The prompt repaints two and a half times a second, and the macro it arms is
-- the same one until the person, the buff or the reason changes. Rebuilding it
-- every time also re-rolled the spoken line, so the tooltip never described
-- what a click would actually say. The clear path stays unconditional, which is
-- the half that was once guarded and left an emptied queue armed at the last
-- person -- so both halves are asserted here.
Mock.reset()
ns = load("the macro is armed once per candidate")
if ns then
	drive("the macro is armed once per candidate", ns)
	Mock.advance(60)
	-- Nobody targeted. Every token in the mock is the same person and the
	-- target is walked first, and your own target is never handed back
	-- (scenario 237) -- so the restore setting below would change nothing about
	-- the macro for them, and this is about a setting that does.
	local realExists = UnitExists
	UnitExists = function(unit) if unit == "target" then return false end return realExists(unit) end
	local button = ns.Prompt:GetButton()
	local realSet = button.SetAttribute
	local sets = 0
	button.SetAttribute = function(self, k, v) sets = sets + 1 return realSet(self, k, v) end

	local queue = ns.BuildQueue()
	if #queue == 0 then
		fail("the macro is armed once per candidate", "SKIPPED -- nobody to arm against")
	else
		local name = queue[1].name
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		if sets == 0 then
			fail("the macro is armed once per candidate", "SKIPPED -- nothing was armed at all")
		else
			local armed = button:GetAttribute("macrotext1")
			sets = 0
			ns.Prompt:Refresh()
			if sets > 0 then
				fail("the macro is armed once per candidate",
					sets .. " attribute writes for a candidate that had not changed")
			end
			if button:GetAttribute("macrotext1") ~= armed then
				fail("the macro is armed once per candidate",
					"the armed macro changed underneath an unchanged candidate")
			end

			-- Anything that does change what would go out says so.
			ns.Prompt:InvalidateMacro()
			sets = 0
			ns.Prompt:Refresh()
			if sets == 0 then
				fail("the macro is armed once per candidate",
					"InvalidateMacro did not make the next pass re-arm")
			end

			-- And every setting that alters what the macro says has to invoke
			-- that, now that an unchanged candidate is left alone. Handing your
			-- target back is a line in the macro, not a filter on the queue.
			local function findOption(node, key)
				if type(node) ~= "table" or type(node.args) ~= "table" then return nil end
				for k, v in pairs(node.args) do
					if k == key then return v end
					local found = findOption(v, key)
					if found then return found end
				end
			end

			local option = findOption(ns.optionsTable, "restoreTarget")
			if not (option and option.set) then
				fail("the macro is armed once per candidate",
					"SKIPPED -- no restoreTarget option to toggle")
			else
				local before = button:GetAttribute("macrotext1")
				option.set({ "restoreTarget" }, not ns.db.profile.filters.restoreTarget)
				ns.Prompt:Refresh()
				if button:GetAttribute("macrotext1") == before then
					fail("the macro is armed once per candidate",
						"changing what the macro says left the old one armed")
				end
				option.set({ "restoreTarget" }, true)
				ns.Prompt:Refresh()
			end

			-- And the guarantee the optimisation is most likely to break: an
			-- emptied queue has to disarm the button, not leave the last person
			-- on it. Clicking then cast at somebody nobody was offering.
			ns.BlockPerson(name, 60)
			ns.Prompt:Refresh()
			if #ns.BuildQueue() > 0 then
				fail("the macro is armed once per candidate",
					"SKIPPED -- the queue would not empty")
			elseif button:GetAttribute("macrotext1") ~= nil then
				fail("the macro is armed once per candidate",
					"an emptied queue left a macro armed: "
						.. tostring(button:GetAttribute("macrotext1")))
			end
		end
	end

	button.SetAttribute = realSet
	UnitExists = realExists
end

-- ------------------------------------------------------------------ 42
-- The spoken line used to be measured against a constant 120, with a second
-- and correct length check immediately below it -- two rules for one question,
-- and the options preview quoted the wrong one. There is one rule now, and it
-- is the room the cast lines actually leave.
Mock.reset()
ns = load("the spoken line is measured, not assumed")
if ns then
	drive("the spoken line is measured, not assumed", ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local queue = ns.BuildQueue()
	if #queue == 0 then
		fail("the spoken line is measured, not assumed", "SKIPPED -- nobody to arm against")
	else
		-- Off a nameplate rather than through the target token the mock walks
		-- first: your own target is never handed back (scenario 237), and the
		-- room the hand-back takes is half of what is measured here.
		local entry = {}
		for k, v in pairs(queue[1]) do entry[k] = v end
		entry.unit = "nameplate1"
		ns.db.profile.speech.enabled = true
		ns.db.profile.speech.channel = "SAY"
		-- This candidate is a passer-by, not a debt, so the returning-only
		-- filter would otherwise answer every question here with "no line".
		ns.db.profile.speech.onlyWhenReturning = false
		ns.db.profile.filters.restoreTarget = true

		local budget = ns.PhraseBudget(entry)
		if type(budget) ~= "number" or budget < 10 then
			fail("the spoken line is measured, not assumed",
				"no room at all was left for a spoken line: " .. tostring(budget))
		else
			-- "/say " plus the text is exactly the budget: it must go out, and
			-- the whole macro must still be inside the client's limit.
			local function armWith(text)
				ns.db.profile.speech.phrases = text
				ns.Prompt:InvalidateMacro()
				ns.Prompt:ApplyTarget(entry)
				return button:GetAttribute("macrotext1") or ""
			end

			local exact = armWith(string.rep("x", budget - #"/say "))
			if not exact:find("\n/say ", 1, true) then
				fail("the spoken line is measured, not assumed",
					"a line that fits exactly was dropped")
			end
			if #exact > ns.MACRO_LIMIT then
				fail("the spoken line is measured, not assumed",
					"the macro came out at " .. #exact .. " characters")
			end
			if not exact:find("/targetlasttarget", 1, true) then
				fail("the spoken line is measured, not assumed",
					"the courtesy line crowded out the restore")
			end

			-- One character more and it cannot go, but everything the cast
			-- needs still does.
			local over = armWith(string.rep("x", budget - #"/say " + 1))
			if over:find("/say ", 1, true) then
				fail("the spoken line is measured, not assumed",
					"a line one character too long went out anyway")
			end
			if #over > ns.MACRO_LIMIT then
				fail("the spoken line is measured, not assumed",
					"dropping the line still left " .. #over .. " characters")
			end
			if not (over:find("/cast ", 1, true) and over:find("/targetlasttarget", 1, true)) then
				fail("the spoken line is measured, not assumed",
					"dropping the line took the cast or the restore with it")
			end

			-- Handing your target back costs a line, so it costs the phrase
			-- room too. A budget that ignores it is the old constant again.
			ns.db.profile.filters.restoreTarget = false
			local roomier = ns.PhraseBudget(entry)
			if roomier ~= budget + #"/targetlasttarget" + 1 then
				fail("the spoken line is measured, not assumed",
					("turning the restore off freed %s characters, not %s"):format(
						tostring(roomier - budget), tostring(#"/targetlasttarget" + 1)))
			end
			ns.db.profile.filters.restoreTarget = true

			-- And the preview asks the same function, so it cannot promise a
			-- line the cast path would silently drop.
			local fake = { short = "Somebody", name = "Somebody", reason = "owed",
				buff = entry.buff }
			if ns.PhraseBudget(fake) ~= ns.MACRO_LIMIT
				- #(ns.TargetCommand() .. " Somebody\n/cast " .. ns.BuffName(entry.buff))
				- 1 - #"/targetlasttarget" - 1 then
				fail("the spoken line is measured, not assumed",
					"the preview budget is not the cast path's: " .. tostring(ns.PhraseBudget(fake)))
			end
		end
		ns.db.profile.speech.enabled = false
		ns.db.profile.speech.onlyWhenReturning = true
	end
end

-- ------------------------------------------------------------------ 43
-- The help block and the if/elseif chain were two lists kept in step by hand,
-- which is how "restore" came to be advertised for a release without existing.
-- They are one list now, and every word on it has to reach a real branch.
Mock.reset()
ns = load("every advertised command exists")
if ns then
	drive("every advertised command exists", ns)
	local db = ns.db.profile
	local saved = { enabled = db.enabled, locked = db.prompt.locked,
		restoreTarget = db.filters.restoreTarget, verbose = db.verbose,
		debugClicks = db.debugClicks }

	local function helped()
		for _, line in ipairs(Mock.printed) do
			if line:find("Manners commands:", 1, true) then return true end
		end
		return false
	end

	if #(ns.COMMANDS or {}) == 0 then
		fail("every advertised command exists", "there is no command list to walk")
	end
	for _, command in ipairs(ns.COMMANDS or {}) do
		Mock.printed = {}
		if not pcall(function() ns.addon:HandleSlash(command.word) end) then
			fail("every advertised command exists", command.word .. " threw")
		elseif helped() then
			fail("every advertised command exists",
				command.word .. " is advertised but falls through to the help")
		end
	end

	-- The mirror, or the loop above proves nothing: an unknown word does have
	-- to reach the help.
	Mock.printed = {}
	ns.addon:HandleSlash("nosuchcommand")
	if not helped() then
		fail("every advertised command exists",
			"an unknown command printed no help, so nothing above is measured")
	end

	-- Several of those branches are toggles, and one left the preview running.
	ns.Prompt:ExitTest()
	db.enabled, db.prompt.locked = saved.enabled, saved.locked
	db.filters.restoreTarget, db.verbose, db.debugClicks =
		saved.restoreTarget, saved.verbose, saved.debugClicks
end

-- ------------------------------------------------------------------ 44
-- A failure the addon catches is invisible unless it says so, and one flag for
-- the whole session meant only the first one ever spoke. The list it keeps is
-- read back by /manners errors, and Guard wraps the tick -- so it also has to
-- stop growing.
Mock.reset()
ns = load("every kind of failure gets named once")
if ns then
	drive("every kind of failure gets named once", ns)

	Mock.printed = {}
	ns.Guard("first thing", function() error("boom", 0) end)
	ns.Guard("second thing", function() error("bang", 0) end)
	-- The same label again is not news; saying it every tick would be its own
	-- kind of broken.
	ns.Guard("first thing", function() error("boom", 0) end)

	local said = {}
	for _, line in ipairs(Mock.printed) do
		if line:find("first thing", 1, true) then said.first = (said.first or 0) + 1 end
		if line:find("second thing", 1, true) then said.second = (said.second or 0) + 1 end
	end
	if said.first ~= 1 then
		fail("every kind of failure gets named once",
			"the first failure was announced " .. tostring(said.first) .. " times, not once")
	end
	if said.second ~= 1 then
		fail("every kind of failure gets named once",
			"a second, unrelated failure was never announced at all")
	end

	-- Every one of them is still recorded, up to the cap.
	for i = 1, 60 do
		ns.Guard("noisy " .. i, function() error("again", 0) end)
	end
	if #ns.errors > 30 then
		fail("every kind of failure gets named once",
			#ns.errors .. " errors kept, so the list grows without bound")
	end
	if #ns.errors < 5 then
		fail("every kind of failure gets named once", "the errors were not recorded at all")
	end

	-- And they can be read back, which is the only way to see one that happened
	-- before anybody was looking at chat.
	Mock.printed = {}
	ns.addon:HandleSlash("errors")
	local listed = false
	for _, line in ipairs(Mock.printed) do
		if line:find("noisy 60", 1, true) then listed = true end
	end
	if not listed then
		fail("every kind of failure gets named once", "/manners errors did not list the last one")
	end

	-- The scenario made these on purpose; drive() has already reported the real
	-- ones, and leaving them would fail every later read of this namespace.
	wipe(ns.errors)
end

-- ------------------------------------------------------------------ 45
-- Secure frames cannot be restyled in combat, so ApplyStyle gives up and leaves
-- a flag. Leaving combat then flushed it -- and also walked every texture and
-- font on the panel when nothing had been deferred at all, on every single
-- fight. The flag was written and never read.
Mock.reset()
ns = load("the style is re-applied only when it was put off")
if ns then
	drive("the style is re-applied only when it was put off", ns)

	local applied = 0
	local real = ns.Prompt.ApplyStyle
	ns.Prompt.ApplyStyle = function(self) applied = applied + 1 return real(self) end

	-- Nothing was deferred, so leaving a fight has nothing to flush.
	ns.addon:PLAYER_REGEN_ENABLED()
	if applied > 0 then
		fail("the style is re-applied only when it was put off",
			"restyled the whole panel because a fight ended, not because anything changed")
	end

	-- Something was: a style change arriving under lockdown.
	Mock.inCombat = true
	ns.Prompt:ApplyStyle()
	Mock.inCombat = false
	applied = 0
	ns.addon:PLAYER_REGEN_ENABLED()
	if applied == 0 then
		fail("the style is re-applied only when it was put off",
			"a change made in combat was never applied afterwards")
	end

	-- And it is flushed once, not on every fight from then on.
	applied = 0
	ns.addon:PLAYER_REGEN_ENABLED()
	if applied > 0 then
		fail("the style is re-applied only when it was put off",
			"the deferred flag was never cleared")
	end

	ns.Prompt.ApplyStyle = real
end

-- ------------------------------------------------------------------ 46
-- A click writes a twelve-second cooldown on the buff it assumes went out. When
-- the game refuses the cast outright -- out of range, no line of sight -- that
-- assumption was only unwound on one of the two paths that settle a click. On
-- the other the person was blocked for two seconds and the buff for twelve, so
-- three seconds later the prompt offered them the next buff down the list,
-- which failed the same way, and so on until they had been walked off it.
Mock.reset()
Mock.class = "PRIEST"
ns = load("a refused cast costs one block, not the whole list")
if ns then
	local scenario = "a refused cast costs one block, not the whole list"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local queue = ns.BuildQueue()
	if #queue == 0 or queue[1].buff.key ~= "fortitude" then
		fail(scenario, "SKIPPED -- fortitude was not the first offer")
	else
		local person = queue[1].name
		local button = ns.Prompt:GetButton()
		ns.Prompt:ApplyTarget(queue[1])
		Mock.advance(1)
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end

		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press left nothing to settle")
		else
			-- The game says no. Nothing was cast at all.
			ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.")

			local perBuff = ns.tried[person .. "\0fortitude"]
			if not perBuff or perBuff > GetTime() + 3 then
				fail(scenario, ("fortitude stayed blocked for %s seconds after a cast that never went out")
					:format(tostring(perBuff and math.floor(perBuff - GetTime()))))
			end

			-- Which is the whole point of unwinding it: once the short block on
			-- the person is up they come back with the same buff, rather than
			-- with the next one on a list that is being burned down for them.
			Mock.advance(3)
			local after
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name == person then after = entry end
			end
			if not after then
				fail(scenario, "a refused cast took the person off the prompt entirely")
			elseif after.buff.key ~= "fortitude" then
				fail(scenario, ("the refusal walked them on to %s, which fails the same way")
					:format(tostring(after.buff.key)))
			end
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 47
-- Refusing to take a baseline from a scan that read nothing protects against a
-- loading screen, but "nothing was readable" and "there is nothing to read" are
-- different states: a character holding no buffs at all logs in, stays unprimed
-- because the count was zero, and the first person to buff them -- the one
-- moment any of this exists for -- is silently written to the baseline instead.
Mock.reset()
ns = load("a character with no buffs still sees their first favour")
if ns then
	local scenario = "a character with no buffs still sees their first favour"
	drive(scenario, ns)
	wipe(ns.owed)

	-- Nothing on you, and every slot said so plainly. Twice: one scan saying so
	-- is not enough to take a baseline from, because a client blacking the list
	-- out with plain silence produces the identical reading and there is nothing
	-- in it to tell them apart. The second scan agreeing is what settles it, and
	-- it is the whole price of never having to guess -- one extra UNIT_AURA.
	Mock.noAuras = true
	ns.addon:PLAYER_ENTERING_WORLD()
	ns.addon:UNIT_AURA(nil, "player")
	-- And then somebody buffs you.
	Mock.extraAura = true
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail(scenario, "the first buff to reach an unbuffed character was taken for a baseline")
	end
	Mock.extraAura = false
	Mock.noAuras = false

	-- None of which may cost the protection that gate was reaching for: a list
	-- the client will not show is still not an empty one.
	wipe(ns.owed)
	Mock.auraBlackout = true
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.auraBlackout = false
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail(scenario, "an unreadable aura list invented a favour from " .. tostring(next(ns.owed)))
	end
end

-- ------------------------------------------------------------------ 48
-- Blessings overwrite each other, so the walk stops at the first one and the
-- answer is "are they carrying any of mine". Saying no to that on an aura
-- nobody could read is a guess wearing a verdict's clothes -- and the queue
-- promotes a verified gap on your own target above every debt you owe, so for
-- a paladin that guess outranked somebody who really had buffed you.
Mock.reset()
Mock.class = "PALADIN"
ns = load("a guess never outranks a debt")
if ns then
	local scenario = "a guess never outranks a debt"
	local known = {}
	for _, key in ipairs({ "wisdom", "might" }) do
		for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)

	-- The mirror first, and it is not a formality: a read that really did come
	-- back empty has to say false, and `allRead and false or nil` -- the obvious
	-- way to write that -- is nil either way, which would quietly take the
	-- promotion away from every paladin instead of only the guesses.
	ns.owed["Ysolde Marrow"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
	local readPick, readHas = ns.PickBuffFor(ns.CastableBuffs(), { name = "Somebody" },
		function() return false end)
	if not readPick then
		fail(scenario, "SKIPPED -- no blessing was castable at all")
	elseif readHas ~= false then
		fail(scenario, "an aura that read back empty came back as " .. tostring(readHas))
	end
	local verified = ns.BuildQueue()
	if #verified < 2 then
		fail(scenario, "SKIPPED -- " .. #verified .. " on the queue, so nothing is being ordered")
	elseif verified[1].reason ~= "target" then
		fail(scenario, ("a verified gap on your own target came in as %s, behind the debt")
			:format(tostring(verified[1].reason)))
	end

	-- Auras withheld, people not. Readability is decided once, by the probe, so
	-- making everything secret for the length of it models this client's usual
	-- state without also hiding whoever is standing in front of you.
	Mock.allSecret = true
	ns.Guard("probe", ns.ProbeCapabilities)
	Mock.allSecret = false

	local pick, has = ns.PickBuffFor(ns.CastableBuffs(), { name = "Somebody" },
		function() return nil end)
	if not pick then
		fail(scenario, "SKIPPED -- no blessing was castable at all")
	elseif has ~= nil then
		fail(scenario, "an aura nobody could read came back as " .. tostring(has))
	end

	-- And what claiming otherwise costs, which is the reason it matters.
	local queue = ns.BuildQueue()
	if #queue < 2 then
		fail(scenario, "SKIPPED -- " .. #queue .. " on the queue, so nothing is being ordered")
	elseif queue[1].name ~= "Ysolde Marrow" then
		fail(scenario, ("a guess at %s outranked the debt owed to Ysolde Marrow")
			:format(tostring(queue[1].name)))
	end
	wipe(ns.owed)

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 49
-- When the client will not show a person's auras there is no truth to go on, so
-- the walk rotates past whatever it gave them last. That rotation sat below a
-- loop that returned on anything which was not a hard true, so it could not be
-- reached from it: ns.lastGave was written on every click and read by nothing,
-- and an unreadable class offered the top of its list forever.
Mock.reset()
Mock.class = "PRIEST"
ns = load("an unreadable class is walked through its list")
if ns then
	local scenario = "an unreadable class is walked through its list"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.allSecret = true
	ns.Guard("probe", ns.ProbeCapabilities)
	Mock.allSecret = false
	Mock.advance(60)

	local keys = {}
	for _, buff in ipairs(ns.CastableBuffs()) do keys[#keys + 1] = buff.key end
	local queue = ns.BuildQueue()
	if #queue == 0 or #keys < 2 then
		fail(scenario, "SKIPPED -- " .. #keys .. " buffs and " .. #queue .. " on the queue")
	else
		local person = queue[1].name

		local function offeredNow()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name == person then return entry.buff.key end
			end
		end

		ns.lastGave[person] = keys[1]
		local next1 = offeredNow()
		if next1 == keys[1] then
			fail(scenario, ("%s was offered again straight after being given"):format(tostring(keys[1])))
		end

		-- Round the end of the list rather than off it.
		ns.lastGave[person] = keys[#keys]
		local wrapped = offeredNow()
		if wrapped ~= keys[1] then
			fail(scenario, ("the last buff on the list rotated to %s, not back to %s")
				:format(tostring(wrapped), tostring(keys[1])))
		end

		-- The other half of "no truth to go on" is the mode that says not to
		-- look at all. Auras readable again, so the rotation here can only be
		-- coming from the mode -- and that half was just as unreachable.
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.advance(5)
		ns.db.profile.filters.whenBuffed = "always"
		ns.lastGave[person] = keys[1]
		local anyway = offeredNow()
		if anyway == keys[1] then
			fail(scenario, ("offer-anyway handed back %s straight after giving it")
				:format(tostring(keys[1])))
		end
		ns.db.profile.filters.whenBuffed = "skip"
		ns.lastGave[person] = nil
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 50
-- A unit turned down is remembered, so the tokenless fallback cannot re-add
-- somebody the main path has just judged. Only a judgement about the person
-- counts -- and a value the client withheld is not one. plain() collapses a
-- secret to nil, so testing "not true" filed somebody standing right there
-- under rejected and the grace window then honoured it.
Mock.reset()
ns = load("a withheld answer is not a judgement")
if ns then
	local scenario = "a withheld answer is not a judgement"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)

	local person = ns.UnitFullName("target")
	local realCanAssist = UnitCanAssist
	if not person then
		fail(scenario, "SKIPPED -- the target has no usable name")
	else
		-- They buffed you moments ago, so they were demonstrably within reach.
		ns.owed[person] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }

		local function offered()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name == person then return entry end
			end
		end

		UnitCanAssist = function() return Mock.SECRET end
		local withheld = offered()
		UnitCanAssist = realCanAssist
		if not withheld then
			fail(scenario, "a value the client would not show took somebody off the prompt"
				.. " that the grace window exists to reach")
		end

		-- The mirror, or the flag could simply be deleted: a definite no really
		-- is a judgement, and still has to keep them out of the fallback.
		UnitCanAssist = function() return false end
		local refused = offered()
		UnitCanAssist = realCanAssist
		if refused then
			fail(scenario, "somebody we definitely cannot assist came back through the fallback")
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 51
-- The favour recorder is gated on the source being on, because nothing it
-- writes can reach a prompt that will not offer it. A switched-off addon is the
-- same statement made louder -- Refresh hides the button outright -- and this
-- still wrote the debt to the saved file and said returning it was on a prompt
-- that is not there.
Mock.reset()
ns = load("a switched-off addon records nothing")
if ns then
	local scenario = "a switched-off addon records nothing"
	drive(scenario, ns)
	wipe(ns.owed)

	ns.db.profile.enabled = false
	ns.db.profile.sources.owed = true
	ns.db.profile.verbose = true
	Mock.printed = {}
	Mock.extraAura = 3005
	ns.addon:UNIT_AURA(nil, "player")

	if next(ns.owed) then
		fail(scenario, "recorded a debt while switched off, and wrote it to the saved file")
	end
	for _, line in ipairs(Mock.printed) do
		if line:find("buffed you", 1, true) then
			fail(scenario, "promised a prompt that is not there: " .. line)
		end
	end

	Mock.extraAura = false
	ns.db.profile.enabled = true
end

-- ------------------------------------------------------------------ 52
-- The refresh mode is the only thing that offers somebody a buff they already
-- have, so the tooltip's "missing it" is wrong for exactly those people. How
-- long theirs has left is the answer, and it was read out of the aura, assigned
-- to an upvalue nobody looked at, and returned to a call site that dropped it.
Mock.reset()
ns = load("a top-up says how long is left")
if ns then
	local scenario = "a top-up says how long is left"
	drive(scenario, ns)
	Mock.advance(60)

	local db = ns.db.profile
	db.filters.whenBuffed = "refresh"
	db.filters.refreshUnder = 5
	-- Carrying it with two minutes to run, which is what puts them on the
	-- prompt in this mode and nothing else would.
	Mock.held = { [1459] = true }
	Mock.heldFor = 120

	local queue = ns.BuildQueue()
	local entry = queue[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody was offered a top-up")
	elseif type(entry.remaining) ~= "number" then
		fail(scenario, "the queue entry carries " .. type(entry.remaining)
			.. " where the time left should be")
	elseif math.abs(entry.remaining - 120) > 1 then
		fail(scenario, "the time left came back as " .. tostring(entry.remaining))
	else
		-- And it reaches the player, which is the only reason to carry it.
		local lines = {}
		local realAdd = GameTooltip.AddLine
		GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
		ns.Prompt:ApplyTarget(entry)
		local onEnter = ns.Prompt:GetButton().scripts.OnEnter
		if onEnter then pcall(onEnter, ns.Prompt:GetButton()) end
		GameTooltip.AddLine = realAdd

		local said = false
		for _, line in ipairs(lines) do
			if line:find("expires in 2m", 1, true) then said = true end
		end
		if not said then
			fail(scenario, "the time left never reached the tooltip")
		end
	end

	Mock.held = nil
	Mock.heldFor = nil
	db.filters.whenBuffed = "skip"
end

-- ------------------------------------------------------------------ 53
-- Every way of disarming the prompt -- /manners off, /manners unlock, leaving
-- preview -- comes through ApplyTarget with nil, and it gave up on the first
-- line of a fight. So none of them cleared anything: the button was hidden and
-- went on naming the last person, a CLICK binding still reaches a hidden frame,
-- and the press that followed was filed as a favour returned.
Mock.reset()
ns = load("a disarm in combat is not a no-op")
if ns then
	local scenario = "a disarm in combat is not a no-op"
	drive(scenario, ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local queue = ns.BuildQueue()
	local entry = queue[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		ns.Prompt:ApplyTarget(entry)

		-- The tooltip is the one window onto who the prompt thinks it is
		-- offering: it describes that person and nobody else, and says nothing
		-- at all when there is no one.
		local function describes()
			local lines = {}
			local realAdd, realDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
			GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
			GameTooltip.AddDoubleLine = function(_, a) lines[#lines + 1] = tostring(a) end
			local onEnter = button.scripts.OnEnter
			if onEnter then pcall(onEnter, button) end
			GameTooltip.AddLine, GameTooltip.AddDoubleLine = realAdd, realDouble
			return #lines > 0
		end

		if not describes() then
			fail(scenario, "SKIPPED -- the prompt was not offering anybody to begin with")
		else
			Mock.inCombat = true
			ns.db.profile.verbose = true
			ns.addon:HandleSlash("off")

			if describes() then
				fail(scenario, "a switched-off prompt still named the person it was told to forget")
			end

			-- The half that cannot be fixed, and the reason the other half
			-- matters: secure attributes are frozen, so the macro stays armed
			-- and a keybinding can still fire it.
			if not button:GetAttribute("macrotext1") then
				fail(scenario, "the macro was cleared in combat, which the client does not allow")
			end

			Mock.advance(1)
			ns.pendingClick = nil
			ns.lastGave[name] = nil
			ns.tried[name .. "\0" .. buffKey] = nil
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			Mock.printed = {}
			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end

			if ns.pendingClick or ns.lastGave[name] or ns.tried[name .. "\0" .. buffKey] then
				fail(scenario, "a switched-off addon recorded a cast it never asked for")
			end
			local said = table.concat(Mock.printed, "\n")
			if not said:find("combat", 1, true) then
				fail(scenario, "a buff went out and nothing explained it: " .. said)
			end

			-- And the moment the attributes are writable again, the disarm that
			-- was asked for in the fight actually happens.
			Mock.inCombat = false
			ns.Prompt:Refresh()
			if button:GetAttribute("macrotext1") then
				fail(scenario, "the fight ended and the macro was still armed: "
					.. tostring(button:GetAttribute("macrotext1")))
			end
		end
	end
	ns.db.profile.enabled = true
	Mock.inCombat = false
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 54
-- PostClick had no guard of any kind. Hiding the button was treated as one,
-- and it never was: a CLICK binding is delivered to a hidden frame. /manners
-- unlock does not repaint either, so the gap between unlocking and the next
-- tick is a real four tenths of a second in which the old macro is armed and
-- the key still settles debts.
Mock.reset()
ns = load("a press on a prompt that is not offering records nothing")
if ns then
	local scenario = "a press on a prompt that is not offering records nothing"
	drive(scenario, ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local queue = ns.BuildQueue()
	local entry = queue[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]
		local db = ns.db.profile

		-- The last tick armed the button and named them; then the setting
		-- changed, and the key was pressed before the next tick repainted.
		local function press()
			Mock.advance(1)
			ns.pendingClick = nil
			ns.lastGave[name] = nil
			ns.tried[name .. "\0*"] = nil
			ns.tried[name .. "\0" .. buffKey] = nil
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:ApplyTarget(entry)
			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end
			-- The game answers whatever the macro did. With nothing parked to
			-- settle, that answer has to reach nobody.
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
		end

		local function recorded()
			return ns.pendingClick ~= nil or ns.lastGave[name] ~= nil
				or ns.tried[name .. "\0" .. buffKey] ~= nil or ns.owed[name] == nil
		end

		db.enabled, db.prompt.locked = true, false
		press()
		if recorded() then
			fail(scenario, "an unlocked prompt settled a debt through the keybinding")
		end

		db.enabled, db.prompt.locked = false, true
		press()
		if recorded() then
			fail(scenario, "a switched-off addon settled a debt through the keybinding")
		end

		-- The mirror, or the guard could be a bare return: a working prompt
		-- still has to do all of it.
		db.enabled, db.prompt.locked = true, true
		press()
		if ns.owed[name] then
			fail(scenario, "a press on a working prompt left the debt standing")
		end
		if ns.lastGave[name] ~= buffKey then
			fail(scenario, "a press on a working prompt recorded nothing")
		end
	end
	wipe(ns.owed)
end

-- 55 was the first-name fallback being learned from a run of failed casts. The
-- mechanism is gone -- see the account in Core, above ExpirePendingClick -- and
-- the one thing this scenario checked that was not about it, that the macro
-- carries exactly one /target line spelling the full name, moved into check 15,
-- where it is asserted for every class and buff rather than one.

-- ------------------------------------------------------------------ 56
-- Refresh reads `enabled` before `locked`, which is right -- an unlocked prompt
-- must not outlive /manners off -- but it made unlocking a switched-off addon a
-- silent no-op, while the reply still sent you off to drag something that is
-- not on the screen. Both routes to the setting had the same silence.
Mock.reset()
ns = load("unlocking a switched-off prompt says so")
if ns then
	local scenario = "unlocking a switched-off prompt says so"
	drive(scenario, ns)
	local db = ns.db.profile

	local function unlocking(fn)
		db.prompt.locked = true
		Mock.printed = {}
		fn()
		return table.concat(Mock.printed, "\n")
	end

	db.enabled = false
	local said = unlocking(function() ns.addon:HandleSlash("unlock") end)
	if said:find("drag the prompt", 1, true) then
		fail(scenario, "sent you to drag a prompt that `enabled` keeps off the screen: " .. said)
	end
	if not said:find("/manners on", 1, true) then
		fail(scenario, "said nothing about why nothing happened: " .. said)
	end
	-- The other way out of this was to switch the addon on for you. /manners
	-- off is a decision, and a command about where the prompt sits must not
	-- quietly undo it.
	if db.enabled then
		fail(scenario, "unlocking switched the addon on, which nobody asked it to do")
	end
	if db.prompt.locked then
		fail(scenario, "the unlock itself did not happen")
	end

	-- The mirror: the working case still has to say what to do next.
	db.enabled = true
	said = unlocking(function() ns.addon:HandleSlash("unlock") end)
	if not said:find("drag the prompt", 1, true) then
		fail(scenario, "the working case stopped telling you what to do: " .. said)
	end

	local function findOption(node, key)
		if type(node) ~= "table" or type(node.args) ~= "table" then return nil end
		for k, v in pairs(node.args) do
			if k == key then return v end
			local found = findOption(v, key)
			if found then return found end
		end
	end

	local option = findOption(ns.optionsTable, "locked")
	if not (option and option.set) then
		fail(scenario, "SKIPPED -- no locked option in the panel")
	else
		db.enabled = false
		said = unlocking(function() option.set({ "locked" }, false) end)
		if said == "" then
			fail(scenario, "the panel unlocked a prompt that cannot appear and said nothing")
		end
		db.enabled = true
		said = unlocking(function() option.set({ "locked" }, false) end)
		if said ~= "" then
			fail(scenario, "the panel explains itself when there is nothing to explain: " .. said)
		end
	end

	db.enabled, db.prompt.locked = true, true
end

-- ------------------------------------------------------------------ 57
-- The macro is armed once per candidate, and the memo that decides "same
-- candidate" has to name everything the macro interpolates. A /manners try
-- template can say {unit}, and the token a person is reached through changes
-- under them -- nameplate one tick, party member the next -- so the memo showed
-- and armed an expansion for a token that is no longer theirs.
Mock.reset()
ns = load("the armed macro follows the unit token")
if ns then
	local scenario = "the armed macro follows the unit token"
	drive(scenario, ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local queue = ns.BuildQueue()
	local entry = queue[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		ns.addon:HandleSlash("try /cast [@{unit}] {spell}")
		entry.unit = "target"
		ns.Prompt:ApplyTarget(entry)
		local armed = button:GetAttribute("macrotext1")
		if not armed or not armed:find("@target", 1, true) then
			fail(scenario, "the try template never expanded the unit: " .. tostring(armed))
		else
			-- The same person a moment later, reached through a different
			-- token. Nothing else about them changed, so the unit is the only
			-- thing that can tell the memo the macro is out of date.
			entry.unit = "party2"
			ns.Prompt:ApplyTarget(entry)
			local second = button:GetAttribute("macrotext1")
			if second == armed then
				fail(scenario, "a stale expansion stayed armed: " .. tostring(second))
			elseif not second or not second:find("@party2", 1, true) then
				fail(scenario, "the re-arm did not carry the new token: " .. tostring(second))
			end
		end
		ns.addon:HandleSlash("try")
	end
end

-- ------------------------------------------------------------------ 58
-- The baseline of your own buffs is reused between scans rather than rebuilt,
-- which is the right shape for something that runs on every UNIT_AURA -- but it
-- only stays honest because it is emptied at the top of each scan. Without that
-- it is a record of everything you have ever carried, and the prune below it
-- never removes anything again. Instance ids are recycled -- a zone renumbers
-- them, so they are not unique for all time -- so a buff that fell off and was
-- cast at you again then arrives under a number the list still calls known, and
-- the second favour is silently swallowed.
Mock.reset()
ns = load("the aura baseline forgets what fell off")
if ns then
	local scenario = "the aura baseline forgets what fell off"
	drive(scenario, ns)
	wipe(ns.owed)

	-- Cast at you once. The mirror for everything below: a mock that notices
	-- nothing would pass the real case without proving anything.
	Mock.extraAura = 3100
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail(scenario, "SKIPPED -- the first cast of it was never noticed")
	else
		-- It runs out. Nothing is owed for a buff ending. Two scans see it gone,
		-- which is what it takes for the entry to leave: one scan failing to
		-- find an aura is also exactly what a client refusing the trailing slots
		-- produces, and pruning on that reading is what invented favours out of
		-- the auras it had failed to read. The entry leaves on the second.
		wipe(ns.owed)
		Mock.extraAura = false
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "a buff falling off was recorded as a favour from "
				.. tostring(next(ns.owed)))
		end

		-- And they cast it again, under the id the first one had.
		wipe(ns.owed)
		Mock.extraAura = 3100
		ns.addon:UNIT_AURA(nil, "player")
		if not next(ns.owed) then
			fail(scenario, "a second cast was taken for the one already held")
		end
	end

	Mock.extraAura = false
end

-- ------------------------------------------------------------------ 59
-- The console says, in the file, that whatever it prints also lands in
-- SavedVariables -- which is the only way a session on this client gets read
-- afterwards without somebody transcribing chat out of a screenshot. One line
-- in WriteProbe is the whole of that promise, and nothing has ever checked it
-- was still there.
Mock.reset()
ns = load("what the console printed is on disk")
if ns then
	local scenario = "what the console printed is on disk"
	drive(scenario, ns)

	-- drive() already ran /manners debug, so start from nothing and watch this
	-- one line make the trip.
	MannersDB = nil
	ns.Say("probe line %d", 58)
	local held = false
	for _, line in ipairs(ns.console or {}) do
		if line:find("probe line 58", 1, true) then held = true end
	end
	if not held then
		fail(scenario, "SKIPPED -- the console did not record its own line")
	else
		ns.Guard("WriteProbe", ns.WriteProbe)
		if type(MannersDB) ~= "table" then
			fail(scenario, "the probe wrote nothing at all: " .. tostring(MannersDB))
		elseif not MannersDB.probe then
			fail(scenario, "the capability dump did not reach SavedVariables")
		else
			local saved = false
			for _, line in ipairs(MannersDB.console or {}) do
				if line:find("probe line 58", 1, true) then saved = true end
			end
			if not saved then
				fail(scenario, "the console never reached SavedVariables, so the file"
					.. " promises a log that is not written")
			end
		end
	end

	-- The list is shared rather than copied, on purpose: the file is serialised
	-- at logout, so anything said after the probe ran has to be in it too.
	ns.Say("probe line %d", 59)
	local late = false
	for _, line in ipairs((MannersDB or {}).console or {}) do
		if line:find("probe line 59", 1, true) then late = true end
	end
	if not late then
		fail(scenario, "only what was printed before the probe is kept, so the last"
			.. " thing said before a crash is the thing that is lost")
	end
end

-- ------------------------------------------------------------------ 60
-- A selfCast buff's macro has no /target line and cannot have one: the spell
-- lands on the caster and reaches the party from there. Settling the click by
-- "did it go to the person we offered" therefore had no true answer for it and
-- always read as a miss -- the debt never cleared, the same person came back on
-- the prompt every two seconds, the line announced they were still owed in the
-- moment they had just been buffed, and their name was blamed for a /target
-- that was never in the macro. Battle Shout is the whole of what a warrior has
-- to give, so that was every repayment a warrior can make.
Mock.reset()
Mock.class = "WARRIOR"
-- Battle Shout is partyOnly, so this path only exists in a group.
Mock.groupSize = 3
ns = load("a warrior can repay a favour")
if ns then
	local scenario = "a warrior can repay a favour"
	local known = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local queue = ns.BuildQueue()
	local entry = queue[1]
	if not entry or not entry.buff or not entry.buff.selfCast then
		fail(scenario, "SKIPPED -- Battle Shout was not what came up")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff("WARRIOR", buffKey).ranks[1]
		local button = ns.Prompt:GetButton()

		local function press()
			Mock.advance(1)
			ns.pendingClick = nil
			ns.tried[name .. "\0*"] = nil
			ns.tried[name .. "\0" .. buffKey] = nil
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to settle")
				return false
			end
			return true
		end

		-- The macro has no /target, so the game reports the shout going out on
		-- the player. That is not the person offered and never can be.
		if press() then
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Mort Defrette", nil, ours)
			if ns.owed[name] then
				fail(scenario, "the shout went out and the favour was still counted unpaid,"
					.. " which is every repayment a warrior can make")
			end
			if ns.pendingClick then
				fail(scenario, "the click was left outstanding after the game had answered")
			end
			local person = ns.tried[name .. "\0*"]
			if person and person > GetTime() then
				fail(scenario, "a buff that did go out blocked the person as a failure would")
			end
		end

		-- Being generous about the target must not become generous about the
		-- spell: something else beating the macro's own /cast to the click is
		-- still not the favour returned.
		if press() then
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Mort Defrette", nil, 999999)
			if not ns.owed[name] then
				fail(scenario, "a different spell going out counted as the shout")
			end
		end

		-- And a shout the game refused outright is still a debt.
		if press() then
			ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.")
			if not ns.owed[name] then
				fail(scenario, "a shout that never went out counted as the favour returned")
			end
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 61
-- RewindClick unwinds what a click optimistically wrote when nothing reached
-- the person. It cut both blocks back and left the third thing PostClick writes
-- standing: ns.lastGave, the rotation pointer. On a client that will not show
-- auras that pointer is the only thing moving the walk down somebody's buff
-- list, so a refused cast still marched them off it -- by a second route, and
-- doing exactly what this function exists to prevent.
Mock.reset()
Mock.class = "PRIEST"
ns = load("a refused cast does not move the rotation on")
if ns then
	local scenario = "a refused cast does not move the rotation on"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	-- Auras unreadable, which is the one state the rotation pointer exists for.
	Mock.allSecret = true
	ns.Guard("probe", ns.ProbeCapabilities)
	Mock.allSecret = false
	Mock.advance(60)

	local keys = {}
	for _, buff in ipairs(ns.CastableBuffs()) do keys[#keys + 1] = buff.key end
	local opening = ns.BuildQueue()[1]
	if not opening or not opening.buff or #keys < 2 then
		fail(scenario, "SKIPPED -- " .. #keys .. " buffs and "
			.. (opening and "somebody" or "nobody") .. " on the queue")
	else
		local name = opening.name
		local button = ns.Prompt:GetButton()

		local function offeredNow()
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == name then return e, e.buff.key end
			end
		end

		-- Pin the rotation somewhere known, and take the offer that follows from
		-- it. Anything less and the assertion below cannot tell a pointer that
		-- was put back from one that never moved.
		ns.lastGave[name] = keys[1]
		local entry, buffKey = offeredNow()
		if not entry or buffKey == keys[1] then
			fail(scenario, "SKIPPED -- the rotation did not move off the pinned buff")
		else
			local ours = ns.FindBuff("PRIEST", buffKey).ranks[1]

			local function press()
				Mock.advance(1)
				ns.pendingClick = nil
				ns.lastGave[name] = keys[1]
				ns.tried[name .. "\0*"] = nil
				ns.tried[name .. "\0" .. buffKey] = nil
				ns.Prompt:ApplyTarget(entry)
				local post = button.scripts.PostClick
				if post then pcall(post, button, "LeftButton", true) end
				if not ns.pendingClick then
					fail(scenario, "SKIPPED -- the press left nothing to settle")
					return false
				end
				if ns.lastGave[name] ~= buffKey then
					fail(scenario, "SKIPPED -- the press did not move the rotation pointer")
					return false
				end
				return true
			end

			-- The game says no. Nothing was cast.
			if press() then
				ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.")
				if ns.lastGave[name] ~= keys[1] then
					fail(scenario, ("a cast that never went out still recorded %s as given")
						:format(tostring(ns.lastGave[name])))
				end

				-- Which is the whole point of unwinding it: once the short block
				-- is up they come back with the same buff, rather than with the
				-- next one down a list being burned through for them.
				Mock.advance(3)
				local _, after = offeredNow()
				if after == nil then
					fail(scenario, "a refused cast took the person off the prompt entirely")
				elseif after ~= buffKey then
					fail(scenario, ("the refusal walked them on to %s, which rewinding the"
						.. " cooldown alone could not prevent"):format(tostring(after)))
				end
			end

			-- The mirror, or none of it proves anything: a cast that did go out
			-- has to leave the pointer forward, or nobody is ever walked along
			-- their list at all.
			if press() then
				ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
				if ns.lastGave[name] ~= buffKey then
					fail(scenario, "a cast that went out left the rotation where it was, so an"
						.. " unreadable person is offered the same buff forever")
				end
			end
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 62
-- A right-press is the one instruction the user gives explicitly: not this
-- person, not now. It writes the whole-person block at the full retry cooldown.
-- RewindClick then overwrote that block unconditionally with two seconds, so a
-- pending click still sitting there from a left press a moment earlier settled
-- as failed and cancelled the skip -- and the person who had just been declined
-- was back on the prompt two seconds later.
Mock.reset()
ns = load("a stale click does not cancel a deliberate skip")
if ns then
	local scenario = "a stale click does not cancel a deliberate skip"
	drive(scenario, ns)
	Mock.advance(60)
	local queue = ns.BuildQueue()
	local entry = queue[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		local button = ns.Prompt:GetButton()
		local cooldown = ns.db.profile.timing.retryCooldown

		Mock.advance(1)
		ns.pendingClick = nil
		ns.tried[name .. "\0*"] = nil
		ns.tried[name .. "\0" .. buffKey] = nil
		ns.Prompt:ApplyTarget(entry)

		-- The left press that is about to go unanswered for a moment.
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press left nothing to settle")
		else
			-- And then, inside the two seconds a pending click lives for, the
			-- user decides against this person and says so.
			Mock.advance(0.5)
			if post then pcall(post, button, "RightButton", true) end
			local skip = ns.tried[name .. "\0*"]
			if not skip or skip < GetTime() + cooldown - 1 then
				fail(scenario, "SKIPPED -- the right-press did not write the skip")
			else
				-- Now the game answers the left press: nothing was cast.
				ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.")
				local after = ns.tried[name .. "\0*"]
				if not after or after < GetTime() + cooldown - 2 then
					fail(scenario, ("a stale click cut a deliberate skip back to %s seconds,"
						.. " so the person declined is offered again straight away")
						:format(tostring(after and math.floor(after - GetTime()))))
				end

				-- Which must not become "a failed cast blocks nobody": with no
				-- skip standing, the same rewind still has to write its two
				-- seconds.
				Mock.advance(1)
				ns.pendingClick = nil
				ns.tried[name .. "\0*"] = nil
				ns.tried[name .. "\0" .. buffKey] = nil
				ns.Prompt:ApplyTarget(entry)
				if post then pcall(post, button, "LeftButton", true) end
				ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.")
				local fresh = ns.tried[name .. "\0*"]
				if not fresh or fresh <= GetTime() then
					fail(scenario, "nothing stopped the prompt marching straight down the"
						.. " rest of the list after a cast that went nowhere")
				end
			end
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 63
-- A scan the client only partly refused still pruned the baseline down to the
-- slots it had managed to read, so every aura behind the refusal was dropped --
-- and then announced as a brand-new favour the moment it read back: printed at
-- the player, pulsed at a bystander, and written through to SavedVariables. The
-- flag that knew the client had refused was consulted when deciding whether to
-- prime, and not for the prune it was added to guard.
Mock.reset()
Mock.auraCount = 8
ns = load("a half-refused scan cannot invent favours")
if ns then
	local scenario = "a half-refused scan cannot invent favours"
	drive(scenario, ns)
	wipe(ns.owed)

	-- Three slots in the middle stop reading, with auras the client is still
	-- perfectly willing to show sitting behind them.
	Mock.auraHidden = { [4] = true, [5] = true, [6] = true }
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail(scenario, "a refused scan announced a favour from " .. tostring(next(ns.owed)))
	end
	if ns.auraScan.doubt ~= "refused" then
		fail(scenario, "a withheld slot was not read as a refusal: "
			.. tostring(ns.auraScan.doubt))
	end

	-- And then the client answers again. Nothing about the player changed.
	Mock.auraHidden = nil
	ns.addon:UNIT_AURA(nil, "player")
	if ns.auraScan.doubt then
		fail(scenario, "a list the client answered in full was still not believed: "
			.. tostring(ns.auraScan.doubt))
	end
	if next(ns.owed) then
		fail(scenario, "auras the client had refused came back as invented favours from "
			.. tostring(next(ns.owed)))
	end

	-- The mirror, without which a scan that simply stopped working would pass
	-- everything above: a buff that really does arrive on a readable list is
	-- still a favour.
	wipe(ns.owed)
	Mock.extraAura = 3300
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail(scenario, "SKIPPED -- a real favour on a list nobody refused went unnoticed")
	end

	Mock.extraAura = false
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 64
-- All of 63 again, told by a client that refuses with plain silence rather than
-- a value you are not allowed to look at. Nothing in this repository says which
-- shape this client uses; the fixture was changed to refuse the way the code
-- already expected, which made the suite agree with the code by construction
-- rather than check it. Both shapes are the client saying no, and neither may
-- be read as "there is nothing on you".
Mock.reset()
Mock.refuseWith = "nil"
Mock.auraCount = 8
ns = load("silence is a refusal too")
if ns then
	local scenario = "silence is a refusal too"
	drive(scenario, ns)
	wipe(ns.owed)

	-- The same three slots, refused the other way. The only thing left to tell
	-- it by is the five auras still readable behind the gap.
	Mock.auraHidden = { [4] = true, [5] = true, [6] = true }
	ns.addon:UNIT_AURA(nil, "player")
	if ns.auraScan.doubt ~= "hole" then
		fail(scenario, "silence with five auras behind it was not read as a refusal: "
			.. tostring(ns.auraScan.doubt))
	end
	Mock.auraHidden = nil
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail(scenario, "auras refused as plain nil came back as invented favours from "
			.. tostring(next(ns.owed)))
	end

	-- The same refusal taken to the whole list, mid-session rather than through
	-- a loading screen. Silence at every slot is indistinguishable from an empty
	-- list except for one thing the client did not tell us: the baseline held
	-- eight auras a moment ago, and buffs do not all leave between two frames.
	wipe(ns.owed)
	Mock.auraBlackout = true
	ns.addon:UNIT_AURA(nil, "player")
	if ns.auraScan.doubt ~= "empty" then
		fail(scenario, "a list that went silent while eight auras were on it was not"
			.. " read as a refusal: " .. tostring(ns.auraScan.doubt))
	end
	Mock.auraBlackout = false
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail(scenario, "a silent blackout emptied the baseline and invented a favour from "
			.. tostring(next(ns.owed)))
	end

	-- The mirror again.
	wipe(ns.owed)
	Mock.extraAura = 3400
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail(scenario, "SKIPPED -- a real favour on a list nobody refused went unnoticed")
	end

	Mock.extraAura = false
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 65
-- Doubting a scan is the whole defence above, so it has to end with the scan
-- that had it. A buff that really did run out must still leave the baseline, or
-- the same buff cast at you again is already "known" and the second favour is
-- swallowed -- instance ids are recycled here, so a recast can arrive under the
-- number the old one had. Refusing to prune is only ever allowed to be a delay:
-- a false positive traded for a false negative is not a fix.
Mock.reset()
ns = load("doubt does not outlive the scan that had it")
if ns then
	local scenario = "doubt does not outlive the scan that had it"
	drive(scenario, ns)
	wipe(ns.owed)

	-- Cast at you once, on a list nobody is refusing.
	Mock.extraAura = 3500
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail(scenario, "SKIPPED -- the first cast of it was never noticed")
	else
		-- A slot stops reading, so this scan may not be believed and nothing
		-- leaves the baseline on it.
		wipe(ns.owed)
		Mock.auraHidden = { [2] = true }
		ns.addon:UNIT_AURA(nil, "player")

		-- And while it was not being believed, the buff ran out for real. Two
		-- believed scans have to agree it is gone before the entry leaves -- one
		-- reading without it is indistinguishable from the client refusing that
		-- slot -- so the delay is one UNIT_AURA, and it is a delay rather than a
		-- refusal to prune, which is the whole of what this scenario checks.
		Mock.auraHidden = nil
		Mock.extraAura = false
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "a buff falling off was recorded as a favour from "
				.. tostring(next(ns.owed)))
		end

		-- They cast it at you again, under the id the first one had.
		wipe(ns.owed)
		Mock.extraAura = 3500
		ns.addon:UNIT_AURA(nil, "player")
		if not next(ns.owed) then
			fail(scenario, "a recast after a refused scan was taken for the buff already held")
		end
	end

	Mock.extraAura = false
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 66
-- Refresh mode offers somebody who is holding the buff, and then told them the
-- opposite of the fact it printed underneath: the sub-line said "needs Arcane
-- Intellect", the tooltip said "Nearby and missing it.", and the line added
-- below it said "Theirs expires in 2m." Naming a contradiction is not removing
-- it, and the sub-line is what gets read without hovering. The four reason
-- lines belong to the user, so the top-up needs a line of its own rather than a
-- qualifier bolted onto whatever they typed.
Mock.reset()
ns = load("a top-up is not described as a missing buff")
if ns then
	local scenario = "a top-up is not described as a missing buff"
	drive(scenario, ns)
	Mock.advance(60)
	-- A debt is answered with "offer them anyway", which is a different reason
	-- with different wording and can never be a top-up.
	wipe(ns.owed)

	local db = ns.db.profile
	-- Whatever this user has typed into the reason boxes: the thing a top-up
	-- must neither wear nor overwrite.
	db.prompt.reasonGroup = "WANTS ONE"
	db.prompt.reasonNearby = "WANTS ONE"
	db.prompt.reasonTarget = "WANTS ONE"

	-- Somebody genuinely missing it first, so the customised wording is known
	-- to reach the sub-line at all before anything is claimed about a top-up.
	local missing = ns.BuildQueue()[1]
	if not missing or not missing.buff then
		fail(scenario, "SKIPPED -- nobody was offered anything")
	elseif ns.Prompt:ReasonText(missing) ~= "WANTS ONE" then
		fail(scenario, "SKIPPED -- the customised wording never reached the sub-line: "
			.. tostring(ns.Prompt:ReasonText(missing)))
	else
		db.filters.whenBuffed = "refresh"
		db.filters.refreshUnder = 5
		-- Carrying it with two minutes to run, which is the only thing that
		-- puts a person who already has it on the prompt.
		Mock.held = { [1459] = true }
		Mock.heldFor = 120
		-- Past the aura cache: the queue built a moment ago read them as
		-- missing it and that answer is good for three seconds.
		Mock.advance(4)

		local entry = ns.BuildQueue()[1]
		if not entry or type(entry.remaining) ~= "number" then
			fail(scenario, "SKIPPED -- nobody was offered a top-up")
		else
			local sub = ns.Prompt:ReasonText(entry)
			if sub == "WANTS ONE" then
				fail(scenario, "the sub-line told somebody holding the buff that they want one")
			elseif not sub:find("2m", 1, true) then
				fail(scenario, "the sub-line says nothing true about the top-up: " .. sub)
			end

			-- The tooltip is where the contradiction was printed in full: one
			-- line calling them missing it, the next counting down what they
			-- are carrying.
			local lines = {}
			local realAdd = GameTooltip.AddLine
			GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
			ns.Prompt:ApplyTarget(entry)
			local onEnter = ns.Prompt:GetButton().scripts.OnEnter
			if onEnter then pcall(onEnter, ns.Prompt:GetButton()) end
			GameTooltip.AddLine = realAdd

			local said = table.concat(lines, "\n")
			if said:find("missing it", 1, true) then
				fail(scenario, "the tooltip called somebody holding the buff missing it")
			end
			if not said:find("expires in 2m", 1, true) then
				fail(scenario, "SKIPPED -- the tooltip never described the top-up at all")
			end
		end

		-- The mirror, and it carries two claims at once: a person who really is
		-- missing the buff still gets the user's own wording on the sub-line and
		-- the plain sentence in the tooltip. Deleting both -- the cheapest way
		-- to stop saying something untrue -- passes everything above and fails
		-- here.
		Mock.held = nil
		Mock.heldFor = nil
		db.filters.whenBuffed = "skip"
		Mock.advance(20)
		local again = ns.BuildQueue()[1]
		if not again or again.remaining then
			fail(scenario, "SKIPPED -- nobody was left to be plainly missing it")
		else
			if ns.Prompt:ReasonText(again) ~= "WANTS ONE" then
				fail(scenario, "a missing buff stopped using the wording the user set: "
					.. tostring(ns.Prompt:ReasonText(again)))
			end
			local lines = {}
			local realAdd = GameTooltip.AddLine
			GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
			ns.Prompt:ApplyTarget(again)
			local onEnter = ns.Prompt:GetButton().scripts.OnEnter
			if onEnter then pcall(onEnter, ns.Prompt:GetButton()) end
			GameTooltip.AddLine = realAdd
			if not table.concat(lines, "\n"):find("missing it", 1, true) then
				fail(scenario, "the tooltip stopped saying anything about a buff that really is missing")
			end
		end
	end

	Mock.held = nil
	Mock.heldFor = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 67
-- The click guard refuses the bookkeeping when the addon is off, unlocked or
-- previewing, and explains itself when a macro frozen by combat may have cast
-- anyway. It sits above the right-button branch and said the same thing to a
-- right-press -- which provably cast nothing, because type2 to type5 are
-- "none" and the secure handler matches nothing for them. A warning with no
-- event behind it is the same fault as a sub-line that describes the wrong
-- person.
Mock.reset()
ns = load("a press that cannot cast is not warned about a cast")
if ns then
	local scenario = "a press that cannot cast is not warned about a cast"
	drive(scenario, ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local db = ns.db.profile
		db.verbose = true
		ns.Prompt:ApplyTarget(entry)

		-- The premise, stated rather than assumed: if the other buttons ever
		-- stop being silenced, this scenario has to say so instead of passing.
		if button:GetAttribute("type2") ~= "none" then
			fail(scenario, "SKIPPED -- the right button is no longer silenced, so it could cast: "
				.. tostring(button:GetAttribute("type2")))
		elseif not button:GetAttribute("macrotext1") then
			fail(scenario, "SKIPPED -- the button was never armed")
		else
			-- The fight starts and the prompt is unlocked, so every press from
			-- here is refused -- and the macro cannot be taken off the button
			-- until the fight ends, which is what the warning is about.
			Mock.inCombat = true
			db.prompt.locked = false
			local post = button.scripts.PostClick

			Mock.printed = {}
			if post then pcall(post, button, "RightButton", true) end
			local said = table.concat(Mock.printed, "\n")
			if said:find("may still have cast", 1, true) then
				fail(scenario, "a right-press was warned about a cast the client cannot make from it: "
					.. said)
			end

			-- The mirror: the warning exists for the press that really can cast,
			-- and a guard that simply went quiet would pass everything above.
			Mock.advance(1)
			Mock.printed = {}
			if post then pcall(post, button, "LeftButton", true) end
			said = table.concat(Mock.printed, "\n")
			if not said:find("may still have cast", 1, true) then
				fail(scenario, "a left press on a macro frozen in combat explained nothing: " .. said)
			end
		end
		db.prompt.locked = true
	end
	Mock.inCombat = false
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 68
-- Preview is a disarm like /manners off and /manners unlock, and it was the
-- only one that never healed. Those two re-ask on every pass, so the first pass
-- out of combat clears the attributes for real; the preview branch returned
-- above them. Enter a preview during a fight and the frozen macro stayed armed
-- at a real person for the whole preview after the fight ended, while `current`
-- named nobody -- a keybinding would have cast it.
Mock.reset()
ns = load("a preview entered in a fight lets go of the person")
if ns then
	local scenario = "a preview entered in a fight lets go of the person"
	drive(scenario, ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name = entry.name
		ns.Prompt:ApplyTarget(entry)
		if not button:GetAttribute("macrotext1") then
			fail(scenario, "SKIPPED -- the button was never armed")
		else
			Mock.inCombat = true
			ns.Prompt:ToggleTest()
			if not button:GetAttribute("macrotext1") then
				fail(scenario, "the macro was cleared in combat, which the client does not allow")
			end

			-- Nobody real is waiting, or the preview ends itself and takes the
			-- macro with it. A person inside the retry cooldown their own click
			-- just wrote is exactly how that comes about.
			ns.BlockPerson(name)
			Mock.inCombat = false
			Mock.printed = {}
			ns.Prompt:Refresh()
			local said = table.concat(Mock.printed, "\n")
			if said:find("preview off", 1, true) then
				fail(scenario, "SKIPPED -- the preview ended by itself: " .. said)
			elseif button:GetAttribute("macrotext1") then
				fail(scenario, "the fight ended with a preview still holding a real person's macro: "
					.. tostring(button:GetAttribute("macrotext1")))
			end

			-- The mirror: leaving the preview arms the button again. Without it
			-- a prompt that never casts anything would pass.
			ns.tried[name .. "\0*"] = nil
			ns.Prompt:ToggleTest()
			ns.Prompt:Refresh()
			if not button:GetAttribute("macrotext1") then
				fail(scenario, "the prompt never armed again after the preview")
			end
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 69
-- Blessings overwrite one another, so a paladin must not be walked down the
-- list: the second click takes away what the first gave, on a client that
-- cannot show the auras to notice. ns.lastGave was written for them and never
-- read, which read as a rotation half-built -- but the rotation was already
-- happening by another route, because the per-buff retry cooldown made the
-- blessing just cast ineligible and the next one down was offered four tenths
-- of a second later.
Mock.reset()
Mock.class = "PALADIN"
ns = load("a paladin is not walked off the blessing just given")
if ns then
	local scenario = "a paladin is not walked off the blessing just given"
	local known = {}
	for _, key in ipairs({ "wisdom", "might", "kings" }) do
		for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	wipe(ns.owed)
	-- Auras unreadable: the state a rotation exists for, and the state this
	-- client is in for every stranger.
	Mock.allSecret = true
	ns.Guard("probe", ns.ProbeCapabilities)
	Mock.allSecret = false
	Mock.advance(60)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- no blessing was offered at all")
	else
		local name, first = entry.name, entry.buff.key
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		local function offeredNow(who)
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == (who or name) then return e.buff.key end
			end
		end

		ns.pendingClick = nil
		ns.Prompt:ApplyTarget(entry)
		if post then pcall(post, button, "LeftButton", true) end
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press left nothing behind to judge")
		else
			if ns.lastGave[name] ~= nil then
				fail(scenario, ("a class whose walk never reads the pointer recorded %s in it")
					:format(tostring(ns.lastGave[name])))
			end

			-- The cast went out, as far as anything on this client can tell.
			Mock.advance(1)
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil,
				ns.FindBuff("PALADIN", first).ranks[1])
			if ns.lastGave[name] ~= nil then
				fail(scenario, "settling the click wrote a rotation pointer nothing reads")
			end

			local straightAfter = offeredNow()
			if straightAfter and straightAfter ~= first then
				fail(scenario, ("the blessing just given was answered with an offer of %s,"
					.. " which would take it away again"):format(tostring(straightAfter)))
			end

			-- And when the cooldown lifts it is the same blessing again, rather
			-- than the person having been walked one step down the list.
			Mock.advance(13)
			local later = offeredNow()
			if later == nil then
				fail(scenario, "the person never came back to the prompt at all")
			elseif later ~= first then
				fail(scenario, ("the cooldown lifted on to %s, which is the walk by another name")
					:format(tostring(later)))
			end
		end

		-- The readable client, which is where the same bug was still living.
		--
		-- This used to assert the opposite: a client that says outright they are
		-- carrying none of ours was taken as evidence the cast did not land, so
		-- reaching for the next blessing was right. It is not evidence about the
		-- cast. The aura cache is three seconds deep and the blessing was armed
		-- a fraction of a second ago, so the definite "no" read here is, in the
		-- ordinary case, the reading taken *before* the click -- evidence about
		-- the moment before, spent on the moment after. The carve-out closed the
		-- unreadable route and left this one open, and a paladin was walked off
		-- the blessing just given through it.
		--
		-- So the same rule applies whatever the client says, and the mirror
		-- moves to the thing that must still happen: the cooldown lifting and
		-- the person coming back. That is what stops "a paladin is offered one
		-- blessing and never another" passing everything above.
		--
		-- The other half of the mirror is in scenarios 54 and 61: a class whose
		-- buffs stack still writes ns.lastGave on a click and still rotates on
		-- it, so this cannot be fixed by never writing the table at all.
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.advance(60)
		local readable = ns.BuildQueue()[1]
		if not readable or readable.known ~= false then
			fail(scenario, "SKIPPED -- the readable client never reported an empty aura list")
		else
			local readableKey, who = readable.buff.key, readable.name
			ns.pendingClick = nil
			ns.Prompt:ApplyTarget(readable)
			if post then pcall(post, button, "LeftButton", true) end
			Mock.advance(1)
			local during = offeredNow(who)
			if during and during ~= readableKey then
				fail(scenario, ("a readable client answered the blessing just given with an"
					.. " offer of %s, which replaces it"):format(tostring(during)))
			end

			Mock.advance(13)
			if offeredNow(who) == nil then
				fail(scenario, "the cooldown lifted and the paladin was never offered anything again")
			end
			ns.pendingClick = nil
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 70
-- The loading screen, told in both refusal shapes.
--
-- PLAYER_ENTERING_WORLD wipes the baseline and scans in the same breath, so the
-- baseline is empty and the "we held things a moment ago and now see none" term
-- cannot fire. A client that blacks the list out with plain silence therefore
-- produced a scan that read nothing, doubted nothing, and primed off a list it
-- had never been shown -- and when the list came back, every buff the player
-- was carrying the whole time was announced as a brand-new favour: printed,
-- pulsed at a bystander as an amber priority-1 prompt, and written through to
-- SavedVariables.
--
-- Both shapes are run because neither may be relied on. The withheld value is
-- caught by evidence, the plain nil is caught by nothing at all, and the fix
-- has to be the same fix for both: no baseline from a single scan.
for _, shape in ipairs({ "secret", "nil" }) do
	Mock.reset()
	Mock.refuseWith = shape
	Mock.auraCount = 8
	local scenario = "a loading screen cannot invent a favour (" .. shape .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		wipe(ns.owed)

		-- Through the loading screen: the list is not readable yet, and the
		-- baseline is dropped on the way in because a zone renumbers every
		-- instance id.
		Mock.auraBlackout = true
		ns.addon:PLAYER_ENTERING_WORLD()
		Mock.auraBlackout = false

		-- The list reads back. Eight auras, all of them already on the player
		-- before the zone change, none of them a favour.
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "buffs the player was already carrying were announced as a favour from "
				.. tostring(next(ns.owed)))
		end
		-- And the scan that agrees with it, which is the one allowed to settle
		-- the baseline. It must settle it silently.
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "the scan that settled the baseline announced a favour from "
				.. tostring(next(ns.owed)))
		end

		-- The mirror, and it is the reason the delay is a delay: a buff that
		-- really does land after all that is still a favour. Curing the false
		-- positive by never noticing anything again would pass everything above.
		wipe(ns.owed)
		Mock.extraAura = 3600
		ns.addon:UNIT_AURA(nil, "player")
		if not next(ns.owed) then
			fail(scenario, "SKIPPED -- a real favour after the loading screen went unnoticed")
		end

		Mock.extraAura = false
		wipe(ns.owed)
	end
end

-- ------------------------------------------------------------------ 71
-- A refusal of the trailing slots, told in both shapes.
--
-- Slots seven and eight stop reading on a list of eight, and slot nine is the
-- end of the list either way -- so there is no readable aura sitting behind the
-- silence and the "hole" evidence has nothing to find. The scan then pruned
-- precisely the two auras it had failed to read, and announced both of them as
-- brand-new favours the moment the client answered in full again.
--
-- The withheld shape is caught outright and the silent one is not, which is the
-- whole argument for not recognising refusals: the same bug, wearing the other
-- set of clothes, walks straight past the check written for it.
for _, shape in ipairs({ "secret", "nil" }) do
	Mock.reset()
	Mock.refuseWith = shape
	Mock.auraCount = 8
	local scenario = "a refusal at the end of the list cannot invent favours (" .. shape .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		wipe(ns.owed)

		Mock.auraHidden = { [7] = true, [8] = true }
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "a list cut short at the end announced a favour from "
				.. tostring(next(ns.owed)))
		end

		-- The client answers in full again. Nothing about the player changed
		-- between the two scans, so nobody did the player a favour.
		Mock.auraHidden = nil
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "the two auras behind the refusal came back as invented favours from "
				.. tostring(next(ns.owed)))
		end

		-- The mirror.
		wipe(ns.owed)
		Mock.extraAura = 3700
		ns.addon:UNIT_AURA(nil, "player")
		if not next(ns.owed) then
			fail(scenario, "SKIPPED -- a real favour on a list nobody refused went unnoticed")
		end

		Mock.extraAura = false
		wipe(ns.owed)
	end
end

-- ------------------------------------------------------------------ 72
-- Corroboration has one cost, and it is stated in the file: a refusal that
-- repeats is corroborated by its own repetition. Two scans agreeing the player
-- holds nothing is exactly what a player holding nothing looks like, and there
-- is no reading of the client that separates them.
--
-- For the shapes that can be recognised, though, it need not cost that, and it
-- does not -- which is the remaining job of the evidence the scan collects, and
-- the reason it stops the scan dead rather than only being recorded for
-- /manners debug. A scan the client refused outright is not merely disbelieved:
-- it never becomes one of the two readings at all, so a blackout can last as
-- long as it likes without ever agreeing with itself. Nothing checked that, and
-- the short-circuit is one line to lose in a tidy-up.
--
-- The withheld shape only. A client that refuses with plain silence gives this
-- scan nothing to recognise, so the same sequence really is indistinguishable
-- from a player standing there with no buffs on -- that is the residue, and
-- pretending to check it here would be checking a guess.
Mock.reset()
Mock.refuseWith = "secret"
Mock.auraCount = 8
ns = load("a refusal cannot corroborate itself")
if ns then
	local scenario = "a refusal cannot corroborate itself"
	drive(scenario, ns)
	wipe(ns.owed)

	-- Held across three scans, which is two more than it takes for two readings
	-- to agree with each other.
	Mock.auraBlackout = true
	for _ = 1, 3 do ns.addon:UNIT_AURA(nil, "player") end
	if ns.auraScan.doubt ~= "refused" then
		fail(scenario, "SKIPPED -- the blackout was not recognised at all: "
			.. tostring(ns.auraScan.doubt))
	end

	-- And the list comes back, unchanged, with the same eight auras on it.
	Mock.auraBlackout = false
	ns.addon:UNIT_AURA(nil, "player")
	if next(ns.owed) then
		fail(scenario, "a blackout long enough to agree with itself emptied the baseline"
			.. " and invented a favour from " .. tostring(next(ns.owed)))
	end

	-- The mirror.
	wipe(ns.owed)
	Mock.extraAura = 3800
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail(scenario, "SKIPPED -- a real favour after the blackout lifted went unnoticed")
	end

	Mock.extraAura = false
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 73
-- The aura line in /manners debug exists for one failure: the scan giving up
-- for good without saying so, which from the prompt is indistinguishable from
-- nobody ever buffing you. It could not see that failure. The scan returns when
-- C_UnitAuras.GetAuraDataByIndex is missing, and it did so above every write to
-- ns.auraScan -- so the command printed the same untroubled "0 read, baseline
-- 0" for a scanner that had never run once as for one running fine and finding
-- nothing.
Mock.reset()
Mock.noAuraScanner = true
ns = load("debug can see a scanner that never ran")
if ns then
	local scenario = "debug can see a scanner that never ran"
	drive(scenario, ns)

	Mock.printed = {}
	ns.addon:HandleSlash("debug")
	local said = table.concat(Mock.printed, "\n")
	if said:find("own buffs: 0 read, baseline 0", 1, true) then
		fail(scenario, "debug printed the untroubled line for a scan that never ran at all")
	end
	if not said:find("no aura api", 1, true) then
		fail(scenario, "debug never named the missing API the scan gave up on: " .. said)
	end
end

-- The mirror, without which deleting the untroubled line altogether would pass:
-- a client that has the API and a scan that settled must not be reported broken.
Mock.reset()
ns = load("debug does not cry wolf about a working scanner")
if ns then
	local scenario = "debug does not cry wolf about a working scanner"
	drive(scenario, ns)

	Mock.printed = {}
	ns.addon:HandleSlash("debug")
	local said = table.concat(Mock.printed, "\n")
	if said:find("not believed", 1, true) or said:find("not settled", 1, true) then
		fail(scenario, "a scanner that is reading the list fine was reported as broken: " .. said)
	end
	if not said:find("own buffs: 2 read, baseline 2", 1, true) then
		fail(scenario, "SKIPPED -- debug never described a settled scan at all: " .. said)
	end
end

-- ------------------------------------------------------------------ 74
-- The policy and the reading, told apart.
--
-- Owing somebody means offering them even when they are covered, which is a
-- decision about who deserves an offer. It used to be expressed by answering
-- the aura question on the client's behalf -- false, for every buff, without
-- asking -- and PickBuffFor read that fabricated false as the client stating
-- outright that nothing had landed. For a paladin that is the difference
-- between refreshing the blessing somebody is carrying and replacing it: the
-- walk stepped past the one they held, because it had been told they held
-- nothing, and offered the next one down.
Mock.reset()
Mock.class = "PALADIN"
ns = load("a debt does not walk a paladin off the blessing they hold")
if ns then
	local scenario = "a debt does not walk a paladin off the blessing they hold"
	local known = {}
	for _, key in ipairs({ "might", "wisdom", "kings" }) do
		for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	wipe(ns.owed)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local candidates = ns.CastableBuffs()
	local first = ns.BuildQueue()[1]
	if #candidates < 2 or not first or not first.buff then
		fail(scenario, "SKIPPED -- fewer than two blessings were castable at anybody")
	else
		local name = first.name
		-- Deliberately not the one at the top of the list. Holding the first
		-- blessing would let "offer them the first thing" pass by coincidence,
		-- and that is exactly the wrong answer being measured.
		local held = candidates[2]
		Mock.held = {}
		for _, id in ipairs(held.ranks) do Mock.held[id] = true end

		local function offeredFor(who)
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == who then return e end
			end
		end

		-- Covered, and nobody owes them anything: the exclusivity rule stands
		-- untouched. Asserted first, because everything below is an exception
		-- to it and an exception to nothing proves nothing.
		wipe(ns.tried)
		Mock.advance(5)
		local uninvited = offeredFor(name)
		if uninvited then
			fail(scenario, ("somebody carrying a blessing was offered %s with no favour"
				.. " outstanding"):format(tostring(uninvited.buff.key)))
		end

		-- Now they have done us a favour. They are offered -- and what they are
		-- offered is the blessing they are already carrying, which is a refresh
		-- and takes nothing away.
		ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		wipe(ns.tried)
		Mock.advance(5)
		local offered = offeredFor(name)
		if not offered then
			fail(scenario, "a person we owe was dropped from the prompt for being buffed")
		elseif offered.buff.key ~= held.key then
			fail(scenario, ("a debt was answered with %s over the top of the %s they are"
				.. " carrying, which takes it away"):format(tostring(offered.buff.key), held.key))
		elseif offered.known ~= true then
			fail(scenario, ("the queue reported %s for an aura the client answered outright")
				:format(tostring(offered.known)))
		end

		-- The mirror, and without it "never offer anybody anything" passes: the
		-- debt still has to reach the prompt when they are carrying nothing.
		Mock.held = nil
		wipe(ns.tried)
		Mock.advance(5)
		local bare = offeredFor(name)
		if not bare then
			fail(scenario, "a person we owe who is carrying nothing was not offered a blessing")
		elseif bare.known ~= false then
			fail(scenario, ("an empty aura list came back to the queue as %s")
				:format(tostring(bare.known)))
		end
	end

	Mock.held = nil
	wipe(ns.owed)
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 75
-- One pending slot, and nothing on it saying which press it belongs to.
--
-- A second press inside the settle window used to overwrite the first record
-- without a word, so what that press had written on the assumption of success
-- -- the per-buff cooldown and the rotation pointer -- was left standing with
-- nothing left that could ever take it back. PostClick's quarter-second
-- debounce is no help: three tenths of a second apart is two full records.
--
-- Matching events to records would need identity the client does not give us,
-- so the rule is the other one: a record is never discarded silently. It is
-- settled as an unknown outcome first -- rewound, debt left standing, nothing
-- filed about the name -- and only then is the new one parked.
Mock.reset()
Mock.class = "PRIEST"
ns = load("a second press does not bury the first")
if ns then
	local scenario = "a second press does not bury the first"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	wipe(ns.owed)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	-- Two people, which needs one of them to be somebody we hold no unit token
	-- for: every unit the mock offers answers to the same name.
	local absent = "Mort Defrette"
	ns.owed[absent] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
	local here, gone
	for _, e in ipairs(ns.BuildQueue()) do
		if e.name == absent then gone = e elseif not here then here = e end
	end
	if not gone or not here or not gone.buff or not here.buff then
		fail(scenario, "SKIPPED -- could not get two different people onto one queue")
	else
		ns.owed[here.name] = { expires = GetTime() + 100, at = GetTime() }
		local firstKey = gone.buff.key
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		local cooldown = ns.db.profile.timing.retryCooldown

		ns.pendingClick = nil
		wipe(ns.tried)
		ns.lastGave[absent] = nil

		-- The press that is about to go unanswered.
		ns.Prompt:ApplyTarget(gone)
		if post then pcall(post, button, "LeftButton", true) end
		if not ns.pendingClick or ns.pendingClick.name ~= absent then
			fail(scenario, "SKIPPED -- the first press parked nothing for that person")
		else
			if ns.lastGave[absent] ~= firstKey then
				fail(scenario, "SKIPPED -- the first press did not move the rotation pointer")
			end

			-- Three tenths of a second later, which is past the debounce and
			-- well inside the window the game is allowed to answer in.
			Mock.advance(0.3)
			ns.Prompt:ApplyTarget(here)
			if post then pcall(post, button, "LeftButton", true) end

			if ns.pendingClick and ns.pendingClick.name ~= here.name then
				fail(scenario, "SKIPPED -- the second press did not take the slot")
			end
			if ns.lastGave[absent] ~= nil then
				fail(scenario, ("the buried press left %s standing as given to somebody the"
					.. " game never answered about"):format(tostring(ns.lastGave[absent])))
			end
			local perBuff = ns.tried[absent .. "\0" .. firstKey]
			if perBuff and perBuff > GetTime() + cooldown - 3 then
				fail(scenario, ("the buried press left %s blocked for %s seconds on the"
					.. " assumption it landed"):format(firstKey,
					tostring(math.floor(perBuff - GetTime()))))
			end
			if not ns.owed[absent] then
				fail(scenario, "a press the game never answered was counted as the favour returned")
			end

			-- The mirror: burying the old record must not cost the new one its
			-- settle, or the fix is "clicking twice repays nobody".
			local ours = ns.FindBuff("PRIEST", here.buff.key).ranks[1]
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", here.name, nil, ours)
			if ns.owed[here.name] then
				fail(scenario, "the second press was parked and then never settled")
			end
		end
	end

	ns.pendingClick = nil
	wipe(ns.owed)
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 76
-- UI_ERROR_MESSAGE carries every complaint the game makes -- a full bag, an
-- item not ready, a spell somebody else fumbled -- and nothing tests that the
-- one that arrived has anything to do with our cast. It settled the pending
-- click outright and threw the record away, so the cast that really did go out
-- a frame later had nothing left to settle and the favour stayed owed.
--
-- The record is parked instead, and the error takes back only what the click
-- wrote on the assumption it landed. Which leaves the other half: a cast
-- arriving after the doubt has to put those writes back, or the rewind outlives
-- the reason for it and a buff that was delivered is offered again two seconds
-- later.
Mock.reset()
ns = load("an unrelated error does not throw the record away")
if ns then
	local scenario = "an unrelated error does not throw the record away"
	drive(scenario, ns)
	Mock.advance(60)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		local cooldown = ns.db.profile.timing.retryCooldown

		local function press()
			Mock.advance(1)
			ns.pendingClick = nil
			wipe(ns.tried)
			ns.lastGave[name] = nil
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:ApplyTarget(entry)
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to settle")
				return false
			end
			return true
		end

		-- Twice, because the record surviving one error proves nothing about the
		-- second: this used to get worse with every error, not better.
		for _ = 1, 2 do
			if press() then
				ns.addon:UI_ERROR_MESSAGE(nil, nil, "Your bags are full.")
				-- And the cast goes out regardless, because the error was
				-- somebody else's problem.
				ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
				if ns.owed[name] then
					fail(scenario, "an error the game raised about something else threw away the"
						.. " record, so the cast that did go out repaid nobody")
				end
			end
		end

		-- And the writes the error took back are back, because the cast it was
		-- doubting turned up. The error cuts the per-buff cooldown to two seconds
		-- and puts the rotation pointer where the press found it -- correct while
		-- nothing is known, and a lie the moment the game says the spell went out.
		-- Nothing restored either, so the person who had just been buffed was back
		-- on the prompt with the same buff two seconds later.
		if press() then
			ns.addon:UI_ERROR_MESSAGE(nil, nil, "Your bags are full.")
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
			local held = ns.tried[name .. "\0" .. buffKey]
			if not held or held < GetTime() + cooldown - 3 then
				fail(scenario, ("a buff that went out was left blocked for %s seconds, so the"
					.. " prompt offers it again"):format(
					tostring(held and math.floor(held - GetTime()) or "no")))
			end
			if ns.RotatesBuffs() and ns.lastGave[name] ~= buffKey then
				fail(scenario, ("a buff that went out left the rotation pointer at %s, where the"
					.. " error had put it back"):format(tostring(ns.lastGave[name])))
			end
		end
	end

	ns.pendingClick = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 77
-- This client usually will not say who a spell went to, so plain(target) is nil
-- for the ordinary case rather than the odd one. That nil was read as "nothing
-- contradicting who it went to" and the debt was cleared -- which makes any
-- cast of the offered buff inside two seconds of a click a repayment, whoever
-- it actually reached.
--
-- Refusing to settle on it is worse: on a client that never names a recipient
-- every favour becomes permanent. So the inference is carried by the one thing
-- that genuinely connects the press to the person -- the macro having had a
-- /target of ours in it, aimed at them, recorded when it was armed. A macro
-- that aimed at nobody carries nothing, and /manners try is exactly that shape.
Mock.reset()
ns = load("an unattributed cast settles only what the macro aimed at")
if ns then
	local scenario = "an unattributed cast settles only what the macro aimed at"
	drive(scenario, ns)
	Mock.advance(60)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick

		local function press()
			Mock.advance(1)
			ns.pendingClick = nil
			wipe(ns.tried)
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to settle")
				return false
			end
			return true
		end

		-- A macro this addon did not write. It casts, and it aims at nobody we
		-- chose, so a spell going out under it says nothing about this person.
		ns.addon:HandleSlash("try /cast {spell}")
		if press() then
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, ours)
			if not ns.owed[name] then
				fail(scenario, "a cast the client would not attribute, under a macro that aimed"
					.. " at nobody, was counted as the favour returned")
			end
		end
		ns.addon:HandleSlash("try")

		-- The mirror, and it is the case that matters most: our own macro, our
		-- own /target line, our own spell -- and a client that will not say who
		-- received it. Settling on that is an inference and the addon makes it,
		-- because the alternative is a debt that can never be repaid.
		if press() then
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, ours)
			if ns.owed[name] then
				fail(scenario, "a client that would not name the recipient made the favour"
					.. " permanent, which is worse than the bug")
			end
		end
	end

	ns.pendingClick = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 78
-- The four reason lines and the name format are free text somebody types into
-- the options, and they were being handed to gsub as *replacements*, where % is
-- an escape rather than a character. "10% left" in the top-up wording is a
-- natural thing to write and it threw from inside the substitution -- on every
-- repaint, two and a half times a second, which is a prompt that stops dead
-- mid-fight and a chat window full of the same error.
Mock.reset()
ns = load("a per-cent sign in the wording does not stop the prompt")
if ns then
	local scenario = "a per-cent sign in the wording does not stop the prompt"
	drive(scenario, ns)
	Mock.advance(60)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to render")
	else
		local p = ns.db.profile.prompt
		p.format = "{name} -- {reason}"
		p.reasonOwed = "gave you 10% of a buff"
		p.reasonGroup = "100% needs {buff}"
		p.reasonNearby = "100% needs {buff}"
		p.reasonTarget = "your target, 50% there"
		p.reasonRefresh = "10% left"
		p.reasonUnknown = "unverified, 0% sure"

		local ok, out = pcall(function() return ns.Prompt:RenderPrimary(entry, 3) end)
		if not ok then
			fail(scenario, "a per-cent sign in the reason wording threw on render: " .. tostring(out))
		elseif not tostring(out):find("%%") then
			fail(scenario, "the per-cent sign was eaten rather than printed: " .. tostring(out))
		end

		-- Through the path the game actually takes, because the render above is
		-- reached from inside ns.Guard -- where a throw is swallowed, recorded,
		-- and shows up as a prompt that simply stopped.
		local before = #ns.errors
		ns.addon:Tick()
		ns.Prompt:Refresh()
		if #ns.errors > before then
			fail(scenario, "repainting the prompt with a per-cent sign in the wording threw: "
				.. tostring(ns.errors[#ns.errors].err))
		end

		-- And the sub-line on its own, which is where the top-up wording lands.
		entry.remaining = 120
		local subOk, sub = pcall(function() return ns.Prompt:ReasonText(entry) end)
		if not subOk then
			fail(scenario, "a per-cent sign in the top-up wording threw: " .. tostring(sub))
		end
	end

	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 79
-- The queue is rebuilt from scratch two and a half times a second, and in a
-- crowd the reason its top changes is usually not that somebody more deserving
-- turned up: it is that the person already on the panel dropped out of one
-- scan -- a yard out of range, a recycled nameplate, an aura read falling out
-- of the three-second cache. The prompt swapped to a stranger and swapped back
-- on the next scan, with the text cross-fade and the alert sound following each
-- swap. A strobe at 2.5 Hz, in exactly the place where there is most to do.
--
-- Driven through a stubbed BuildQueue rather than by arranging units: what is
-- under test is what the panel does when the queue churns, and manufacturing
-- the churn is the only way to be certain it churned.
Mock.reset()
ns = load("the prompt does not strobe when the queue churns")
if ns then
	local scenario = "the prompt does not strobe when the queue churns"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local function cand(name, reason, priority)
			local e = {}
			for k, v in pairs(template) do e[k] = v end
			e.name, e.short, e.reason, e.priority = name, name, reason, priority
			-- Both spellings move together. An entry whose identity says one
			-- person and whose targeting spelling says another is a shape
			-- BuildQueue cannot produce, and a fixture in that shape tests the
			-- fixture.
			e.targetName = ns.TargetName(name)
			return e
		end
		local queue = { cand("Ana Field", "nearby", 3) }
		ns.BuildQueue = function() return queue end

		local button = ns.Prompt:GetButton()
		local function armedAt() return tostring(button:GetAttribute("macrotext1") or "") end

		wipe(ns.tried)
		ns.Prompt:Refresh()
		if not armedAt():find("Ana Field", 1, true) then
			fail(scenario, "SKIPPED -- the panel never armed the first candidate")
		else
			-- One scan without her, and the replacement is no better than she was.
			queue = { cand("Bo Stone", "nearby", 3) }
			Mock.advance(0.4)
			ns.Prompt:Refresh()
			if armedAt():find("Bo Stone", 1, true) then
				fail(scenario, "one scan without Ana handed the panel to somebody no more"
					.. " deserving -- this is the strobe")
			end

			-- The one being held off is still waiting, and the panel has to say
			-- so. Both the list and the count read off the queue's own order,
			-- which assumed the pick was always queue[1] -- so the person the
			-- hold is keeping out vanished from the list as well as the panel,
			-- and the count of who else is waiting came back one short.
			ns.db.profile.prompt.showQueue = true
			ns.db.profile.prompt.queueRows = 3
			ns.Prompt:ApplyStyle()
			local regions = ns.Prompt:Regions()
			if not tostring(regions.rows[1]:GetText() or ""):find("Bo Stone", 1, true) then
				fail(scenario, "the candidate being held off disappeared from the waiting list"
					.. " too: " .. tostring(regions.rows[1]:GetText()))
			end
			if tostring(regions.count:GetText() or "") ~= "1" then
				fail(scenario, "the count of who else is waiting was read off the queue's order"
					.. " rather than counted: " .. tostring(regions.count:GetText()))
			end
			ns.db.profile.prompt.showQueue = false
			ns.Prompt:ApplyStyle()

			-- And it lets go. Nothing here may pin the prompt to a name.
			Mock.advance(2)
			ns.Prompt:Refresh()
			if not armedAt():find("Bo Stone", 1, true) then
				fail(scenario, "the hold never expired, so a candidate who has genuinely gone"
					.. " keeps the prompt for good")
			end

			-- Somebody strictly more deserving is never held off: noticing a
			-- favour owed over a passer-by is the whole business of this addon.
			queue = { cand("Cai Marsh", "owed", 1) }
			Mock.advance(0.4)
			ns.Prompt:Refresh()
			if not armedAt():find("Cai Marsh", 1, true) then
				fail(scenario, "a favour owed was held off by a passer-by painted a moment"
					.. " earlier, which is the one swap that must always happen")
			end
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 80
-- The other half of the same strobe. An empty queue took the prompt down on the
-- spot, and the next scan 0.4s later put it back with the entrance animation
-- replayed -- for a gap that was one person stepping briefly out of range.
--
-- The fuse must not swallow the real thing, though: a queue that stays empty
-- still hides, and somebody deliberately retired -- clicked, or skipped with a
-- right-press -- goes at once, because "they are gone" is the answer that was
-- just asked for.
Mock.reset()
ns = load("an empty queue is given a moment to refill")
if ns then
	local scenario = "an empty queue is given a moment to refill"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local ana = {}
		for k, v in pairs(template) do ana[k] = v end
		ana.name, ana.short, ana.reason, ana.priority = "Ana Field", "Ana Field", "nearby", 3
		ana.targetName = ns.TargetName(ana.name)

		local queue = { ana }
		ns.BuildQueue = function() return queue end
		local button = ns.Prompt:GetButton()

		wipe(ns.tried)
		ns.Prompt:Refresh()
		if not button:IsShown() then
			fail(scenario, "SKIPPED -- the prompt never came up")
		else
			queue = {}
			Mock.advance(0.4)
			ns.Prompt:Refresh()
			if not button:IsShown() then
				fail(scenario, "one empty scan took the prompt down, so a momentary gap replays"
					.. " the entrance animation and the sound")
			end

			-- And a press during the gap has to agree with what is on screen.
			-- Re-resolving to nobody would leave a visible, named prompt that
			-- casts nothing and says nothing about it.
			Mock.advance(0.1)
			local pre = button.scripts.PreClick
			if pre then pcall(pre, button, "LeftButton") end
			if not tostring(button:GetAttribute("macrotext1") or ""):find("Ana Field", 1, true) then
				fail(scenario, "a press while the prompt was still naming Ana disarmed it, so"
					.. " the click did nothing at all and nothing said why")
			end

			-- A refill puts the fuse out rather than leaving it burning.
			queue = { ana }
			Mock.advance(0.2)
			ns.Prompt:Refresh()
			queue = {}
			Mock.advance(0.4)
			ns.Prompt:Refresh()
			if not button:IsShown() then
				fail(scenario, "the fuse was not reset by the queue refilling, so the second gap"
					.. " was measured from the first")
			end

			-- But a gap that is real is still a gap.
			Mock.advance(1)
			ns.Prompt:Refresh()
			if button:IsShown() then
				fail(scenario, "an empty queue never took the prompt down at all")
			end

			-- And a right-press skip is obeyed immediately, not 0.75s later.
			queue = { ana }
			Mock.advance(1)
			wipe(ns.tried)
			ns.Prompt:Refresh()
			ns.BlockPerson("Ana Field")
			queue = {}
			Mock.advance(0.4)
			ns.Prompt:Refresh()
			if button:IsShown() then
				fail(scenario, "somebody who was deliberately skipped stayed on the prompt,"
					.. " which is the opposite of what the press asked for")
			end
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 81
-- The sound was tied to the name on the panel changing, and the name changing
-- is exactly what churns. A panel swapping a name is something you can look
-- away from; a sound going off twice a second is not.
Mock.reset()
ns = load("the alert sound has a floor under it")
if ns then
	local scenario = "the alert sound has a floor under it"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local function cand(name)
			local e = {}
			for k, v in pairs(template) do e[k] = v end
			e.name, e.short, e.reason, e.priority = name, name, "nearby", 3
			e.targetName = ns.TargetName(name)
			return e
		end
		local queue = { cand("Ana Field") }
		ns.BuildQueue = function() return queue end

		local db = ns.db.profile
		db.sound.enabled = true
		db.sound.file = ns.SOUND_KEY
		-- The churn this is about is the whole queue, not the owed half of it,
		-- and these candidates are passers-by. Said out loud rather than left
		-- to the default, because the reason filter is a separate guarantee
		-- with a scenario of its own.
		db.sound.owedOnly = false

		wipe(ns.tried)
		Mock.sounds = {}
		ns.Prompt:Refresh()
		if #Mock.sounds == 0 then
			fail(scenario, "SKIPPED -- the first candidate made no sound at all")
		else
			-- Past the hold, so the name really does change, and inside the
			-- sound floor.
			queue = { cand("Bo Stone") }
			Mock.advance(1.6)
			ns.Prompt:Refresh()
			if #Mock.sounds > 1 then
				fail(scenario, "the sound followed the name changing, so a churning queue is"
					.. " audible twice a second")
			end

			-- The floor is a floor, not a mute.
			queue = { cand("Cai Marsh") }
			Mock.advance(4)
			ns.Prompt:Refresh()
			if #Mock.sounds < 2 then
				fail(scenario, "the sound never came back, so somebody arriving minutes later"
					.. " is silent")
			end
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 82
-- Nothing on screen said whether the click worked. Every ingredient existed --
-- the parked click, the cast event with its recipient, the error event -- and
-- all of it was thrown away unless the click debugging was switched on. On a
-- client that also refuses to show most auras, that left the user pressing a
-- button and looking at an unchanged panel.
--
-- The half that matters most is the distinction. The settle path is careful
-- about the difference between a cast the client attributed to the person we
-- aimed at and one it would not attribute at all, and a tick over the second
-- would be the panel claiming precisely what that care exists to avoid.
Mock.reset()
ns = load("the panel says how the click turned out")
if ns then
	local scenario = "the panel says how the click turned out"
	drive(scenario, ns)
	Mock.advance(60)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		local regions = ns.Prompt:Regions()

		local function press()
			Mock.advance(1)
			ns.pendingClick = nil
			wipe(ns.tried)
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to settle")
				return false
			end
			return true
		end

		-- The client named the person we aimed at. This is the one case that is
		-- confirmed rather than inferred.
		if press() then
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
			local line = tostring(regions.name:GetText() or "")
			if not line:find("buffed", 1, true) then
				fail(scenario, "a cast the game confirmed left the panel saying nothing: "
					.. line)
			end
			if not regions.fill:IsShown() then
				fail(scenario, "the confirmation had no colour behind it, so it reads as the"
					.. " prompt simply changing its mind")
			end
		end

		-- Our spell, our /target, and a client that would not say who received
		-- it. The favour settles -- refusing to would make every debt permanent
		-- here -- but the panel must not call it confirmed.
		if press() then
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, ours)
			local line = tostring(regions.name:GetText() or "")
			if line:find("buffed", 1, true) then
				fail(scenario, "the panel claimed the buff landed on somebody the client never"
					.. " named: " .. line)
			end
			if not line:find("sent", 1, true) then
				fail(scenario, "an inferred settle said nothing at all: " .. line)
			end
		end

		-- And the game's own reason, which is frequently the only thing that
		-- says why.
		if press() then
			ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.")
			local line = tostring(regions.name:GetText() or "")
			local sub = tostring(regions.sub:GetText() or "")
			if not line:find("could not buff", 1, true) then
				fail(scenario, "an error inside the click window left the panel looking like a"
					.. " successful cast: " .. line)
			end
			if not sub:find("Out of range", 1, true) then
				fail(scenario, "the game said why and the panel did not repeat it: " .. sub)
			end
		end
	end

	ns.pendingClick = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 83
-- Combat freezes the secure attributes, so the macro on the button stays aimed
-- at whoever was on it when the fight started -- however long they have since
-- been out of range, dead, or buffed by somebody else. The panel went on
-- painting that at full brightness, with a queue list underneath it still being
-- rebuilt from a queue the button cannot be aimed at, and a tooltip describing
-- a macro for a person who may have walked off two minutes ago. Everything it
-- said was stale and nothing about it looked stale.
Mock.reset()
ns = load("the prompt admits it is frozen in combat")
if ns then
	local scenario = "the prompt admits it is frozen in combat"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local function cand(name, reason, priority)
			local e = {}
			for k, v in pairs(template) do e[k] = v end
			e.name, e.short, e.reason, e.priority = name, name, reason, priority
			-- Both spellings move together. An entry whose identity says one
			-- person and whose targeting spelling says another is a shape
			-- BuildQueue cannot produce, and a fixture in that shape tests the
			-- fixture.
			e.targetName = ns.TargetName(name)
			return e
		end
		ns.BuildQueue = function()
			return { cand("Ana Field", "nearby", 3), cand("Bo Stone", "group", 2),
				cand("Cai Marsh", "owed", 1) }
		end

		local db = ns.db.profile
		db.prompt.showQueue = true
		db.prompt.queueRows = 2
		db.prompt.hideInCombat = false

		wipe(ns.tried)
		ns.Prompt:ApplyStyle()
		local regions = ns.Prompt:Regions()
		if (regions.rows[1]:GetText() or "") == "" then
			fail(scenario, "SKIPPED -- the queue list was empty before combat")
		else
			-- In the client's order: the event arrives while lockdown is still
			-- off, and lockdown is on by the next frame. The other way round,
			-- which is how this was first written, the handler's own Refresh
			-- saw lockdown and painted the hold -- something it never sees in
			-- game, where the hold waited for the next scan.
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
			Mock.runTimers(0)

			if regions.art:GetAlpha() >= 1 then
				fail(scenario, "the panel kept full brightness over a frozen target, so nothing"
					.. " about it says it cannot follow the queue")
			end
			if (regions.rows[1]:GetText() or "") ~= "" then
				fail(scenario, "the queue list went on updating under a button that cannot be"
					.. " aimed at any of it")
			end
			if not tostring(regions.sub:GetText() or ""):find("held", 1, true) then
				fail(scenario, "nothing on the panel says the prompt is held: "
					.. tostring(regions.sub:GetText()))
			end

			Mock.tooltip = {}
			local onEnter = ns.Prompt:GetButton().scripts.OnEnter
			if onEnter then pcall(onEnter, ns.Prompt:GetButton()) end
			if #Mock.tooltip > 0 then
				fail(scenario, "the tooltip described a frozen macro in detail, which is the"
					.. " most convincing thing the prompt can say and the least true")
			end

			-- And it all comes off when the fight does, without waiting for the
			-- next scan.
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
			if regions.art:GetAlpha() < 1 then
				fail(scenario, "the dim outlived the fight, so the prompt looks held while it"
					.. " is working normally")
			end
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 84
-- The tooltip was headed "Will run:" over a quote of the macro, and the heading
-- was not true. The spoken line is drawn at random out of the phrase pool and
-- was re-rolled on every repaint -- 2.5 times a second -- and once more inside
-- PreClick, so the line being read was reliably not the line that went out.
--
-- math.random is replaced with a counter here rather than left to chance: with
-- a real roll the two lines agree by luck often enough that the bug could pass.
Mock.reset()
ns = load("the tooltip quotes the line that will actually run")
if ns then
	local scenario = "the tooltip quotes the line that will actually run"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local ana = {}
		for k, v in pairs(template) do ana[k] = v end
		ana.name, ana.short, ana.reason, ana.priority = "Ana Field", "Ana Field", "owed", 1
		ana.targetName = ns.TargetName(ana.name)
		-- Off a nameplate. The template came through the target token, and your
		-- own target is never handed back (scenario 237).
		ana.unit = "nameplate1"
		ns.BuildQueue = function() return { ana } end

		local db = ns.db.profile
		db.speech.enabled = true
		db.speech.onlyWhenReturning = false
		db.speech.channel = "SAY"
		db.speech.phrases = "alpha\nbravo\ncharlie\ndelta"
		db.debugClicks = false
		db.filters.restoreTarget = true

		local realRandom = math.random
		local rolls = 0
		math.random = function(n) rolls = rolls + 1 return ((rolls - 1) % n) + 1 end

		local button = ns.Prompt:GetButton()
		wipe(ns.tried)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()

		Mock.tooltip = {}
		local onEnter = button.scripts.OnEnter
		if onEnter then pcall(onEnter, button) end

		local quoted, plain, restore, dump
		for _, line in ipairs(Mock.tooltip) do
			quoted = line:match("^Says: |cffffffff(.-)|r$") or quoted
			if line:find("Targets ", 1, true) and line:find("casts ", 1, true) then plain = true end
			if line:find("target back", 1, true) then restore = true end
			if line == "Will run:" then dump = true end
		end

		if not plain then
			fail(scenario, "the tooltip never says in plain words who it targets and what it"
				.. " casts")
		end
		if not restore then
			fail(scenario, "the tooltip never says your own target is handed back, which is the"
				.. " thing people are most afraid it will not do")
		end
		if dump then
			fail(scenario, "the raw macro is still in the tooltip with the click debugging off")
		end

		-- The press rebuilds the macro. What it casts has to be what was read.
		Mock.advance(1)
		local pre = button.scripts.PreClick
		if pre then pcall(pre, button, "LeftButton") end
		local said = tostring(button:GetAttribute("macrotext1") or ""):match("/say ([^\n]+)")
		if not (quoted and said) then
			fail(scenario, "SKIPPED -- no spoken line to compare (" .. tostring(quoted)
				.. " / " .. tostring(said) .. ")")
		elseif quoted ~= said then
			fail(scenario, "the tooltip quoted |" .. quoted .. "| and the press cast |"
				.. said .. "|")
		end

		-- And the raw dump is still reachable where the other debugging is.
		db.debugClicks = true
		Mock.tooltip = {}
		if onEnter then pcall(onEnter, button) end
		local back = false
		for _, line in ipairs(Mock.tooltip) do
			if line == "Will run:" then back = true end
		end
		if not back then
			fail(scenario, "the raw macro was deleted rather than moved, so there is no way to"
				.. " read what the button is actually carrying")
		end

		math.random = realRandom
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 85
-- The queue list hung below the panel as bare text on the world: unreadable on
-- anything bright, invisible on anything dark, with nothing to say which of the
-- rows is a favour owed and which is a passer-by. And the prompt's new home is
-- just above the action bars, where a list hanging underneath runs off the
-- bottom of the screen.
Mock.reset()
ns = load("the queue list is readable and stays on screen")
if ns then
	local scenario = "the queue list is readable and stays on screen"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local function cand(name, reason, priority)
			local e = {}
			for k, v in pairs(template) do e[k] = v end
			e.name, e.short, e.reason, e.priority = name, name, reason, priority
			-- Both spellings move together. An entry whose identity says one
			-- person and whose targeting spelling says another is a shape
			-- BuildQueue cannot produce, and a fixture in that shape tests the
			-- fixture.
			e.targetName = ns.TargetName(name)
			return e
		end
		ns.BuildQueue = function()
			return { cand("Ana Field", "nearby", 3), cand("Bo Stone", "owed", 1),
				cand("Cai Marsh", "group", 2), cand("Dai Holt", "nearby", 3) }
		end

		local db = ns.db.profile
		db.prompt.showQueue = true
		db.prompt.queueRows = 3
		db.prompt.style = "glass"

		wipe(ns.tried)
		Mock.promptCentreY = 500
		ns.Prompt:ApplyStyle()
		local regions = ns.Prompt:Regions()

		if not regions.queueBack:IsShown() then
			fail(scenario, "the rows are still lying on the world with no background behind"
				.. " them")
		end
		if not regions.queueHair:IsShown() then
			fail(scenario, "no hairline divides the list from the prompt, so the two stacked"
				.. " rectangles read as one")
		end
		for i = 1, 3 do
			if (regions.rows[i]:GetText() or "") == "" then
				fail(scenario, "queue row " .. i .. " is empty")
			end
			if not regions.bars[i]:IsShown() then
				fail(scenario, "queue row " .. i .. " has no reason bar, so its priority can"
					.. " only be had by reading it")
			end
		end
		local first, second = regions.bars[1]._color, regions.bars[2]._color
		if first and second and first[1] == second[1] and first[2] == second[2]
			and first[3] == second[3] then
			fail(scenario, "every row was tinted the same, so the bar says nothing")
		end
		-- The list is who is waiting *behind* the panel, so the person on it is
		-- not one of them.
		if tostring(regions.rows[1]:GetText() or ""):find("Ana Field", 1, true) then
			fail(scenario, "the person on the panel is listed again as somebody waiting behind"
				.. " it: " .. tostring(regions.rows[1]:GetText()))
		end

		-- Low on the screen, where the list would hang off the bottom edge.
		Mock.promptCentreY = 50
		ns.Prompt:ApplyStyle()
		local anchor = regions.rows[1].points[1]
		if not (anchor and anchor[1] == "BOTTOMLEFT" and anchor[3] == "TOPLEFT") then
			fail(scenario, "a prompt in the bottom third of the screen still hangs its list"
				.. " below itself, off the edge")
		end

		-- And back, because flipping it when there is room would be its own bug.
		Mock.promptCentreY = 500
		ns.Prompt:ApplyStyle()
		anchor = regions.rows[1].points[1]
		if not (anchor and anchor[1] == "TOPLEFT" and anchor[3] == "BOTTOMLEFT") then
			fail(scenario, "the list flipped above the prompt with a screen full of room"
				.. " below it")
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 86
-- The icon slider ran to 64 against a height that runs down to 20, so the icon
-- could be set three times the height of the thing it sits in: overhanging both
-- hairlines, pushing the text off the right-hand edge, with nothing on the page
-- to say why.
Mock.reset()
ns = load("the icon cannot be bigger than the panel")
if ns then
	local scenario = "the icon cannot be bigger than the panel"
	drive(scenario, ns)

	local p = ns.db.profile.prompt
	p.height = 30
	p.iconSize = 64
	ns.ClampSettings()
	if p.iconSize > p.height - 8 then
		fail(scenario, "a stored profile kept an icon taller than the prompt: "
			.. tostring(p.iconSize) .. " in " .. tostring(p.height))
	end

	-- The slider's own max has to be a plain number. AceConfigRegistry types
	-- min and max as "number or nil" and rejects the WHOLE options table if
	-- either is a function -- not the control, the table -- so binding the max
	-- to the height here would stop the page drawing at all. The bound lives in
	-- ClampSettings, which is asserted above.
	local slider = ns.optionsTable and ns.optionsTable.args.appearance.args.iconSize
	if not slider then
		fail(scenario, "the icon slider is not on the options table at all")
	elseif type(slider.max) ~= "number" then
		fail(scenario, "iconSize.max is a " .. type(slider.max)
			.. "; AceConfig wants a number and rejects the whole table otherwise")
	elseif type(slider.min) ~= "number" then
		fail(scenario, "iconSize.min is a " .. type(slider.min) .. ", not a number")
	end

	-- And the page must say so when the clamp has bitten, or the slider reads
	-- back a number the prompt is not using with nothing to explain it.
	local notice = ns.optionsTable and ns.optionsTable.args.appearance.args.iconSizeCapped
	if notice then
		p.height, p.iconSize = 30, 22
		if notice.hidden and notice.hidden() then
			fail(scenario, "no notice shown while the icon is held below the slider value")
		end
		p.height, p.iconSize = 120, 30
		if notice.hidden and not notice.hidden() then
			fail(scenario, "a notice about a clamp that is not happening")
		end
	end

	-- Through the control somebody actually touches, not just the clamp: the
	-- height slider has to take the icon down with it.
	p.height = 120
	p.iconSize = 60
	local height = ns.optionsTable and ns.optionsTable.args.appearance.args.height
	if height and height.set then
		height.set({ "height" }, 40)
		if p.iconSize > 32 then
			fail(scenario, "lowering the height left an oversized icon overhanging it: "
				.. tostring(p.iconSize))
		end
	end

	-- And the same rule from the other control, which is the one the page
	-- claims it for. The icon slider never called the clamp at all: it runs to
	-- 64 against a height that runs down to 20, so dragging it left the icon
	-- exactly where it was dropped -- over both hairlines, pushing the text off
	-- the right-hand edge -- while the notice above read "the icon is held at
	-- 64 to fit a prompt 30 high", which was held at nothing.
	p.height = 30
	p.iconSize = 20
	if slider and slider.set then
		slider.set({ "iconSize" }, 64)
		if p.iconSize > p.height - 8 then
			fail(scenario, "dragging the icon slider left an icon taller than the prompt: "
				.. tostring(p.iconSize) .. " in " .. tostring(p.height))
		end
		local capped = ns.optionsTable and ns.optionsTable.args.appearance.args.iconSizeCapped
		if capped and capped.hidden and not capped.hidden()
			and not tostring(capped.name and capped.name() or ""):find(tostring(p.iconSize), 1, true) then
			fail(scenario, "the page says the icon is held at a size it is not: "
				.. tostring(capped.name()))
		end
	end
end

-- ------------------------------------------------------------------ 87
-- The prompt defaulted to the middle of the play area: a panel that eats mouse
-- clicks, sitting over whatever you are looking at, and the only way to move it
-- was unlock, find it, drag it, lock it -- four steps and a mode you can forget
-- you are in, because an unlocked prompt is also one that will not cast.
Mock.reset()
ns = load("the prompt starts somewhere sensible and can be moved without dragging")
if ns then
	local scenario = "the prompt starts somewhere sensible and can be moved without dragging"
	drive(scenario, ns)

	local d = ns.defaults.profile.prompt
	if d.point == "CENTER" and d.relPoint == "CENTER" then
		fail(scenario, "the prompt still defaults to the middle of the play area")
	end
	if not ns.CurrentPositionPreset() then
		fail(scenario, "the default position is not one of the presets, so a fresh profile"
			.. " shows the dropdown blank over a prompt that has never been moved")
	end

	if not ns.ApplyPositionPreset("minimap") then
		fail(scenario, "SKIPPED -- the minimap preset does not exist")
	else
		local p = ns.db.profile.prompt
		if p.point ~= "TOPRIGHT" or p.relPoint ~= "TOPRIGHT" then
			fail(scenario, "the preset did not move the prompt: " .. tostring(p.point))
		end
		if ns.CurrentPositionPreset() ~= "minimap" then
			fail(scenario, "the dropdown does not read back the preset it was just set to")
		end
		-- Moving it must never unlock it: an unlocked prompt cannot cast, and
		-- that is the one state the user cannot see from the outside.
		if p.locked ~= true then
			fail(scenario, "a position preset unlocked the prompt")
		end
		-- Dragged off it afterwards, it is not on a preset any more.
		p.x = p.x - 37
		if ns.CurrentPositionPreset() ~= nil then
			fail(scenario, "the dropdown still names a preset the prompt has been dragged off")
		end
	end
end

-- ------------------------------------------------------------------ 88
-- Preview is for styling the prompt, and both of its exits fired while you were
-- doing exactly that. Twenty seconds is not long enough to work through a tab of
-- sliders, and "somebody real turned up" fires on the first pass anywhere there
-- are people -- so the prompt could not be styled in a city at all, which is the
-- one place its size and position matter.
--
-- The limit still has to exist. A preview left running looks exactly like a
-- working prompt while ignoring every real buff, which is a silent failure.
Mock.reset()
ns = load("preview survives the options window being open")
if ns then
	local scenario = "preview survives the options window being open"
	drive(scenario, ns)
	Mock.advance(60)

	Mock.optionsOpen = true
	ns.Prompt:ToggleTest()
	if not ns.Prompt:InTest() then
		fail(scenario, "SKIPPED -- the preview never started")
	else
		Mock.advance(120)
		ns.Prompt:Refresh()
		if not ns.Prompt:InTest() then
			fail(scenario, "the preview timed out while the options window was open, which is"
				.. " the only time it is any use")
		end

		-- And a crowd does not end it either, which is what made it useless in
		-- a city.
		local template = ns.BuildQueue()[1]
		if template then
			ns.BuildQueue = function() return { template } end
			ns.Prompt:Refresh()
			if not ns.Prompt:InTest() then
				fail(scenario, "somebody walking past ended the preview in the middle of a"
					.. " slider")
			end
			ns.BuildQueue = function() return {} end
		end

		local test = ns.optionsTable and ns.optionsTable.args.appearance.args.test
		local label = test and (type(test.name) == "function" and test.name() or test.name)
		if label ~= "Stop preview" then
			fail(scenario, "the button still reads " .. tostring(label)
				.. " while a preview is running, so you press it to find out which it does")
		end

		-- Shut the window and the old rules come straight back.
		Mock.optionsOpen = false
		Mock.advance(120)
		ns.Prompt:Refresh()
		if ns.Prompt:InTest() then
			fail(scenario, "the preview outlived the options window, which is the silent"
				.. " failure the time limit exists to prevent")
		end
	end
	Mock.optionsOpen = false
end

-- ------------------------------------------------------------------ 89
-- The options page itself, walked.
--
-- Three guarantees it had no way to keep. AceConfig sorts controls by `order`
-- and breaks a tie on the option's *name*, so two controls sharing a number
-- render in whatever order their labels happen to sort -- which is how a
-- slider reading "...after this long" came to sit under "If they already have
-- the buff", a dropdown it has nothing to do with. Every closure on the page
-- runs only while the window is being drawn, so a `name` or a `hidden` that
-- throws is a blank options screen and no other symptom. And a control moving
-- between tabs is a silent settings reset the moment its key changes, because
-- every get and set here is keyed either on the option's own name or on a
-- profile field named outright.

-- Every option key anywhere in the tree.
local function optionKeys(node, into)
	if type(node) ~= "table" or type(node.args) ~= "table" then return into end
	for key, option in pairs(node.args) do
		if type(option) == "table" then
			into[key] = true
			optionKeys(option, into)
		end
	end
	return into
end

-- Unique orders within a group, and every closure called the way AceConfig
-- calls it: `info` is the path to the control, and info[#info] -- its key -- is
-- what the shared get/set closures read.
local function walkOptions(scenario, node, path)
	if type(node) ~= "table" or type(node.args) ~= "table" then return end
	local orders = {}
	for key, option in pairs(node.args) do
		if type(option) == "table" then
			if type(option.order) == "number" then
				if orders[option.order] then
					fail(scenario, ("%s: %s and %s are both at order %s, so which one renders"
						.. " first is decided by how their names sort"):format(
						path, orders[option.order], key, tostring(option.order)))
				end
				orders[option.order] = key
			end
			for _, field in ipairs({ "name", "desc", "hidden", "disabled", "values",
				"sorting", "get", "min", "max", "step" }) do
				if type(option[field]) == "function" then
					local ok, err = pcall(option[field], { key })
					if not ok then
						fail(scenario, ("%s/%s: %s() threw -- %s"):format(
							path, key, field, tostring(err)))
					end
				end
			end
			walkOptions(scenario, option, path .. "/" .. key)
		end
	end
end

-- Every control that existed before the page was rearranged, plus the ones the
-- new behaviour needs. Nothing here says which tab it is on -- the point is
-- that moving a control does not quietly delete it.
local REQUIRED_OPTIONS = {
	"enabled", "minimap", "verbose", "makeMacro",
	"choice", "owed", "owedClassBuffsOnly", "group", "strangers",
	"relevantOnly", "requireInRange", "reachableOnly", "graceSeconds", "minLevel",
	"whenBuffed", "refreshUnder", "reciprocateWindow", "retryCooldown", "scanInterval",
	"restoreTarget", "channel", "onlyWhenReturning", "preset", "phrases", "roll",
	"test", "locked", "reset", "style", "accentByReason", "accentColor", "bgColor",
	"accentMode", "flashStyle", "posPreset", "x", "y", "width", "height", "scale",
	"alpha", "hideInCombat", "format", "showSub", "reasonTarget", "reasonOwed",
	"reasonGroup", "reasonNearby", "reasonRefresh", "reasonUnknown", "font",
	"fontSize", "fontColor", "classColor", "showIcon", "iconSize", "roundIcon",
	"showCount", "showQueue", "queueRows", "debugClicks", "diag",
	-- the sound, which moved tabs to sit beside the flash
	"soundEnabled", "soundFile", "soundOwedOnly",
	-- and the switches the new behaviour arrived without
	"target", "keepDebts", "combatNotice", "report",
}

Mock.reset()
Mock.class = "PRIEST"
ns = load("the options page is whole")
if ns then
	local scenario = "the options page is whole"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)

	local options = ns.optionsTable
	if type(options) ~= "table" or type(options.args) ~= "table" then
		fail(scenario, "SKIPPED -- no options table was built")
	else
		for key, group in pairs(options.args) do
			-- The profiles tab is AceDBOptions' own table. We do not own its
			-- numbering and have no business judging it.
			if key ~= "profiles" then walkOptions(scenario, group, key) end
		end

		local present = optionKeys(options, {})
		for _, key in ipairs(REQUIRED_OPTIONS) do
			if not present[key] then
				fail(scenario, "the page no longer has a control for " .. key)
			end
		end

		-- The one ordering that was wrong rather than merely tied: the setting
		-- that decides where the reason colour goes sat *below* the two colour
		-- pickers it governs, so the page explained itself backwards.
		local style = options.args.appearance and options.args.appearance.args
		if style then
			if not (style.accentMode.order < style.accentByReason.order
				and style.accentMode.order < style.accentColor.order) then
				fail(scenario, "the control that decides where the accent goes still sits below"
					.. " the colours it governs")
			end
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- The same walk on a class with nothing to give, and on a client missing every
-- C_ namespace. Both are pages somebody will open to find out why nothing is
-- happening, which is the worst possible moment for a `name` function to throw.
for _, case in ipairs({ { class = "ROGUE" }, { class = "MAGE", stripped = true } }) do
	Mock.reset()
	Mock.class = case.class
	Mock.stripped = case.stripped == true
	local label = "the options page is whole (" .. case.class
		.. (case.stripped and ", stripped client)" or ")")
	ns = load(label)
	if ns then
		drive(label, ns)
		if type(ns.optionsTable) == "table" then
			for key, group in pairs(ns.optionsTable.args) do
				if key ~= "profiles" then walkOptions(label, group, key) end
			end
		end
	end
end
Mock.stripped = false

-- ------------------------------------------------------------------ 90
-- Four of the five time sliders are seconds and the fifth is minutes, and every
-- one of them showed a bare number. "Remember a buff for: 120" and "Top up when
-- less than this is left: 5" are the same control as far as the page is
-- concerned. AceConfig has no suffix on a range, so the unit goes in the name
-- or it is nowhere at all.
Mock.reset()
ns = load("the time sliders say what they are counting")
if ns then
	local scenario = "the time sliders say what they are counting"
	drive(scenario, ns)

	local wanted = {
		{ group = "when", key = "reciprocateWindow", unit = "second" },
		{ group = "when", key = "retryCooldown", unit = "second" },
		{ group = "when", key = "scanInterval", unit = "second" },
		{ group = "when", key = "refreshUnder", unit = "minute" },
		{ group = "who", key = "graceSeconds", unit = "second" },
	}
	for _, want in ipairs(wanted) do
		local group = ns.optionsTable and ns.optionsTable.args[want.group]
		local option = group and group.args[want.key]
		local name = option and (type(option.name) == "function" and option.name() or option.name)
		if type(name) ~= "string" then
			fail(scenario, "no slider called " .. want.key .. " on the " .. want.group .. " tab")
		elseif not name:lower():find(want.unit, 1, true) then
			fail(scenario, ("%s reads \"%s\", which does not say it is in %ss"):format(
				want.key, name, want.unit))
		end
	end

	-- And the one whose label was a sentence fragment finishing the control
	-- above it -- which only reads as anything at all while the two are
	-- adjacent, and adjacency is exactly what a duplicate order number took
	-- away.
	local grace = ns.optionsTable and ns.optionsTable.args.who.args.graceSeconds
	local graceName = grace and (type(grace.name) == "function" and grace.name() or grace.name)
	if type(graceName) == "string" and graceName:find("^%s*%.%.%.") then
		fail(scenario, "the grace slider still reads as a continuation of the control above it: "
			.. graceName)
	end
end

-- ------------------------------------------------------------------ 91
-- The flash and the sound are one job -- getting you to look up -- and they
-- were two tabs apart and disagreed about who is worth it. The pulse fired for
-- a favour owed and nothing else; the sound went off for every stranger who
-- wandered within range of a nameplate.
Mock.reset()
ns = load("the sound is as choosy as the flash")
if ns then
	local scenario = "the sound is as choosy as the flash"
	drive(scenario, ns)
	Mock.advance(60)

	local panel = ns.optionsTable and ns.optionsTable.args.appearance
	if not (panel and panel.args.flashStyle and panel.args.soundEnabled) then
		fail(scenario, "the flash and the sound are still on different tabs")
	end

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local function cand(name, reason, priority)
			local e = {}
			for k, v in pairs(template) do e[k] = v end
			e.name, e.short, e.reason, e.priority = name, name, reason, priority
			-- Both spellings move together. An entry whose identity says one
			-- person and whose targeting spelling says another is a shape
			-- BuildQueue cannot produce, and a fixture in that shape tests the
			-- fixture.
			e.targetName = ns.TargetName(name)
			return e
		end
		local queue = { cand("Ana Field", "nearby", 3) }
		ns.BuildQueue = function() return queue end

		local db = ns.db.profile
		db.sound.enabled = true
		db.sound.file = ns.SOUND_KEY
		if db.sound.owedOnly ~= true then
			fail(scenario, "the reason filter is off by default, so the sound still goes off"
				.. " for passers-by until somebody finds the setting")
		end

		wipe(ns.tried)
		Mock.sounds = {}
		ns.Prompt:Refresh()
		if #Mock.sounds > 0 then
			fail(scenario, "a passer-by made a noise while the flash stayed silent for them")
		end

		-- Somebody who actually buffed you is the whole point of the addon.
		queue = { cand("Bo Stone", "owed", 1) }
		Mock.advance(10)
		ns.Prompt:Refresh()
		if #Mock.sounds == 0 then
			fail(scenario, "a favour owed made no sound, which is the one case the sound is for")
		end

		-- And switching the filter off brings the old behaviour back rather
		-- than removing it.
		db.sound.owedOnly = false
		queue = { cand("Cai Marsh", "nearby", 3) }
		Mock.advance(10)
		Mock.sounds = {}
		ns.Prompt:Refresh()
		if #Mock.sounds == 0 then
			fail(scenario, "switching the filter off left the sound filtered anyway")
		end
	end
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 92
-- The walk offers a class's whole list, and until now there was no way to say
-- "not that one". A priest who does not want to hand out Shadow Protection had
-- to pin one spell, which switches the walk off entirely.
--
-- The note above the switches is the other half: it named Wisdom and Might --
-- the one class whose automatic pick depends on who is standing there -- so
-- every other class read an explanation of somebody else's spells.
Mock.reset()
Mock.class = "PRIEST"
ns = load("each spell can be switched off on its own")
if ns then
	local scenario = "each spell can be switched off on its own"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local who = ns.optionsTable and ns.optionsTable.args.who
	local toggle = who and who.args["offer_spirit"]
	local note = who and who.args.autoNote
	if not (toggle and toggle.get and toggle.set) then
		fail(scenario, "SKIPPED -- there is no per-spell switch to test")
	else
		-- The note names the real walk, in the real order, for this class.
		local text = note and note.name() or ""
		for _, spell in ipairs({ "Power Word: Fortitude", "Divine Spirit", "Shadow Protection" }) do
			if not text:find(spell, 1, true) then
				fail(scenario, "the explanation of Automatic does not name " .. spell)
			end
		end

		if toggle.get({ "offer_spirit" }) ~= true then
			fail(scenario, "a spell nobody has touched starts switched off")
		end
		if ns.db.profile.buff.skip.spirit ~= nil then
			fail(scenario, "an untouched spell is stored rather than left absent, so every"
				.. " profile now carries a list it never asked for")
		end

		local function offered()
			local q = ns.BuildQueue()
			return q[1] and q[1].buff and q[1].buff.key or nil
		end

		Mock.held = {}
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do Mock.held[id] = true end
		Mock.advance(10)
		if offered() ~= "spirit" then
			fail(scenario, "SKIPPED -- the walk was not on spirit to begin with")
		else
			toggle.set({ "offer_spirit" }, false)
			Mock.advance(10)
			if offered() == "spirit" then
				fail(scenario, "a spell switched off is still being offered")
			elseif offered() ~= "shadow" then
				fail(scenario, "switching one spell off stopped the walk rather than stepping"
					.. " over it: offered " .. tostring(offered()))
			end
			if not ns.db.profile.buff.skip.spirit then
				fail(scenario, "the switch did not record anything")
			end
			-- And it drops out of the explanation, which is read straight off
			-- the same list the scan uses.
			if note and note.name():find("Divine Spirit", 1, true) then
				fail(scenario, "the note still promises a spell that is switched off")
			end

			-- Back on, and stored as an absence again rather than a false.
			toggle.set({ "offer_spirit" }, true)
			if ns.db.profile.buff.skip.spirit ~= nil then
				fail(scenario, "switching a spell back on left a key behind, so the set is no"
					.. " longer sparse")
			end
		end
		Mock.held = nil

		-- Every one of them off is the same silence as an empty Sources list,
		-- arriving from the other direction.
		for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
			ns.db.profile.buff.skip[key] = true
		end
		Mock.advance(10)
		if #ns.BuildQueue() > 0 then
			fail(scenario, "SKIPPED -- switching everything off did not empty the queue")
		elseif not (note and note.name():find("never appear", 1, true)) then
			fail(scenario, "every spell is switched off and the page says nothing about it")
		end
		for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
			ns.db.profile.buff.skip[key] = nil
		end

		-- A pin means "only ever this one", so the switches are over something
		-- that is no longer consulted. That was not quite so until scenario
		-- 213: the pinned spell's own switch was still read, and switched off
		-- it silenced the pin. It is so now, which is what hiding them rests on.
		ns.db.profile.buff.choice = "fortitude"
		if toggle.hidden and not toggle.hidden() then
			fail(scenario, "the per-spell switches are still shown while one spell is pinned,"
				.. " where they do nothing")
		end
		ns.db.profile.buff.choice = "auto"
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- And the same note for a class whose spells overwrite one another. A paladin
-- does not walk -- holding any blessing of yours means covered, because a
-- second one would replace the first -- so promising "the first of these they
-- are missing" would describe a rotation that takes away what the last click
-- gave.
Mock.reset()
Mock.class = "PALADIN"
ns = load("the note does not promise a paladin a walk")
if ns then
	local scenario = "the note does not promise a paladin a walk"
	local known = {}
	for _, key in ipairs({ "wisdom", "might", "kings" }) do
		for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)

	local note = ns.optionsTable and ns.optionsTable.args.who.args.autoNote
	local text = note and note.name() or ""
	if text:find("the first of these they are missing", 1, true) then
		fail(scenario, "the page promises a paladin a walk down the blessing list, which would"
			.. " replace whatever the last click gave")
	end
	if not text:find("Blessing of Wisdom", 1, true) then
		fail(scenario, "the note does not name the blessings it would actually use: " .. text)
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- And a class whose only offer is a shout. Battle Shout is cast on yourself
-- and heard by the party, so BuildQueue turns down everybody outside the group
-- before the strangers toggle is ever read: the control is a switch with
-- nothing behind it, and it read as a feature that was not working.
Mock.reset()
Mock.class = "WARRIOR"
ns = load("a switch with nothing behind it is not shown")
if ns then
	local scenario = "a switch with nothing behind it is not shown"
	local known = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)

	local who = ns.optionsTable and ns.optionsTable.args.who
	local strangers = who and who.args.strangers
	if not (strangers and strangers.hidden) then
		fail(scenario, "a warrior is still offered a toggle for people it can never reach")
	elseif not strangers.hidden() then
		fail(scenario, "the strangers toggle is shown to a class whose only spell is a shout")
	end
	-- The setting itself is untouched: hiding a control must never be a way of
	-- changing what it holds.
	if ns.db.profile.sources.strangers ~= true then
		fail(scenario, "hiding the control also switched it off")
	end
	local note = who and who.args.strangersNote
	if not (note and note.hidden and not note.hidden()) then
		fail(scenario, "the toggle vanished with nothing in its place saying why")
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- A class that can buff anybody keeps it, which is the half that proves the
-- test above is about the spell rather than about the page.
Mock.reset()
Mock.class = "MAGE"
ns = load("a switch with something behind it stays")
if ns then
	local scenario = "a switch with something behind it stays"
	drive(scenario, ns)
	local strangers = ns.optionsTable and ns.optionsTable.args.who.args.strangers
	if strangers and strangers.hidden and strangers.hidden() then
		fail(scenario, "a mage cannot switch on the strangers its whole job is to buff")
	end
end

-- ------------------------------------------------------------------ 93
-- Four ways to leave the addon permanently silent, every one of them reached by
-- switching something off on this page, and not one of them said so. A prompt
-- that never appears is exactly what a broken addon looks like.
Mock.reset()
Mock.class = "PRIEST"
ns = load("the page says when it will never do anything")
if ns then
	local scenario = "the page says when it will never do anything"
	local known = {}
	for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)

	local general = ns.optionsTable and ns.optionsTable.args.general
	local who = ns.optionsTable and ns.optionsTable.args.who

	-- 1. every source off
	local warning = who and who.args.emptyWarning
	if not (warning and warning.hidden) then
		fail(scenario, "nothing under Sources says anything when they are all off")
	else
		if not warning.hidden() then
			fail(scenario, "the empty-sources warning is showing with the sources switched on")
		end
		local s = ns.db.profile.sources
		s.owed, s.group, s.strangers = false, false, false
		if warning.hidden() then
			fail(scenario, "all three sources are off and the page says nothing")
		end
		s.owed, s.group, s.strangers = true, true, true
	end

	-- 2. the addon itself off
	local off = general and general.args.offNotice
	if not (off and off.hidden) then
		fail(scenario, "nothing says the addon is switched off")
	else
		if not off.hidden() then
			fail(scenario, "the disabled notice is showing while the addon is enabled")
		end
		ns.db.profile.enabled = false
		if off.hidden() then
			fail(scenario, "the addon is off and the page reads exactly as it does when it is on")
		end
		ns.db.profile.enabled = true
	end

	-- 3. a pinned spell that has not been learned. This is the quiet one: the
	-- pin is the only spell considered, so there is nothing to fall back to and
	-- nobody is offered anything -- and the pin is deliberately not reset for
	-- you, because a failed spell probe must not rewrite a setting.
	local pinNote = who and who.args.pinNote
	ns.db.profile.buff.choice = "shadow"
	ns.ClampSettings()
	Mock.advance(10)
	if ns.db.profile.buff.choice ~= "shadow" then
		fail(scenario, "SKIPPED -- the clamp discarded the pin")
	elseif #ns.BuildQueue() > 0 then
		fail(scenario, "SKIPPED -- an unlearned pin still offered somebody")
	elseif not (pinNote and pinNote.hidden and not pinNote.hidden()) then
		fail(scenario, "a pinned spell you have not learned stops everything and the page"
			.. " does not mention it")
	else
		local text = pinNote.name()
		if not text:find("ff8080", 1, true) then
			fail(scenario, "the warning about an unlearned pin is not marked as a problem")
		end
		if not text:find("not learned", 1, true) then
			fail(scenario, "the warning does not say what is actually wrong: " .. text)
		end
	end

	-- And the note about Automatic is not shown over a pinned spell.
	local autoNote = who and who.args.autoNote
	if autoNote and autoNote.hidden and not autoNote.hidden() then
		fail(scenario, "the page explains Automatic while a spell is pinned")
	end
	ns.db.profile.buff.choice = "auto"

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 94
-- "Your target wins" is a preference about somebody else's queue order, not a
-- fact about them -- a player who targets to inspect rather than to buff wants
-- the debts back on top -- and it arrived with no way to say so.
Mock.reset()
ns = load("the target rule can be switched off")
if ns then
	local scenario = "the target rule can be switched off"
	local realName = UnitName
	UnitName = function(u)
		if u == "player" then return "Mort", "Defrette" end
		if u == "target" then return "Petra", "Stonewell" end
		return "Yorick", "Vane"
	end

	drive(scenario, ns)
	Mock.advance(60)

	local function find(queue, name)
		for _, entry in ipairs(queue) do
			if entry.name == name then return entry end
		end
	end

	wipe(ns.owed)
	ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }

	local q = ns.BuildQueue()
	if not (q[1] and q[1].name == "Petra Stonewell") then
		fail(scenario, "SKIPPED -- the target was not on top to begin with")
	else
		ns.db.profile.priority.target = false
		Mock.advance(10)
		local off = ns.BuildQueue()
		local petra = find(off, "Petra Stonewell")
		if not petra then
			fail(scenario, "switching the rule off dropped the target instead of demoting them")
		elseif petra.reason == "target" or petra.priority == 0 then
			fail(scenario, ("the target is still promoted with the rule off: %s at %s"):format(
				tostring(petra.reason), tostring(petra.priority)))
		end
		if not (off[1] and off[1].name == "Yorick Vane") then
			fail(scenario, "with the rule off the outstanding debt is still not on top: "
				.. tostring(off[1] and off[1].name))
		end
		ns.db.profile.priority.target = true
	end

	wipe(ns.owed)
	UnitName = realName
end

-- ------------------------------------------------------------------ 95
-- Debts outliving the session is the right default and not everybody's taste:
-- somebody who would rather a reload wiped the slate had no way to say so, and
-- no way to get rid of a file that had already been written.
Mock.reset()
Mock.sv = {}
ns = load("debts can be told not to outlive the session")
if ns then
	local scenario = "debts can be told not to outlive the session"
	drive(scenario, ns)

	wipe(ns.owed)
	ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }
	ns.addon:SaveDebts()
	if not (Mock.sv.char.debts and Mock.sv.char.debts["Yorick Vane"]) then
		fail(scenario, "SKIPPED -- nothing was written to begin with")
	else
		local option = ns.optionsTable and ns.optionsTable.args["when"]
			and ns.optionsTable.args["when"].args.keepDebts
		if not (option and option.set) then
			fail(scenario, "there is no way to switch it off")
		else
			option.set({ "keepDebts" }, false)
			if ns.db.profile.timing.keepDebts ~= false then
				fail(scenario, "the switch did not store anything")
			end
			-- Off means gone now, not merely not-written-again: the file is
			-- read at the next login by a session that has been told not to
			-- want it.
			if Mock.sv.char.debts ~= nil then
				fail(scenario, "switching it off left yesterday's debts on disk")
			end

			ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }
			ns.addon:SaveDebts()
			if Mock.sv.char.debts ~= nil then
				fail(scenario, "a debt was written to disk after it was switched off")
			end
			option.set({ "keepDebts" }, true)
		end
	end
end

-- And the read side. A file can outlive the setting -- the profile is switched
-- between logins, or changed on another character sharing it -- so a session
-- that starts with it off must not restore one.
Mock.reset()
Mock.sv = {}
Mock.sv.char = { debts = { ["Yorick Vane"] = { expires = time() + 120, at = time() } } }
ns = load("a session told to forget does not restore")
if ns then
	local scenario = "a session told to forget does not restore"
	-- Written into the defaults rather than the live profile, because the
	-- restore runs inside OnInitialize -- which is where a profile saved with
	-- the setting off would already have it.
	ns.defaults.profile.timing.keepDebts = false
	drive(scenario, ns)
	if ns.owed["Yorick Vane"] then
		fail(scenario, "a debt was restored into a session that was told to forget them")
	end
	if Mock.sv.char.debts ~= nil then
		fail(scenario, "the file it was told not to read was left there to be read again")
	end
end

-- ------------------------------------------------------------------ 96
-- Every failure the addon catches was named once in chat, at the moment it
-- happened, and then lived only in /manners errors. The options page -- which
-- is where somebody goes when nothing is working -- showed a capability dump
-- and no errors at all, and never mentioned which build it is.
Mock.reset()
ns = load("diagnostics shows what broke and what to send")
if ns then
	local scenario = "diagnostics shows what broke and what to send"
	drive(scenario, ns)

	local diag = ns.optionsTable and ns.optionsTable.args.diagnostics
	if not diag then
		fail(scenario, "SKIPPED -- there is no diagnostics tab")
	else
		local list, none = diag.args.errorList, diag.args.noErrors
		if not (list and none) then
			fail(scenario, "the page still cannot show an error")
		else
			if not list.hidden() then
				fail(scenario, "an empty error list is being shown")
			end
			if none.hidden() then
				fail(scenario, "nothing has broken and the page does not say so either")
			end

			-- Raised through the real thing, so the wiring is under test.
			ns.Guard("a deliberate failure", function() error("kettle boiled dry", 0) end)
			if list.hidden() then
				fail(scenario, "something broke and the page still shows nothing")
			end
			local text = list.name()
			if not text:find("a deliberate failure", 1, true) then
				fail(scenario, "the error list does not name where it happened: " .. text)
			end
			if not text:find("kettle boiled dry", 1, true) then
				fail(scenario, "the error list does not say what happened: " .. text)
			end
		end

		-- The build number, which appeared nowhere on this page, and the block
		-- somebody is meant to paste into a report.
		local report = diag.args.report
		local button = diag.args.copyReport
		if not (report and button and button.func) then
			fail(scenario, "there is nothing to copy for a bug report")
		else
			if not report.hidden() then
				fail(scenario, "the report box is open before anybody asked for it")
			end
			button.func()
			if report.hidden() then
				fail(scenario, "pressing the button did not open the box")
			end
			local text = report.get()
			for _, wanted in ipairs({ tostring(ns.BUILD), "a deliberate failure", "class" }) do
				if not text:find(wanted, 1, true) then
					fail(scenario, "the bug report leaves out " .. wanted)
				end
			end
			if text:find("|cff", 1, true) then
				fail(scenario, "the bug report is full of colour codes, which is not what"
					.. " anybody wants pasted into an issue")
			end
			-- Read-only: it exists to be copied out of, and anything typed in
			-- would be overwritten the next time it is opened.
			if report.set then report.set({ "report" }, "typed over") end
			if report.get() ~= text then
				fail(scenario, "the report box kept what was typed into it")
			end
			button.func()
			if not report.hidden() then
				fail(scenario, "the button does not shut the box again")
			end
		end
	end
	-- The deliberate failure is this scenario's own, and the later ones read
	-- ns.errors as a symptom.
	wipe(ns.errors)
end

-- ------------------------------------------------------------------ 97
-- Every control on the Prompt tab is a secure attribute or a texture on a
-- secure frame, and ApplyStyle gives up and returns for the length of a fight.
-- The values are kept and flushed when it ends; what was missing was anything
-- saying so, so for the length of a fight every slider on the tab did nothing
-- at all and looked exactly as it does when it works.
Mock.reset()
Mock.inCombat = true
ns = load("the prompt tab says when it is frozen")
if ns then
	local scenario = "the prompt tab says when it is frozen"
	drive(scenario, ns)

	local notice = ns.optionsTable and ns.optionsTable.args.appearance.args.combatNotice
	if not (notice and notice.hidden) then
		fail(scenario, "the tab still says nothing about being in combat")
	else
		if notice.hidden() then
			fail(scenario, "in combat, and the tab reads as though everything on it works")
		end
		Mock.inCombat = false
		if not notice.hidden() then
			fail(scenario, "out of combat, and the tab still claims to be frozen")
		end

		-- And the window has to be told to redraw, because that `hidden` is
		-- only ever asked while AceConfig is drawing. Without it the notice
		-- stands over controls that work again for as long as the window stays
		-- open.
		Mock.optionsRepaints = 0
		ns.addon:PLAYER_REGEN_ENABLED()
		if Mock.optionsRepaints == 0 then
			fail(scenario, "leaving combat left the notice standing on an open window")
		end
		Mock.optionsRepaints = 0
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		if Mock.optionsRepaints == 0 then
			fail(scenario, "a fight starting under an open window put no notice up")
		end
	end
end
Mock.inCombat = false

-- ------------------------------------------------------------------ 98
-- "Load a set" replaces a box somebody may have spent ten minutes filling, with
-- no undo anywhere in the addon -- while "Reset position", which is undone by
-- dragging the prompt back, was the one control on the page that asked first.
Mock.reset()
ns = load("the destructive control is the one that asks")
if ns then
	local scenario = "the destructive control is the one that asks"
	drive(scenario, ns)

	local click = ns.optionsTable and ns.optionsTable.args.click
	local preset = click and click.args.preset
	if not preset then
		fail(scenario, "SKIPPED -- there is no phrase set dropdown")
	elseif not preset.confirm then
		fail(scenario, "loading a set still wipes hand-written lines without asking")
	else
		local question = preset.confirm
		if type(question) == "function" then question = question({ "preset" }, "polite") end
		if type(question) ~= "string" or question == "" then
			fail(scenario, "the confirmation does not say what it is about to do")
		elseif not question:lower():find("polite", 1, true) then
			fail(scenario, "the confirmation does not name the set being loaded: "
				.. tostring(question))
		end
	end

	local reset = ns.optionsTable and ns.optionsTable.args.appearance.args.reset
	if reset and reset.confirm then
		fail(scenario, "moving the prompt back to where it started still asks for confirmation,"
			.. " while overwriting hand-written text did not")
	end
end

-- ------------------------------------------------------------------ 99
-- Speaking at the wrong player, which is the one output of this addon another
-- human reads.
--
-- aura.sourceUnit is a unit token, and nameplate tokens are recycled here: the
-- token that meant one player when a buff landed can mean a different one a
-- moment later. The caster was read at the announcement rather than when the
-- aura was seen, and a scan that throws its own reading away for doubting it
-- hands the aura to the next scan to notice -- which asks the client who that
-- token is now. The debt, the chat line, the amber prompt and the /say the
-- click speaks all come off that name.
Mock.reset()
ns = load("the favour names who was there, not who is there now")
if ns then
	local scenario = "the favour names who was there, not who is there now"
	drive(scenario, ns)
	wipe(ns.owed)

	-- The buff lands while the client is refusing one of the other slots, so
	-- the scan that sees it is not believed and announces nothing.
	Mock.extraAura = 3400
	Mock.auraHidden = { [1] = true }
	ns.addon:UNIT_AURA(nil, "player")
	if ns.auraScan.doubt ~= "refused" then
		fail(scenario, "SKIPPED -- the refused slot was not recognised at all: "
			.. tostring(ns.auraScan.doubt))
	elseif next(ns.owed) then
		fail(scenario, "a scan that doubted itself announced a favour from "
			.. tostring(next(ns.owed)))
	else
		-- And the nameplate goes to somebody else, which takes no time at all.
		Mock.unitName = { "Brannoc", "Grimsby" }
		Mock.auraHidden = nil
		ns.addon:UNIT_AURA(nil, "player")

		if ns.owed["Brannoc Grimsby"] then
			fail(scenario, "the favour was filed against whoever was holding the token"
				.. " when it was announced, not against the caster")
		end
		if not ns.owed["Petra Stonewell"] then
			fail(scenario, "the favour went missing with the scan that first saw it")
		end
	end

	Mock.extraAura = false
	Mock.auraHidden = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 100
-- The other half of the same rule. A stranger with no nameplate cannot be
-- identified at all -- a hard limit, not an oversight -- and an aura that named
-- nobody when it was seen must not be given a name by a later scan reading
-- whoever is behind that token by then. A nameless favour is not better than
-- none; one spoken at a bystander is considerably worse.
Mock.reset()
ns = load("a favour nobody could name is not given one later")
if ns then
	local scenario = "a favour nobody could name is not given one later"
	drive(scenario, ns)
	wipe(ns.owed)

	Mock.extraAura = 3450
	Mock.extraAuraSource = nil
	Mock.auraHidden = { [1] = true }
	ns.addon:UNIT_AURA(nil, "player")
	if ns.auraScan.doubt ~= "refused" then
		fail(scenario, "SKIPPED -- the refused slot was not recognised at all: "
			.. tostring(ns.auraScan.doubt))
	else
		-- A token turns up on the aura afterwards. It is a different question
		-- wearing the same spelling.
		Mock.extraAuraSource = "nameplate1"
		Mock.auraHidden = nil
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "an aura that named nobody when it was seen was filed against "
				.. tostring(next(ns.owed)))
		end

		-- The mirror. The rule is about the sighting, not about going quiet for
		-- good after a scan the client spoiled.
		wipe(ns.owed)
		Mock.extraAura = 3451
		ns.addon:UNIT_AURA(nil, "player")
		if not next(ns.owed) then
			fail(scenario, "SKIPPED -- a favour with a readable caster went unnoticed too")
		end
	end

	Mock.extraAura = false
	Mock.auraHidden = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 101
-- Settling the baseline needs two readings that agree, and the second one used
-- to be whatever UNIT_AURA the client sent next. A character who zones in and
-- stands still gets none for minutes, and every one of those minutes is a hole:
-- anything landing inside it is in both readings and is filed as something they
-- were already carrying. The loss itself cannot be separated from the truth and
-- stays; its length can, and is asked for on the clock instead.
Mock.reset()
Mock.auraCount = 8
ns = load("the baseline settles on the clock, not on the next event")
if ns then
	local scenario = "the baseline settles on the clock, not on the next event"
	drive(scenario, ns)
	wipe(ns.owed)

	-- Into the zone. The list is not readable yet, so the scan taken on the way
	-- in has nothing to agree with.
	Mock.auraBlackout = true
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.auraBlackout = false
	if ns.auraScan.primed then
		fail(scenario, "SKIPPED -- the baseline settled off the loading screen itself")
	else
		-- Not one UNIT_AURA from here on, which is the point.
		local settled = false
		for _ = 1, 5 do
			Mock.runTimers(0.2)
			if ns.auraScan.primed then
				settled = true
				break
			end
		end
		if not settled then
			fail(scenario, "the baseline never settled without an event, so the hole after"
				.. " a zone change lasts until the client next says something")
		else
			-- And it is a delay rather than a stop: a favour after it is still a
			-- favour. Never noticing anything again would pass everything above.
			Mock.extraAura = 3500
			ns.addon:UNIT_AURA(nil, "player")
			if not next(ns.owed) then
				fail(scenario, "SKIPPED -- a real favour after the baseline settled"
					.. " went unnoticed")
			end
		end
	end

	-- And the chain stops. A client that never answers must not leave a scan
	-- running every fifth of a second for the rest of the session: past the
	-- count the baseline goes back to waiting for an event, which is where it
	-- was before any of this existed.
	Mock.extraAura = false
	Mock.auraBlackout = true
	ns.addon:PLAYER_ENTERING_WORLD()
	local finished = true
	for _ = 1, 40 do
		if not Mock.runTimers(0.2) then
			finished = false
			break
		end
	end
	Mock.auraBlackout = false
	if not finished then
		fail(scenario, "the settling chain never stopped scheduling itself")
	elseif #Mock.timers > 0 then
		fail(scenario, "a client that never settles is still being scanned on a timer: "
			.. #Mock.timers .. " left parked")
	end

	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 102
-- Instance ids are recycled here, and the prune deliberately leaves an expired
-- entry in the baseline for one more reading -- because a single absence is
-- also exactly what a refused slot looks like. That grace scan is a window in
-- which something arriving under a dead number was matched against the corpse
-- and never seen at all, so the prune widened the very gap it exists to close.
Mock.reset()
ns = load("a recycled instance id is not the aura it replaced")
if ns then
	local scenario = "a recycled instance id is not the aura it replaced"
	drive(scenario, ns)
	wipe(ns.owed)

	Mock.extraAura = 3600
	ns.addon:UNIT_AURA(nil, "player")
	if not next(ns.owed) then
		fail(scenario, "SKIPPED -- the first cast of it was never noticed")
	else
		-- It runs out, and one reading fails to find it. The entry is still in
		-- the baseline for this scan and only this scan.
		wipe(ns.owed)
		Mock.extraAura = false
		ns.addon:UNIT_AURA(nil, "player")

		-- The client hands that number straight back to a different spell.
		Mock.extraAura = 3600
		Mock.extraAuraSpell = 21562
		ns.addon:UNIT_AURA(nil, "player")
		if not next(ns.owed) then
			fail(scenario, "a different spell arriving under a recycled number was matched"
				.. " against the dead entry and never seen")
		end

		-- The ordinary re-buff, where the number and the spell both match the
		-- entry that died. The only thing that separates the two readings is
		-- that a cast which replaced another ends later than the one it
		-- replaced, so that is the only thing asked.
		wipe(ns.owed)
		Mock.extraAuraSpell = nil
		Mock.extraAura = 3700
		ns.addon:UNIT_AURA(nil, "player")
		wipe(ns.owed)
		Mock.extraAura = false
		ns.addon:UNIT_AURA(nil, "player")
		Mock.extraAura = 3700
		Mock.extraAuraUntil = 2600
		ns.addon:UNIT_AURA(nil, "player")
		if not next(ns.owed) then
			fail(scenario, "a re-buff arriving under its own predecessor's number was"
				.. " matched against the dead entry and never seen")
		end

		-- And the restraint that has to come with it. A client that declines one
		-- slot for one reading and hands the same aura back is the other half of
		-- this shape, and it must stay silent -- announcing on the absence is
		-- what invented favours out of a refusal of the trailing slots. The
		-- ending is unchanged here, and that is what says so.
		wipe(ns.owed)
		Mock.refuseWith = "nil"
		Mock.auraHidden = { [3] = true }
		ns.addon:UNIT_AURA(nil, "player")
		if ns.auraScan.doubt then
			fail(scenario, "SKIPPED -- the silently refused slot was recognised as a"
				.. " refusal, so nothing below is being tested: "
				.. tostring(ns.auraScan.doubt))
		end
		Mock.auraHidden = nil
		ns.addon:UNIT_AURA(nil, "player")
		if next(ns.owed) then
			fail(scenario, "an aura the client withheld for one reading came back as an"
				.. " invented favour from " .. tostring(next(ns.owed)))
		end
	end

	Mock.extraAura = false
	Mock.extraAuraSpell = nil
	Mock.extraAuraUntil = nil
	Mock.auraHidden = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 103
-- A click writes two things on the assumption it landed -- a twelve-second
-- cooldown on that buff, and the rotation pointer -- and parks a record so
-- they can be taken back when the game says otherwise. Every path that lets go
-- of that record has to take them back first, and one did not: the abandon
-- cleared the slot above its own staleness test and returned on a comment
-- saying the sweep would deal with it. The sweep reads that slot, so nilling it
-- is exactly what stops the sweep ever running, and both writes stood at full
-- length over a press that cast nothing.
--
-- Reachable because the sweep runs on the tick: at a slow scan interval a
-- record outlives its window by seconds before anything looks at it, and a
-- second press inside that gap used to swallow it whole.
Mock.reset()
Mock.class = "PRIEST"
ns = load("an abandoned press still gets its writes back")
if ns then
	local scenario = "an abandoned press still gets its writes back"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick

		-- One press, from nothing: no leftover record, no leftover blocks, and
		-- no pointer, so what is read back afterwards can only have come from
		-- this press and its undoing. Then three seconds with no tick -- a
		-- two-second scan interval, a loading screen, a lag spike -- which is
		-- how a record comes to be past its window and still in the slot.
		local function pressAndStale()
			ns.pendingClick = nil
			wipe(ns.tried)
			ns.lastGave[name] = nil
			Mock.advance(1)
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			if post then pcall(post, button, "LeftButton", true) end
			local blocked = ns.tried[name .. "\0" .. buffKey]
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to abandon")
				return false
			end
			if not blocked or blocked < GetTime() + 5 then
				fail(scenario, "SKIPPED -- the press wrote no per-buff cooldown to rewind")
				return false
			end
			Mock.advance(3)
			return true
		end

		local function check(how)
			if ns.pendingClick then
				fail(scenario, how .. ": the record is still parked, so the next cast"
					.. " event will be judged against a dead press")
			end
			local after = ns.tried[name .. "\0" .. buffKey]
			if after and after > GetTime() + 3 then
				fail(scenario, ("%s: the twelve-second cooldown stood over a press that"
					.. " cast nothing, %s seconds left"):format(how,
					tostring(math.floor(after - GetTime()))))
			end
			if ns.lastGave[name] ~= nil then
				fail(scenario, how .. ": the rotation pointer stayed forward, so an"
					.. " unreadable person is walked on to the next buff by a press that"
					.. " cast nothing -- " .. tostring(ns.lastGave[name]))
			end
		end

		-- All three ways a dead record can be found by something other than the
		-- sweep. Each one used to clear the slot and return, and each one left
		-- both writes standing.
		if pressAndStale() then
			ns.AbandonPendingClick()
			check("a second press")
		end
		if pressAndStale() then
			ns.addon:UI_ERROR_MESSAGE(nil, nil, "Your bags are full.")
			check("an error")
		end
		if pressAndStale() then
			-- A cast event this late belongs to something the player did, not
			-- to that press -- but the press is still owed its undoing.
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
			check("a later cast event")
		end
	end

	ns.pendingClick = nil
	wipe(ns.tried)
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 104
-- A selfCast buff took the confirmed tick -- the strongest thing the panel can
-- say -- on the weakest evidence in the settle path. The targeted branch, which
-- deliberately stops at "sent", at least has a /target of ours aimed at this
-- person and recorded at press time. Battle Shout has none: no /target by
-- construction, no recipient in the cast event, and nothing anywhere tying the
-- spell to the person named. That it reached them is an assumption about where
-- they were standing.
Mock.reset()
Mock.class = "WARRIOR"
Mock.groupSize = 3
ns = load("a selfCast buff is sent, not confirmed")
if ns then
	local scenario = "a selfCast buff is sent, not confirmed"
	local known = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff or not entry.buff.selfCast then
		fail(scenario, "SKIPPED -- the offer was not a selfCast buff")
	else
		local name = entry.name
		local ours = ns.FindBuff("WARRIOR", entry.buff.key).ranks[1]
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		local regions = ns.Prompt:Regions()

		ns.db.profile.verbose = true
		ns.pendingClick = nil
		wipe(ns.tried)
		ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
		Mock.advance(1)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		if post then pcall(post, button, "LeftButton", true) end

		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press left nothing to settle")
		elseif not ns.pendingClick.selfCast then
			fail(scenario, "SKIPPED -- the record does not know the macro was selfCast")
		else
			local before = #Mock.printed
			-- The shout goes out. There is no recipient to report and the
			-- client reports none.
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, ours)

			-- It still settles. Refusing to would make every debt a warrior is
			-- owed permanent, which is the bug this branch was written for.
			if ns.owed[name] then
				fail(scenario, "the selfCast settle stopped clearing the debt, so a warrior"
					.. " repays the same person forever")
			end

			local line = tostring(regions.name:GetText() or "")
			if line:find("buffed", 1, true) then
				fail(scenario, "the panel confirmed a buff that nothing ties to the person"
					.. " named: " .. line)
			end
			if not line:find("sent", 1, true) then
				fail(scenario, "the selfCast settle said nothing on the panel at all: " .. line)
			end

			-- And the claim underneath it is about this macro rather than the
			-- targeted one's. There is no /target here to not be confirmed.
			local sub = tostring(regions.sub:GetText() or "")
			if sub:find("who to", 1, true) then
				fail(scenario, "the panel blamed a client that would not name a recipient,"
					.. " for a cast that has no recipient to name: " .. sub)
			end

			local said
			for i = before + 1, #Mock.printed do
				if Mock.printed[i]:find("counted as repaid", 1, true) then
					said = Mock.printed[i]
				end
			end
			if said and said:find("macro aimed at them", 1, true) then
				fail(scenario, "the chat line credited a /target the selfCast macro cannot"
					.. " contain: " .. said)
			end
		end
	end

	ns.pendingClick = nil
	wipe(ns.tried)
	wipe(ns.owed)
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 105
-- UNIT_SPELLCAST_SENT is the client saying it sent the cast, not the server
-- saying it took it. The refusal arrives a moment later -- out of range, line
-- of sight, they moved -- and by then the settle had cleared the record, so the
-- failure handler returned on its first line and the whole thing was dropped:
-- no red flash, no chat line, a tick left standing over a cast that was thrown
-- away, and the debt marked repaid.
--
-- Undoing a confirmation is the one direction in this addon where an
-- unreadable value may not be waved through, and the first version waved
-- everything through. It ran from UI_ERROR_MESSAGE, which carries no spell id
-- at all, into a check that treats a missing id as ours -- so any complaint the
-- game made inside two seconds of a settle reopened the debt and announced that
-- the cast had been refused, including for settles the client itself had
-- confirmed. Everything below the first block is the shapes that must NOT move
-- it, because each of them did.
Mock.reset()
Mock.class = "PRIEST"
ns = load("a refusal after the send undoes the confirmation")
if ns then
	local scenario = "a refusal after the send undoes the confirmation"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		local regions = ns.Prompt:Regions()

		-- Press, and let the client report the send with the person named --
		-- the one branch that takes the confirmed tick. `gap` is how long since
		-- the settle before it, which matters: two settles inside one window
		-- cannot be told apart by a refusal and the addon keeps neither, so every
		-- check below that has to have a record kept leaves a clear gap first.
		--
		-- Each send carries a cast guid of its own, kept in `lastGuid`, and a
		-- refusal that is to be the answer to it has to name it: a guid is the
		-- only thing allowed to tie a refusal to a cast that settled. With
		-- `anonymous` the client withholds it, and nothing ever can.
		local sent, lastGuid = 0, nil
		local function settleAfter(gap, anonymous)
			Mock.advance(gap)
			ns.pendingClick = nil
			wipe(ns.tried)
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to settle")
				return false
			end
			sent = sent + 1
			lastGuid = not anonymous and ("Cast-" .. sent) or nil
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, lastGuid, ours)
			if ns.owed[name] then
				fail(scenario, "SKIPPED -- the send never settled, so there is no"
					.. " confirmation to undo")
				return false
			end
			return true
		end

		local function sendAndConfirm(anonymous) return settleAfter(3, anonymous) end

		-- The server's answer, one frame later, on the one event that names the
		-- cast it is refusing.
		if sendAndConfirm() then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", lastGuid, ours)

			if not ns.owed[name] then
				fail(scenario, "a cast the server refused stayed filed as a favour repaid")
			end
			local line = tostring(regions.name:GetText() or "")
			local sub = tostring(regions.sub:GetText() or "")
			if line:find("buffed", 1, true) then
				fail(scenario, "the tick stayed up over a refused cast: " .. line)
			end
			if not line:find("could not buff", 1, true) then
				fail(scenario, "a refusal arriving after the send said nothing at all: " .. line)
			end
			if not sub:find("refused", 1, true) then
				fail(scenario, "the panel did not say what happened: " .. sub)
			end
			local held = ns.tried[name .. "\0" .. buffKey]
			if held and held > GetTime() + 3 then
				fail(scenario, ("the twelve-second cooldown stood over a refused cast:"
					.. " %s seconds left"):format(tostring(math.floor(held - GetTime()))))
			end
		end

		-- Somebody else's cast failing in the same moment must not take a good
		-- confirmation down with it. It has a guid of its own.
		if sendAndConfirm() then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-somebody-else", 999999)
			if ns.owed[name] then
				fail(scenario, "an unrelated spell failing undid a confirmed cast")
			end
		end

		-- Nor a failure the client would not name, on a client that named
		-- nothing on the send either. Everywhere else in this addon an
		-- unreadable value has to settle, because one withheld number must not
		-- make a favour permanent -- but here the same leniency reopens a repaid
		-- debt on no evidence whatever, so it is refused in this direction only.
		-- Two withheld guids are not a match.
		if sendAndConfirm(true) then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, nil)
			if ns.owed[name] then
				fail(scenario, "a failure the client would not put a spell id on undid a"
					.. " confirmed cast, which is every failure it will not name")
			end
		end

		-- And the one that did the damage: UI_ERROR_MESSAGE carries no spell id
		-- at all, so it is evidence that something went wrong and evidence about
		-- nothing in particular. A full bag half a second after a settle is not
		-- the server refusing our buff.
		if sendAndConfirm() then
			ns.addon:UI_ERROR_MESSAGE(nil, nil, "Your bags are full.")
			if ns.owed[name] then
				fail(scenario, "a game error with no spell id on it reopened a repaid debt, so"
					.. " any complaint inside two seconds of a settle undoes it")
			end
			local line = tostring(regions.name:GetText() or "")
			if line:find("could not buff", 1, true) then
				fail(scenario, "the panel called a cast refused on an error that says nothing"
					.. " about it: " .. line)
			end
		end

		-- Two settles inside one window. The refusal names a spell and nothing
		-- else, and both presses carry the same buff, so nothing the game sends
		-- can say which cast it answers -- and it used to be applied to whichever
		-- settled last. Undoing the wrong person's repayment is the same damage as
		-- missing one, with a false sentence about them on top.
		if sendAndConfirm() and settleAfter(0.5) then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, ours)
			if ns.owed[name] then
				fail(scenario, "one refusal was applied to one of two casts it cannot be"
					.. " told apart from")
			end
		end

		-- And it does not come back on its own: a third settle a second after
		-- those two is still inside the second one's window, so it may not take
		-- the slot either. Tracking only the record made this the shape that
		-- refilled it -- two settles cleared it and the next one wrote to it.
		if settleAfter(1) then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, ours)
			if ns.owed[name] then
				fail(scenario, "a run of settles cleared the slot and then refilled it, so a"
					.. " refusal owed to an earlier cast undid a later one")
			end
		end

		-- It is a window, not a memory. An error minutes later is about
		-- somebody's bags, and undoing a settled favour on the strength of one
		-- would be its own way of never repaying anybody.
		if sendAndConfirm() then
			Mock.advance(30)
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", lastGuid, ours)
			if ns.owed[name] then
				fail(scenario, "a refusal half a minute later raised a settled favour from"
					.. " the dead")
			end
		end

		-- A switched-off addon is the same lie told louder, which is the rule
		-- NoteFavour keeps at the other end of this same write. With the prompt
		-- hidden and nothing that can pay the debt back, restoring it put it on
		-- disk and said so out loud for a favour nobody was being offered.
		if sendAndConfirm() then
			ns.db.profile.verbose = true
			ns.db.profile.enabled = false
			local before = #Mock.printed
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", lastGuid, ours)
			if ns.owed[name] then
				fail(scenario, "a switched-off addon raised a debt it has no way of repaying")
			end
			for i = before + 1, #Mock.printed do
				if Mock.printed[i]:find("still owed", 1, true) then
					fail(scenario, "a switched-off addon announced a favour it is not tracking: "
						.. Mock.printed[i])
				end
			end
			ns.db.profile.enabled = true
		end
	end

	ns.pendingClick = nil
	wipe(ns.tried)
	wipe(ns.owed)
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 106
-- The panel held for a fight has one duty: to name whoever the frozen macro
-- will cast on. A click's confirmation is written straight over the name line,
-- and when its half-second ran out inside a fight the combat branch rewrote
-- only the line underneath it -- so "buffed <whoever you pressed>" stood as the
-- panel's title for the rest of that fight while the macro under it was armed
-- at, and would cast on, the next person in the queue.
--
-- The flash itself is the other half. It used to call Show on the secure button
-- first, which Blizzard refuses for the length of the fight: a refused Hide is
-- invisible, but a refused Show is the confirmation not appearing, which is the
-- entire feature. Everything it is made of lives on art, and art is ours.
Mock.reset()
ns = load("the held panel names who the macro is aimed at")
if ns then
	local scenario = "the held panel names who the macro is aimed at"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local function cand(who)
			local e = {}
			for k, v in pairs(template) do e[k] = v end
			e.name, e.short, e.reason, e.priority = who, who, "owed", 1
			e.targetName = ns.TargetName(who)
			return e
		end
		local pressed, after = cand("Ana Field"), cand("Bo Stone")
		-- The press is what takes the person pressed off the queue, so by the
		-- time their confirmation lands the panel has already moved on. That is
		-- the ordinary case, not a contrived one.
		ns.BuildQueue = function() return { after } end

		local db = ns.db.profile
		db.prompt.hideInCombat = false
		local button = ns.Prompt:GetButton()
		-- The client refuses Show, Hide and SetAttribute on this frame for the
		-- length of a fight and says nothing about refusing them. The mock
		-- writes them down instead, which is the only way a scenario can tell a
		-- panel painted on art from one painted through a call that never ran.
		Mock.protect(button)
		local post = button.scripts.PostClick
		local regions = ns.Prompt:Regions()
		local ours = ns.FindBuff(ns.caps.class, pressed.buff.key).ranks[1]

		wipe(ns.tried)
		ns.pendingClick = nil
		ns.owed[pressed.name] = { expires = GetTime() + 100, at = GetTime() }
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(pressed)
		if post then pcall(post, button, "LeftButton", true) end

		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press left nothing to settle")
		else
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", pressed.name, nil, ours)
			local macro = tostring(button:GetAttribute("macrotext1") or "")
			local flash = tostring(regions.name:GetText() or "")
			if not macro:find(after.name, 1, true) then
				fail(scenario, "SKIPPED -- the queue did not move on, so there is nothing for"
					.. " the panel to disagree with: " .. macro)
			elseif not flash:find("Ana", 1, true) then
				fail(scenario, "SKIPPED -- the press was never confirmed on the panel: " .. flash)
			else
				-- The fight starts inside the outcome's half second.
				Mock.inCombat = true
				Mock.protectedCalls = {}
				ns.addon:PLAYER_REGEN_DISABLED()

				local held = tostring(regions.name:GetText() or "")
				if not held:find("Ana", 1, true) then
					fail(scenario, "the confirmation vanished the moment the fight started,"
						.. " which is when a click is least likely to be watched: " .. held)
				end
				if #Mock.protectedCalls > 0 then
					fail(scenario, "the flash called " .. table.concat(Mock.protectedCalls, ", ")
						.. " on the secure button in combat, where the client refuses it -- so"
						.. " the one thing that makes the confirmation appear is the one thing"
						.. " that does not happen")
				end

				-- And half a second later, with the fight still on.
				Mock.advance(2)
				Mock.protectedCalls = {}
				ns.Prompt:Refresh()
				local title = tostring(regions.name:GetText() or "")
				if title:find("Ana", 1, true) then
					fail(scenario, "the confirmation for the press on Ana Field became the"
						.. " panel's title for the rest of the fight, over a macro armed at"
						.. " somebody else: " .. title)
				end
				if not title:find("Bo", 1, true) then
					fail(scenario, "the held panel names nobody at all while the macro under it"
						.. " is armed at Bo Stone: " .. title)
				end
				if #Mock.protectedCalls > 0 then
					fail(scenario, "repainting the held panel called "
						.. table.concat(Mock.protectedCalls, ", ") .. " on the secure button,"
						.. " which the client refuses in combat")
				end
				if not tostring(regions.sub:GetText() or ""):find("held", 1, true) then
					fail(scenario, "the panel stopped saying it was held: "
						.. tostring(regions.sub:GetText()))
				end
			end
		end
	end
	Mock.inCombat = false
	ns.pendingClick = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 107
-- The combat dim was put on in the branch that knows about lockdown and taken
-- off at the far end of Refresh, which four branches return before reaching.
-- Preview is the one that never heals: it stays alive for as long as the
-- options window is open, so a preview started during a fight sat at 0.55 alpha
-- indefinitely -- a mock-up that looks held, being used to judge a size and a
-- position, long after the fight it borrowed the dim from.
--
-- Starting one in a fight is refused now, so the dim is met the other way in:
-- a preview started as the fight ends, ahead of the event that says it has.
Mock.reset()
ns = load("a preview does not keep the dim of a fight that has ended")
if ns then
	local scenario = "a preview does not keep the dim of a fight that has ended"
	drive(scenario, ns)
	local regions = ns.Prompt:Regions()

	-- The window is open, which is the one place a preview is of any use and
	-- the reason it can outlive the fight it was started in.
	Mock.optionsOpen = true
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()

	if regions.art:GetAlpha() >= 1 then
		fail(scenario, "SKIPPED -- the panel never dimmed for the fight")
	else
		-- A preview is no longer started in a fight (scenario 243), so the one
		-- that can still find the dim on is one started the moment the lockdown
		-- lifts, before PLAYER_REGEN_ENABLED has reached this addon and
		-- repainted. Its own Refresh is then the first pass out of the fight,
		-- and preview returns above the far end of Refresh.
		Mock.inCombat = false
		if not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the preview would not start")
		elseif regions.art:GetAlpha() < 1 then
			fail(scenario, ("the fight ended and the preview stayed dimmed at %s: the"
				.. " release is at the bottom of Refresh and preview returns above it")
				:format(tostring(regions.art:GetAlpha())))
		end
		ns.addon:PLAYER_REGEN_ENABLED()
	end

	if ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
	Mock.optionsOpen = false
	Mock.inCombat = false
end

-- ------------------------------------------------------------------ 108
-- The tooltip has two lines for "we do not know whether they have it", and they
-- blame different people: one says the client would not say, the other says the
-- user switched the checking off. The grace-window fallback built its entry
-- without the field that tells them apart, and a missing field reads as the
-- second -- so somebody whose options say to check was told, on their own
-- instruction, that nothing was being checked.
Mock.reset()
Mock.class = "PRIEST"
ns = load("a tokenless favour does not blame the user for what it could not read")
if ns then
	local scenario = "a tokenless favour does not blame the user for what it could not read"
	local known = {}
	for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local db = ns.db.profile
	-- A name no unit token carries, so only the fallback can queue it.
	ns.owed["Vann Locke"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }

	local function offered()
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Vann Locke" then return entry end
		end
	end

	local function tooltipFor(entry)
		ns.Prompt:ApplyTarget(entry)
		Mock.tooltip = {}
		local onEnter = ns.Prompt:GetButton().scripts.OnEnter
		if onEnter then pcall(onEnter, ns.Prompt:GetButton()) end
		return table.concat(Mock.tooltip, "\n")
	end

	db.filters.whenBuffed = "skip"
	local entry = offered()
	if not entry then
		fail(scenario, "SKIPPED -- the tokenless favour was not offered at all")
	else
		if entry.checked ~= true then
			fail(scenario, "the entry says checking was switched off ("
				.. tostring(entry.checked) .. ") while the options say to check")
		end
		local said = tooltipFor(entry)
		if said:find("set by your options", 1, true) then
			fail(scenario, "the tooltip blamed the user's options for a reading nobody could"
				.. " have taken -- there is no unit token on this path at all")
		end
		if not said:find("unreadable", 1, true) then
			fail(scenario, "the tooltip says nothing at all about not knowing: " .. said)
		end

		-- And the other way round, because the line is true for somebody who
		-- did switch it off and has to keep being told so.
		db.filters.whenBuffed = "always"
		local off = offered()
		if not off then
			fail(scenario, "SKIPPED -- the favour stopped being offered with checking off")
		elseif off.checked ~= false then
			fail(scenario, "checking is switched off and the entry does not say so: "
				.. tostring(off.checked))
		elseif not tooltipFor(off):find("set by your options", 1, true) then
			fail(scenario, "the user switched the checking off and the tooltip stopped saying"
				.. " so, which is the same untruth told the other way round")
		end
	end

	db.filters.whenBuffed = "skip"
	wipe(ns.owed)
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 109
-- The Look dropdown offered "Blizzard -- default UI border" and no part of this
-- addon has ever applied a backdrop, a border or an atlas: picking it took the
-- shadow, the bevel and the stripe off and drew nothing in their place. A
-- dropdown entry that names a thing the addon does not do is worse than a
-- missing feature, because the user reads the label as the answer.
Mock.reset()
ns = load("the look dropdown offers nothing the addon does not draw")
if ns then
	local scenario = "the look dropdown offers nothing the addon does not draw"
	drive(scenario, ns)

	local db = ns.db.profile
	local regions = ns.Prompt:Regions()
	local appearance = ns.optionsTable and ns.optionsTable.args.appearance
	local look = appearance and appearance.args.style
	if not (look and look.values) then
		fail(scenario, "SKIPPED -- there is no Look dropdown to read")
	else
		-- Every value it offers has to be one the addon recognises. An entry
		-- ClampSettings does not accept is a look you can pick and never get,
		-- silently, at the next login.
		for value in pairs(look.values) do
			db.prompt.style = value
			ns.ClampSettings()
			if db.prompt.style ~= value then
				fail(scenario, ("the dropdown offers %q and the profile repair turns it into %q")
					:format(tostring(value), tostring(db.prompt.style)))
			end
		end

		if look.values.blizzard then
			fail(scenario, "the dropdown still offers a name the addon draws nothing for")
		end

		if not look.values.framed then
			fail(scenario, "SKIPPED -- there is no framed look to check")
		else
			db.prompt.style = "framed"
			ns.Prompt:ApplyStyle()
			local drawn = 0
			for _, edge in ipairs(regions.edges or {}) do
				if edge:IsShown() then drawn = drawn + 1 end
			end
			if drawn < 4 then
				fail(scenario, ("the look offered as %q draws %d of its four edges")
					:format(tostring(look.values.framed), drawn))
			end

			-- And it is the thing that tells the two looks apart, so it must
			-- not be on the other one.
			db.prompt.style = "glass"
			ns.Prompt:ApplyStyle()
			for _, edge in ipairs(regions.edges or {}) do
				if edge:IsShown() then
					fail(scenario, "the border is drawn on the glass look as well, so the two"
						.. " entries in the dropdown are the same panel")
					break
				end
			end
		end

		-- Anybody whose profile holds the old name keeps the look they picked,
		-- rather than being quietly handed the default.
		db.prompt.style = "blizzard"
		ns.ClampSettings()
		if db.prompt.style ~= "framed" then
			fail(scenario, "a profile written under the old name came back as "
				.. tostring(db.prompt.style) .. " instead of the look it asked for")
		end
	end

	db.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
end

-- ------------------------------------------------------------------ 110
-- "Offer a top-up when it is running out" did nothing whatever for a paladin.
-- The exclusive branch read the aura and dropped the second return on the
-- floor, and never looked at the mode at all -- so the one class where topping
-- up is safest was the one class it was switched off for. Recasting the
-- blessing somebody already holds replaces it with itself; every other offer
-- this branch could make replaces it with a different one.
Mock.reset()
Mock.class = "PALADIN"
ns = load("a paladin is offered the blessing that is running out")
if ns then
	local scenario = "a paladin is offered the blessing that is running out"
	local known = {}
	for _, key in ipairs({ "wisdom", "might" }) do
		for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	wipe(ns.owed)
	wipe(ns.tried)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local db = ns.db.profile
	db.filters.whenBuffed = "refresh"
	db.filters.refreshUnder = 5

	-- Carrying might with two minutes left and none of the others. Wisdom is
	-- first in the list and definitely absent, so the walk reaches the blessing
	-- they hold only by refusing to stop at the one they do not.
	Mock.held = {}
	for _, id in ipairs(ns.FindBuff("PALADIN", "might").auraIds) do Mock.held[id] = true end
	Mock.heldFor = 120

	local function offered()
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.buff then return entry end
		end
	end

	local entry = offered()
	if not entry then
		fail(scenario, "a blessing two minutes from expiring was offered no top-up at all,"
			.. " which is the whole of the refresh mode for this class")
	else
		if entry.buff.key ~= "might" then
			fail(scenario, "the top-up offered " .. tostring(entry.buff.key) .. ", which"
				.. " replaces the might they are carrying rather than renewing it")
		end
		if type(entry.remaining) ~= "number" then
			fail(scenario, "the offer carries " .. type(entry.remaining) .. " where the time"
				.. " left should be, so nothing on the prompt says it is a top-up")
		elseif math.abs(entry.remaining - 120) > 2 then
			fail(scenario, "the time left came back as " .. tostring(entry.remaining))
		end
	end

	-- The restraint, twice. A blessing with an hour to run is not running out,
	-- and the mode being off means the same thing it means for everybody else.
	-- Past the three-second aura cache each time, or the second reading is the
	-- first one again.
	Mock.heldFor = 3600
	Mock.advance(5)
	local comfortable = offered()
	if comfortable then
		fail(scenario, "a blessing with an hour left was answered with an offer of "
			.. tostring(comfortable.buff.key) .. ", so every covered paladin target is now"
			.. " permanently on the prompt")
	end

	db.filters.whenBuffed = "skip"
	Mock.heldFor = 120
	Mock.advance(5)
	local switchedOff = offered()
	if switchedOff then
		fail(scenario, "the top-up mode is switched off and a covered person was still"
			.. " offered " .. tostring(switchedOff.buff.key))
	end

	Mock.held = nil
	Mock.heldFor = nil
	db.filters.whenBuffed = "skip"
	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 111
-- The other half of 106, and much the commoner one. 106 holds a fight with
-- somebody still on the panel; this one has nobody, which is what the ordinary
-- click leaves behind: the press blocks the person it was for, the queue is
-- empty without them, and the empty-queue branch disarms the button and clears
-- `current` on its way past. A fight starting in that second used to find a
-- combat branch whose only repaint was guarded on `current` -- so neither the
-- name line nor the sub-line was ever written, and the green past-tense
-- headline from the click stood as the panel's title for the rest of the fight
-- over a button holding no macro at all. Hide is protected, so it could not be
-- taken away either.
Mock.reset()
ns = load("a held panel with nobody on it stops quoting the last click")
if ns then
	local scenario = "a held panel with nobody on it stops quoting the last click"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local pressed = {}
		for k, v in pairs(template) do pressed[k] = v end
		pressed.name, pressed.short, pressed.reason, pressed.priority =
			"Ana Field", "Ana", "owed", 1
		pressed.targetName = ns.TargetName(pressed.name)

		local db = ns.db.profile
		db.prompt.hideInCombat = false
		local button = ns.Prompt:GetButton()
		-- Nothing about a refused call is visible from Lua, so the mock writes
		-- down every protected method reached while the lockdown is on. It is
		-- the only way a scenario can tell a panel painted on art from one
		-- painted through a call that never ran.
		Mock.protect(button)
		local post = button.scripts.PostClick
		local regions = ns.Prompt:Regions()
		local ours = ns.FindBuff(ns.caps.class, pressed.buff.key).ranks[1]

		wipe(ns.tried)
		ns.pendingClick = nil
		ns.owed[pressed.name] = { expires = GetTime() + 100, at = GetTime() }
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(pressed)
		if post then pcall(post, button, "LeftButton", true) end
		-- Blocking the only candidate is what empties the queue. That is the
		-- ordinary shape of a click rather than a contrived one, and it is the
		-- route that leaves the panel with nobody on it.
		ns.BuildQueue = function() return {} end

		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", pressed.name, nil, ours)

		local flash = tostring(regions.name:GetText() or "")
		local armedAfter = tostring(button:GetAttribute("macrotext1") or "")
		if not flash:find("Ana", 1, true) then
			fail(scenario, "SKIPPED -- the press was never confirmed on the panel: " .. flash)
		elseif armedAfter ~= "" then
			fail(scenario, "SKIPPED -- the emptied queue left a macro on the button, so this"
				.. " is not the disarmed state the branch is about: " .. armedAfter)
		else
			-- The fight starts inside the outcome's half second, which is the
			-- only reason the panel is still up to be stuck at all.
			Mock.inCombat = true
			Mock.protectedCalls = {}
			ns.addon:PLAYER_REGEN_DISABLED()
			if not tostring(regions.name:GetText() or ""):find("Ana", 1, true) then
				fail(scenario, "the confirmation vanished the moment the fight started,"
					.. " which is when a click is least likely to be watched")
			end

			-- And half a second later, with the fight still on.
			Mock.advance(2)
			Mock.protectedCalls = {}
			ns.Prompt:Refresh()
			local title = tostring(regions.name:GetText() or "")
			local sub = tostring(regions.sub:GetText() or "")
			if title:find("Ana", 1, true) then
				fail(scenario, "the confirmation for the press on Ana Field became the panel's"
					.. " title for the rest of the fight, with nobody on the panel and no"
					.. " macro on the button: " .. title)
			end
			-- Not merely "something else": the panel has to say which of the two
			-- held states this is. An armed macro a fight froze still casts on a
			-- press and an emptied one does not, and only one of those is true
			-- here.
			if not sub:find("nothing armed", 1, true) then
				fail(scenario, "the held panel does not say the button is empty, so a press"
					.. " that casts nothing looks exactly like one that casts: " .. sub)
			end
			if #Mock.protectedCalls > 0 then
				fail(scenario, "repainting the held panel called "
					.. table.concat(Mock.protectedCalls, ", ") .. " on the secure button,"
					.. " which the client refuses in combat")
			end
		end
	end
	Mock.inCombat = false
	ns.pendingClick = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 112
-- Four branches of Refresh used to reach a protected method and return above
-- the branch that knows lockdown exists, so the lockdown was never consulted at
-- all: switched off, unlocked, nothing this character can cast, and preview.
-- Each of them called Show or Hide straight, was refused, and walked away
-- believing the panel had gone up or come down -- two and a half times a second
-- for the length of the fight, leaving whatever was last painted standing.
--
-- Two claims per branch, and they are not the same claim. Nothing protected may
-- be touched, and the art underneath has to be told what the panel has become,
-- because on this client saying so is the only thing left that works.
Mock.reset()
ns = load("a fight does not stop the prompt saying what it has become")
if ns then
	local scenario = "a fight does not stop the prompt saying what it has become"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local entry = {}
		for k, v in pairs(template) do entry[k] = v end
		entry.name, entry.short, entry.reason, entry.priority = "Ana Field", "Ana", "owed", 1
		entry.targetName = ns.TargetName(entry.name)

		local db = ns.db.profile
		local button = ns.Prompt:GetButton()
		Mock.protect(button)
		local regions = ns.Prompt:Regions()

		-- Armed for real before the fight, so the panel is up with a macro on
		-- it. That macro is what the fight freezes, and it is the reason these
		-- branches cannot simply go quiet: ApplyTarget can clear the name in
		-- combat and cannot clear the attribute under it.
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		local frozen = tostring(button:GetAttribute("macrotext1") or "")
		if frozen == "" then
			fail(scenario, "SKIPPED -- nothing armed, so there is no frozen macro to warn about")
		else
			Mock.inCombat = true

			local function held(what, expect)
				Mock.protectedCalls = {}
				ns.Prompt:Refresh()
				if #Mock.protectedCalls > 0 then
					fail(scenario, what .. " in combat called "
						.. table.concat(Mock.protectedCalls, ", ") .. " on the secure button,"
						.. " where the client refuses it and says nothing about refusing it")
				end
				local sub = tostring(regions.sub:GetText() or "")
				if not sub:find(expect, 1, true) then
					fail(scenario, what .. " in combat left the panel saying " .. sub
						.. " rather than " .. expect .. ", so the prompt disagrees with"
						.. " what the addon has just been told to be")
				end
				-- The macro cannot be cleared in a fight and a press still runs
				-- it. PostClick warns in those words off the same attribute, and
				-- a panel that stays quiet about it is the addon keeping the one
				-- fact a press depends on to itself.
				local name = tostring(regions.name:GetText() or "")
				if not name:find("armed", 1, true) then
					fail(scenario, what .. " in combat left the panel reading " .. name
						.. " over a macro the fight froze, which a press still casts")
				end
			end

			db.enabled = false
			held("/manners off", "switched off")
			db.enabled = true

			db.prompt.locked = false
			held("an unlocked prompt", "unlocked")
			-- "Drag to move" is an instruction, and OnDragStart refuses in combat
			-- exactly as Show does. Offering it is the panel inviting the one
			-- thing that cannot be done to it.
			if tostring(regions.name:GetText() or ""):find("Drag", 1, true) then
				fail(scenario, "an unlocked prompt told the user to drag it during a fight,"
					.. " which the client refuses as flatly as it refuses the Show above it")
			end
			db.prompt.locked = true

			local reallyKnown = ns.caps.anyKnown
			ns.caps.anyKnown = false
			held("a client with nothing to cast", "nothing this character can cast")
			ns.caps.anyKnown = reallyKnown

			-- Preview is the odd one out: everything it draws is art, so all of
			-- it is allowed in a fight, and the Show is the only part that is
			-- not. It gets the protected half of the check and not the spoken
			-- half.
			--
			-- This used to say the spoken half was skipped because a mock-up has
			-- nothing true to say about a fight, and that was wrong: a preview
			-- started in a fight painted "PREVIEW" over the macro the fight had
			-- frozen, and a press under it cast at a real person. So a preview
			-- is no longer started in a fight at all (scenario 243). One started
			-- before the fight -- the options window holds it up -- is the one
			-- left, and it was started out of combat, where its disarm is real,
			-- so there is no frozen macro under it to own up to.
			--
			-- The panel is put down, by the scenario rather than by the addon. A
			-- Show is only reached at all when the fight finds the prompt hidden,
			-- so a preview over a panel that is already up never touches the
			-- protected half and proves nothing about it.
			Mock.inCombat = false
			Mock.optionsOpen = true
			if not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
			Mock.inCombat = true
			button:Hide()
			Mock.protectedCalls = {}
			if not ns.Prompt:InTest() then
				fail(scenario, "SKIPPED -- the preview would not start")
			else
				ns.Prompt:Refresh()
				if #Mock.protectedCalls > 0 then
					fail(scenario, "a preview over a panel the fight found hidden called "
						.. table.concat(Mock.protectedCalls, ", ") .. " on the secure button,"
						.. " which is the one call that would have made it appear and the one"
						.. " the client refuses")
				end
				ns.Prompt:ToggleTest()
			end
			Mock.optionsOpen = false
		end
	end
	Mock.inCombat = false
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 113
-- "Wait before re-offering (seconds)", over "after you click, how long before
-- the same player can come back up". A click writes a block against the one
-- spell; the whole-person key is written in other circumstances entirely. So
-- for a class with more than one buff the page described a setting the addon
-- does not have.
--
-- The code is the half that was right. PickBuffFor is built on this block being
-- per spell -- it is what moves a priest off Fortitude and onto Divine Spirit
-- on the very next scan -- so making the setting mean what it said would have
-- put twelve seconds between the two halves of the buff walk.
--
-- Which is why this asserts the two against each other rather than either
-- alone: whatever the click blocks, the label has to be describing that. It
-- fails from both directions, because a check on wording that only knows one
-- right answer stops being a check the day the behaviour is deliberately
-- changed.
Mock.reset()
Mock.class = "PRIEST"
ns = load("the re-offer wait says which of the two things it blocks")
if ns then
	local scenario = "the re-offer wait says which of the two things it blocks"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local option = ns.optionsTable and ns.optionsTable.args["when"]
		and ns.optionsTable.args["when"].args.retryCooldown
	local entry = ns.BuildQueue()[1]
	if not option then
		fail(scenario, "SKIPPED -- there is no retry cooldown control to read")
	elseif not (entry and entry.buff) then
		fail(scenario, "SKIPPED -- nobody to click on, so nothing is blocked either way")
	else
		local text = ((type(option.name) == "function" and option.name() or option.name) .. " "
			.. (type(option.desc) == "function" and option.desc() or option.desc)):lower()

		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		wipe(ns.tried)
		ns.pendingClick = nil
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		if post then pcall(post, button, "LeftButton", true) end

		-- What the press actually blocked, read off the next scan rather than
		-- off the key the block was written under. The key is an implementation
		-- detail; who is offered is the thing the setting claims to govern.
		local stillThere, sameSpell = false, false
		for _, row in ipairs(ns.BuildQueue()) do
			if row.name == entry.name then
				stillThere = true
				if row.buff and row.buff.key == entry.buff.key then sameSpell = true end
			end
		end

		if sameSpell then
			fail(scenario, "SKIPPED -- the click blocked nothing at all, so neither reading"
				.. " of the label is being tested")
		elseif stillThere then
			-- Per spell, which is what the walk needs.
			if not text:find("spell", 1, true) then
				fail(scenario, "the click blocks one spell and the person is offered the next"
					.. " one immediately, but the page still describes a wait on the player:"
					.. " " .. text)
			end
			if text:find("the same player can come back up", 1, true) then
				fail(scenario, "the page still promises a wait before the same player can come"
					.. " back up, which is the one thing a click does not write")
			end
		else
			-- Per person. Legitimate, but then the label must not sell a walk
			-- it has just stopped.
			if text:find("per spell", 1, true) then
				fail(scenario, "the click blocks the whole person while the page says the"
					.. " block is per spell: " .. text)
			end
		end

		-- The other half of the same number, and the reading the old label was
		-- accidentally right about. A right-press is a refusal of the person,
		-- and it is the only thing in the addon that blocks one.
		wipe(ns.tried)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		if post then pcall(post, button, "RightButton", true) end
		local afterSkip = false
		for _, row in ipairs(ns.BuildQueue()) do
			if row.name == entry.name then afterSkip = true end
		end
		if afterSkip then
			fail(scenario, "a right-press left the person on the prompt, so the whole-person"
				.. " block the page now describes is not being written")
		elseif not text:find("right", 1, true) then
			fail(scenario, "the one thing this number really does to a whole person -- a"
				.. " right-click skip -- is nowhere on the page")
		end
		wipe(ns.tried)
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end

-- ------------------------------------------------------------------ 114
-- AceConfigRegistry is asked for with LibStub's silent flag on purpose: it
-- ships inside AceConfig-3.0 and will normally be there, and a missing library
-- must not take the options screen with it. Every reader checks it -- except
-- the icon slider's own setter, which called it straight, so the one absence
-- the flag exists for would have thrown from inside a set, with somebody's
-- finger on the slider.
--
-- Nothing could catch that before now, because the mock handed every library
-- out unconditionally: the absence was never modelled, so a reader that guards
-- and a reader that does not were the same reader.
Mock.reset()
Mock.missingLibs = { ["AceConfigRegistry-3.0"] = true }
ns = load("the page survives without the library that repaints it")
if ns then
	local scenario = "the page survives without the library that repaints it"
	drive(scenario, ns)

	local function mustNotThrow(what, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then fail(scenario, what .. " threw without AceConfigRegistry -> "
			.. tostring(err)) end
	end

	-- The wrapper every other caller goes through, and the two events that
	-- reach it on their own.
	mustNotThrow("RefreshOptionsDisplay", ns.RefreshOptionsDisplay)
	mustNotThrow("leaving combat", function() ns.addon:PLAYER_REGEN_ENABLED() end)
	mustNotThrow("entering combat", function() ns.addon:PLAYER_REGEN_DISABLED() end)

	local appearance = ns.optionsTable and ns.optionsTable.args.appearance
	local slider = appearance and appearance.args.iconSize
	if not (slider and slider.set) then
		fail(scenario, "SKIPPED -- there is no icon slider whose setter to call")
	else
		local before = ns.db.profile.prompt.iconSize
		mustNotThrow("moving the icon slider", slider.set, { "iconSize" }, before + 4)
		-- And it still did its job. Wrapping the whole setter in a pcall, or
		-- returning early out of it, would keep the run green while quietly
		-- making the slider do nothing on a client without the library.
		if ns.db.profile.prompt.iconSize == before then
			fail(scenario, "the icon slider wrote nothing at all without the library, so it"
				.. " survives the absence by not working")
		end
	end

	-- The other execute that repaints the page from a button press.
	local report = ns.optionsTable and ns.optionsTable.args.diagnostics
		and ns.optionsTable.args.diagnostics.args.copyReport
	if report and report.func then
		mustNotThrow("opening the bug-report box", report.func)
		mustNotThrow("shutting the bug-report box", report.func)
	end
end
Mock.missingLibs = nil

-- ------------------------------------------------------------------ 115
-- The reason colour, and the two places it can go.
--
-- The description named three colours and there are four: soft green is what
-- somebody you targeted yourself gets, and that priority is on by default, so
-- green is what most people see most often.
--
-- And both carriers are switched off from somewhere other than the dropdown
-- that asks for them. ApplyStyle refuses the stripe on the framed look; the
-- ring is a texture behind the icon, so hiding the icon takes it -- and so does
-- rounding the icon off, which puts a mask where the ring was. Pick the ring,
-- round the icon, and the page reads "Ring around the icon" over a prompt with
-- no reason colour anywhere on it and nothing saying why.
Mock.reset()
ns = load("the reason colour is described in full and has somewhere to go")
if ns then
	local scenario = "the reason colour is described in full and has somewhere to go"
	drive(scenario, ns)

	local p = ns.db.profile.prompt
	p.accentByReason = true

	-- How many colours the prompt really has, asked of the code that paints
	-- them rather than counted out of a table by hand -- and which family each
	-- one reads as, by its strongest channel, so a word in the description can
	-- be held to a colour that is actually painted. The target colour moved
	-- from green to a pale cyan and the description went on saying green.
	local function family(r, g, b)
		if math.max(r, g, b) - math.min(r, g, b) < 0.15 then return "grey" end
		if r >= g and r >= b then return "amber" end
		if g > r and g > b then return "green" end
		return "blue"
	end
	local seen, distinct, painted = {}, 0, {}
	for _, reason in ipairs({ "target", "owed", "group", "nearby" }) do
		local r, g, b = ns.Prompt:AccentColor(reason)
		local key = ("%.3f/%.3f/%.3f"):format(r, g, b)
		if not seen[key] then
			seen[key] = true
			distinct = distinct + 1
		end
		painted[family(r, g, b)] = true
	end

	local toggle = ns.optionsTable and ns.optionsTable.args.appearance.args.accentByReason
	local desc = toggle and (type(toggle.desc) == "function" and toggle.desc() or toggle.desc)
	if type(desc) ~= "string" then
		fail(scenario, "SKIPPED -- the reason-colour toggle has no description to read")
	else
		-- Every mention, not every distinct word: two of the four are blues,
		-- told apart by how light they are, and the description has to name
		-- both of them.
		local named = 0
		for _, word in ipairs({ "green", "amber", "blue", "grey" }) do
			for _ in desc:lower():gmatch(word) do named = named + 1 end
			if desc:lower():find(word, 1, true) and not painted[word] then
				fail(scenario, ("the description promises %s, and the prompt never paints"
					.. " it: %s"):format(word, desc))
			end
		end
		if distinct < 2 then
			fail(scenario, "SKIPPED -- the prompt paints " .. distinct .. " distinct reason"
				.. " colours, so there is nothing for the description to get wrong")
		elseif named < distinct then
			fail(scenario, ("the prompt paints %d reason colours and the description names"
				.. " %d of them: %s"):format(distinct, named, desc))
		end
	end

	-- And the note that has to appear when the colour has nowhere left to go.
	local note = ns.optionsTable and ns.optionsTable.args.appearance.args.accentDead
	local regions = ns.Prompt:Regions()
	if not (note and note.hidden and regions.iconBack) then
		fail(scenario, "SKIPPED -- no dead-accent note, or no ring to watch")
	else
		local function state(mode, style, showIcon, round)
			p.accentMode, p.style, p.showIcon, p.roundIcon = mode, style, showIcon, round
			ns.Prompt:ApplyStyle()
			return not note.hidden()
		end

		-- The ordinary default: a square icon with a ring round it.
		if state("icon", "glass", true, false) then
			fail(scenario, "a warning about a reason colour that has a ring to sit on")
		end
		if not regions.iconBack:IsShown() then
			fail(scenario, "SKIPPED -- the ring is not drawn even in the plain case, so the"
				.. " checks below cannot tell it being taken away from it never being there")
		end

		-- Rounding the icon puts a mask where the ring was. This is the one
		-- that had no symptom at all.
		if state("icon", "glass", true, true) then
			if regions.iconBack:IsShown() then
				fail(scenario, "the page says the ring is gone while the ring is still drawn")
			end
		else
			fail(scenario, "a rounded icon leaves the reason colour with nowhere to go and"
				.. " the page says nothing about it")
		end
		local said = note.name and note.name() or ""
		if not tostring(said):lower():find("round", 1, true) then
			fail(scenario, "the note does not name the setting that took the ring away: " .. said)
		end

		-- No icon at all, which takes the same ring by a different door.
		if not state("icon", "glass", false, false) then
			fail(scenario, "the ring cannot be drawn with the icon switched off, and the page"
				.. " does not say so")
		end

		-- The stripe, refused by the framed look inside ApplyStyle.
		if state("stripe", "glass", true, false) then
			fail(scenario, "a warning about a stripe that is being drawn")
		end
		if not state("stripe", "framed", true, false) then
			fail(scenario, "the framed look draws no stripe and the page does not say so")
		end

		-- Both carriers dead at once has to name both, or it sends somebody to
		-- undo the wrong setting.
		if state("both", "framed", true, true) then
			local why = tostring(note.name and note.name() or ""):lower()
			if not (why:find("round", 1, true) and why:find("framed", 1, true)) then
				fail(scenario, "two carriers were taken away and the note names one: " .. why)
			end
		else
			fail(scenario, "both carriers are gone and the page says nothing")
		end

		-- And asking for no accent is not a fault to be warned about.
		if state("off", "framed", true, true) then
			fail(scenario, "somebody switched the accent off and was warned that it is off")
		end
	end
end

-- ------------------------------------------------------------------ 116
-- A warrior's Battle Shout is cast on himself and heard by the party, so
-- CastLines builds no /target line for it and hands back restore = false with
-- it. The whole Targeting section on the click tab was therefore about a line
-- that class's macro will never contain: a toggle that does nothing, over a
-- note explaining a /target that is not there.
--
-- The same shape as the strangers toggle, which is hidden for these classes for
-- the same reason -- and it is computed rather than listed by class, so a
-- warrior who learns something targetable gets the control back on its own.
for _, case in ipairs({
	{ class = "WARRIOR", key = "battleshout", group = 3, targets = false },
	{ class = "MAGE", key = "intellect", group = 0, targets = true },
}) do
	Mock.reset()
	Mock.class = case.class
	Mock.groupSize = case.group
	local label = "the targeting switch matches what the macro does (" .. case.class .. ")"
	ns = load(label)
	if ns then
		local known = {}
		for _, id in ipairs(ns.FindBuff(case.class, case.key).ranks) do known[id] = true end
		local realKnown = IsSpellKnown
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = function(id) return known[id] == true end

		drive(label, ns)
		Mock.advance(60)
		ns.Guard("probe", ns.ProbeCapabilities)

		local entry = ns.BuildQueue()[1]
		local click = ns.optionsTable and ns.optionsTable.args.click
		local toggle = click and click.args.restoreTarget
		local note = click and click.args.noTargetNote
		local explain = click and click.args.targetingNote
		if not (entry and entry.buff) then
			fail(label, "SKIPPED -- nobody to build a macro for")
		elseif not (toggle and note and explain) then
			fail(label, "SKIPPED -- the targeting controls are not on the page")
		else
			-- What the macro really contains, so the page is judged against the
			-- behaviour rather than against the class list.
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			local macro = tostring(ns.lastMacro or "")
			local targets = macro:find(ns.TargetCommand() .. " ", 1, true) ~= nil
			if targets ~= case.targets then
				fail(label, "SKIPPED -- this class's macro was expected "
					.. (case.targets and "to target" or "not to target")
					.. " and did the opposite: " .. macro)
			else
				local hidden = toggle.hidden and toggle.hidden() and true or false
				if targets and hidden then
					fail(label, "the macro takes a target and the switch that hands it back is"
						.. " hidden")
				elseif not targets and not hidden then
					fail(label, "the page offers to hand back a target the macro never takes")
				end
				-- And the explanation goes the same way as the toggle, or one
				-- of the two describes the other class.
				local explained = explain.hidden and explain.hidden() and true or false
				if explained ~= hidden then
					fail(label, "the targeting note and the switch it explains disagree"
						.. " about whether this class targets anybody")
				end
				local saidWhy = note.hidden and note.hidden() and true or false
				if saidWhy == not targets then
					fail(label, "a class that " .. (targets and "does" or "does not")
						.. " target is given the wrong half of the targeting section")
				end
			end
		end

		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown
	end
end

-- ------------------------------------------------------------------ 117
-- "Hide in combat" hid nothing. The only call that ever read it was a
-- button:Hide() inside the combat branch -- a protected method on a protected
-- frame, refused by the client every single time it was made -- and that call
-- is now gone. A secure visibility driver could hide it ([combat] resolves
-- here; only [@Name] is restricted), but a hidden secure button still fires
-- from its key binding and /click, casting the frozen macro out of sight.
--
-- What is left is real. A click still casts the frozen macro in a fight, and
-- the confirmation flash for it is the one thing on a held panel that still
-- changes, so this decides whether it does. The label follows that, and the
-- check below holds both ends: the panel does not go away, and the setting
-- still governs the thing it is now named for.
Mock.reset()
ns = load("the combat switch does what it is called")
if ns then
	local scenario = "the combat switch does what it is called"
	drive(scenario, ns)
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	local toggle = ns.optionsTable and ns.optionsTable.args.appearance.args.hideInCombat
	if not (template and template.buff) then
		fail(scenario, "SKIPPED -- nobody to click on")
	elseif not toggle then
		fail(scenario, "SKIPPED -- the combat switch is not on the page")
	else
		local name = tostring(type(toggle.name) == "function" and toggle.name() or toggle.name)
		local desc = tostring(type(toggle.desc) == "function" and toggle.desc() or toggle.desc)

		local entry = {}
		for k, v in pairs(template) do entry[k] = v end
		entry.name, entry.short, entry.reason, entry.priority = "Ana Field", "Ana", "owed", 1
		entry.targetName = ns.TargetName(entry.name)

		local button = ns.Prompt:GetButton()
		Mock.protect(button)
		local regions = ns.Prompt:Regions()
		local post = button.scripts.PostClick
		local ours = ns.FindBuff(ns.caps.class, entry.buff.key).ranks[1]

		-- The sub-line, not the title. A held panel keeps naming `current` --
		-- correctly, because the frozen macro is still aimed at them -- so the
		-- name reads "Ana" whether the flash was painted or suppressed, and a
		-- check on the title would have passed for the wrong reason.
		local function clickInCombat(quiet)
			Mock.inCombat = false
			wipe(ns.tried)
			ns.pendingClick = nil
			ns.owed[entry.name] = { expires = GetTime() + 100, at = GetTime() }
			ns.db.profile.prompt.hideInCombat = quiet
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			-- Put up by hand. The last press of the drive above blocked its own
			-- candidate, so the panel is down by the time we get here -- and a
			-- fight that finds it down proves nothing about whether a branch
			-- would have taken it down.
			button:Show()
			Mock.inCombat = true
			if post then pcall(post, button, "LeftButton", true) end
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", entry.name, nil, ours)
			Mock.protectedCalls = {}
			ns.Prompt:Refresh()
			return tostring(regions.sub:GetText() or "")
		end

		local loud = clickInCombat(false)
		local shownWhileLoud = button:IsShown()
		local hushed = clickInCombat(true)

		if loud:find("held", 1, true) or loud == "" then
			fail(scenario, "SKIPPED -- the click was never confirmed on the panel even with the"
				.. " switch off, so there is nothing for it to suppress: " .. loud)
		elseif not hushed:find("held", 1, true) then
			fail(scenario, "the switch is on and the prompt still flashed the click's outcome"
				.. " during the fight: " .. hushed)
		end

		-- The half the old label promised and the client refuses. Both states
		-- have to leave the panel standing, because Hide is protected.
		if not (shownWhileLoud and button:IsShown()) then
			fail(scenario, "the panel came down during a fight, which the client does not"
				.. " allow and no branch should believe it has done")
		end
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the combat repaint called "
				.. table.concat(Mock.protectedCalls, ", ") .. " on the secure button")
		end
		if name:lower():find("hide", 1, true) then
			fail(scenario, "the switch is still called \"" .. name .. "\" over a panel it"
				.. " cannot hide and no longer tries to")
		end
		if not desc:lower():find("flash", 1, true) then
			fail(scenario, "the switch does not say what it actually governs, which is the"
				.. " click's confirmation flash: " .. desc)
		end
	end
	Mock.inCombat = false
	ns.pendingClick = nil
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ 118
-- Two labels that were narrower than the code under them.
--
-- The strangers description named nameplates, your target and your mouseover.
-- IterateUnits walks your focus as well, so a genuine way of reaching somebody
-- read like one the addon does not have.
--
-- And the chat switch was called "Print a line in my chat when someone buffs
-- me", which is one of the seven things it prints. The others are the ones
-- worth having it on for: what each click turned into. Somebody reading the old
-- label had no reason to switch it on to find out why a buff went nowhere,
-- which is the question it answers best.
Mock.reset()
-- A different person on the focus token, so `seen` cannot collapse them into
-- the target and report a pass for a token nothing visits.
Mock.unitNames = { focus = { "Iris", "Quill" } }
ns = load("the page names every source and everything the chat line says")
if ns then
	local scenario = "the page names every source and everything the chat line says"
	drive(scenario, ns)
	Mock.advance(60)

	local onFocus = false
	for _, row in ipairs(ns.BuildQueue()) do
		if row.name == "Iris Quill" then onFocus = true end
	end
	local strangers = ns.optionsTable and ns.optionsTable.args.who.args.strangers
	local sources = strangers and tostring(type(strangers.desc) == "function"
		and strangers.desc() or strangers.desc):lower()
	if not sources then
		fail(scenario, "SKIPPED -- the strangers toggle has no description to read")
	elseif not onFocus then
		fail(scenario, "SKIPPED -- nobody was reached through the focus token, so the"
			.. " description cannot be judged against it")
	elseif not sources:find("focus", 1, true) then
		fail(scenario, "somebody is offered through your focus and the list of ways"
			.. " passers-by are seen does not mention it: " .. sources)
	end

	-- The chat switch, judged by what it prints rather than by its own word.
	local verbose = ns.optionsTable and ns.optionsTable.args.general.args.verbose
	if not verbose then
		fail(scenario, "SKIPPED -- the chat switch is not on the page")
	else
		ns.db.profile.verbose = true
		Mock.printed = {}
		-- A press the game never answered. Nobody buffed anybody here, so
		-- anything printed is by definition not the favour line. Run out by
		-- the tick, the way the addon itself notices it: the function that
		-- does the expiring is local to Core, and asking ns for it called nil.
		ns.pendingClick = { name = "Ana Field", at = GetTime() - 30, buffKey = "intellect" }
		ns.addon:Tick()
		local said = table.concat(Mock.printed, " | ")
		local text = ((type(verbose.name) == "function" and verbose.name() or verbose.name)
			.. " " .. (type(verbose.desc) == "function" and verbose.desc() or verbose.desc)):lower()

		-- What was printed has to be the addon's line about the press, not a
		-- Lua error caught on the way to it -- which reads as "something was
		-- printed" just as well, and judged the switch by an error string.
		if said:find("something broke", 1, true) then
			fail(scenario, "SKIPPED -- the unanswered press threw instead of printing: " .. said)
		elseif said == "" then
			fail(scenario, "SKIPPED -- nothing was printed for a click that went nowhere, so"
				.. " the switch has only the one job the old label gave it")
		elseif not (text:find("click", 1, true) or text:find("cast", 1, true)) then
			fail(scenario, "the switch printed \"" .. said .. "\" for a click, and the page"
				.. " still describes it as a line for when somebody buffs you: " .. text)
		end
		ns.pendingClick = nil
	end
end
Mock.unitNames = nil

-- ------------------------------------------------------------------ 119
-- "How long a favour stays offerable once we can no longer see the player."
-- Nothing in the addon can see a player walk off. The fallback that offers
-- somebody we hold no token for measures from the moment they buffed you --
-- that instant is the whole of the evidence, because it is the one time they
-- were provably in casting range -- so a person standing right where they were
-- is let go on the same schedule as one who left immediately.
--
-- Asserted from the behaviour first, so the wording is being checked against
-- the clock the code really runs on rather than against a better sentence.
Mock.reset()
ns = load("the grace window counts from the buff, and says so")
if ns then
	local scenario = "the grace window counts from the buff, and says so"
	drive(scenario, ns)
	Mock.advance(60)

	local db = ns.db.profile
	db.filters.reachableOnly = true
	db.timing.graceSeconds = 45

	-- Somebody we hold no unit token for: every token in the mock answers to
	-- one name, and this is not it. That is the ordinary case for a passer-by
	-- who buffed you, and the only path the grace window governs.
	local function offered(age)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.owed["Yorick Vane"] = { expires = GetTime() + 600, at = GetTime() - age }
		for _, row in ipairs(ns.BuildQueue()) do
			if row.name == "Yorick Vane" then return true end
		end
		return false
	end

	local option = ns.optionsTable and ns.optionsTable.args.who.args.graceSeconds
	local desc = option and tostring(type(option.desc) == "function"
		and option.desc() or option.desc):lower()
	if not desc then
		fail(scenario, "SKIPPED -- there is no grace control to read")
	elseif not offered(10) then
		fail(scenario, "SKIPPED -- a fresh favour is not offered at all, so nothing below"
			.. " distinguishes the clock from a switched-off source")
	elseif offered(120) then
		fail(scenario, "SKIPPED -- a favour well past the window is still offered, so the"
			.. " window is not the thing being measured")
	elseif not desc:find("buff", 1, true) then
		fail(scenario, "the window runs from the moment they buffed you and the page does"
			.. " not say so: " .. desc)
	end
	wipe(ns.owed)
	wipe(ns.tried)
end

-- ------------------------------------------------------------------ 106
-- Matching a late refusal to the press it answers.
--
-- This was a timestamp standing in for a question it could not answer. Two
-- settles inside one window threw both records away -- which is the buff walk
-- working as designed, press, next buff, press -- and a record already consumed
-- by a refusal went on suppressing the next press for the rest of the window.
--
-- The client hands both cast events a guid and both handlers discarded it.
Mock.reset()
ns = load("a refusal is matched to the press it answers")
if ns then
	local scenario = "a refusal is matched to the press it answers"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local buff = ns.CastableBuffs()[1]
	if not buff then
		fail(scenario, "SKIPPED -- nothing castable to press with")
	else
		local spell = buff.ranks[1]

		-- Straight at the settle path: what is under test is which record a
		-- refusal is read against, not how the button arms.
		local function press(who, guid)
			ns.owed[who] = { expires = GetTime() + 100, at = GetTime() }
			ns.pendingClick = { name = who, at = GetTime(), buffKey = buff.key,
				selfCast = false, targeted = true }
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", who, guid, spell)
			if ns.owed[who] then
				fail(scenario, "SKIPPED -- the send never settled for " .. who)
				return false
			end
			return true
		end

		-- (a) A record the refusal already consumed must stop suppressing the
		--     next press. This is the one that needed no guid to go wrong; each
		--     refusal names its own cast now only because nothing else may
		--     undo a settle at all.
		wipe(ns.owed)
		if press("Elara Brightmoor", "Cast-a1") then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-a1", spell)
			if not ns.owed["Elara Brightmoor"] then
				fail(scenario, "SKIPPED -- the first refusal did not land")
			else
				wipe(ns.owed)
				Mock.advance(0.4)
				if press("Corvin Ashgrove", "Cast-a2") then
					ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-a2", spell)
					if not ns.owed["Corvin Ashgrove"] then
						fail(scenario, "a press was ignored because an earlier one had"
							.. " already been answered")
					end
				end
			end
		end

		-- (b) Two presses inside one window, told apart by the guid the client
		--     sends. Only the refused one is undone.
		Mock.advance(5)
		wipe(ns.owed)
		if press("Elara Brightmoor", "Cast-1") and (Mock.advance(0.5) or true)
			and press("Corvin Ashgrove", "Cast-2") then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-2", spell)
			if not ns.owed["Corvin Ashgrove"] then
				fail(scenario, "the refusal named a cast and the press it belonged to"
					.. " was still filed as repaid")
			end
			if ns.owed["Elara Brightmoor"] then
				fail(scenario, "a refusal undid somebody else's repayment")
			end
		end

		-- (c) The same pair with nothing to tell them apart. Abstaining is the
		--     right answer: undoing the wrong person's repayment is the same
		--     damage plus a false sentence about somebody who was buffed. (With
		--     one record it is still the answer -- see 228.)
		Mock.advance(5)
		wipe(ns.owed)
		if press("Elara Brightmoor", nil) and (Mock.advance(0.5) or true)
			and press("Corvin Ashgrove", nil) then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, spell)
			if ns.owed["Elara Brightmoor"] or ns.owed["Corvin Ashgrove"] then
				fail(scenario, "two records could equally have been meant and one was"
					.. " picked anyway")
			end
		end

		-- (d) A guid naming none of our casts is somebody else's spell failing.
		Mock.advance(5)
		wipe(ns.owed)
		if press("Petra Stonewell", "Cast-9") then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-nothing-of-ours", spell)
			if ns.owed["Petra Stonewell"] then
				fail(scenario, "a failure that named a different cast undid ours")
			end
		end

		wipe(ns.owed)
		ns.pendingClick = nil
	end
end

-- ------------------------------------------------------------------ 107
-- An end-to-end assertion, deliberately about the outcome and not the layer
-- that provides it: a character the client says can cast nothing must end up
-- with nothing armed and no press on file.
--
-- Today BuildQueue is what guarantees it -- it returns nothing once
-- caps.anyKnown is false, so no candidate ever reaches the button -- which
-- means removing the matching clause from the click path's own predicate does
-- NOT turn this red. That is recorded here rather than left to be discovered:
-- this scenario pins the behaviour, not the mechanism, and if the queue ever
-- stops being the thing that stops it, this is what will notice.
Mock.reset()
ns = load("nothing castable means nothing is armed and no press is recorded")
if ns then
	local scenario = "nothing castable means nothing is armed and no press is recorded"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local entry = ns.BuildQueue()[1]
	local button = ns.Prompt:GetButton()
	if not entry or not entry.buff or not button then
		fail(scenario, "SKIPPED -- nobody to arm against")
	else
		ns.Prompt:ApplyTarget(entry)
		if not button.attributes["macrotext1"] then
			fail(scenario, "SKIPPED -- the arm did not take, so losing it proves nothing")
		else
			-- The client comes back and says this character knows none of them.
			ns.caps.anyKnown = false
			ns.pendingClick = nil
			wipe(ns.tried)

			local pre = button.scripts.PreClick
			if pre then pcall(pre, button, "LeftButton", true) end
			if button.attributes["macrotext1"] then
				fail(scenario, "a macro stayed armed for a character with nothing to cast")
			end

			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end
			if ns.pendingClick then
				fail(scenario, "a press was filed against "
					.. tostring(ns.pendingClick.name)
					.. " by a character that cannot cast anything")
			end

			ns.caps.anyKnown = true
		end
	end
end

-- ------------------------------------------------------------------ 120
-- Which client this is, read off the interface number.
--
-- The band trap gets its own assertion because it is the one that would never
-- be reported: Forever says 16001 and Classic Era says 11509, both five digits
-- beginning with a 1. A matcher working on a prefix -- or on how many digits
-- there are -- calls Forever vanilla, and vanilla content is exactly what
-- Forever runs, so the addon would half-work forever and nobody would have a
-- symptom to describe.
local FLAVOURS = {
	{ interface = 120100, flavour = "mainline", family = "modern" },
	{ interface = 16001, flavour = "camelot", family = "modern" },
	{ interface = 50504, flavour = "mists", family = "classic" },
	{ interface = 20506, flavour = "tbc", family = "classic" },
	{ interface = 11509, flavour = "vanilla", family = "classic" },
}
for _, want in ipairs(FLAVOURS) do
	local scenario = "interface " .. want.interface .. " is " .. want.flavour
	Mock.reset()
	Mock.interface = want.interface
	-- The three Classic flavours still have the combat log; the two modern ones
	-- refuse the registration. Set here so the probe is answered by a client
	-- that behaves like the one the number claims to be.
	Mock.combatLog = (want.family == "classic")
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local f = ns.Flavour or {}
		if f.flavour ~= want.flavour then
			fail(scenario, "called it " .. tostring(f.flavour))
		end
		if f.family ~= want.family then
			fail(scenario, "put it in the " .. tostring(f.family) .. " family")
		end
		if f.interface ~= want.interface then
			fail(scenario, "recorded the interface as " .. tostring(f.interface))
		end
		if f.recognised ~= true then
			fail(scenario, "did not recognise a number it has a band for")
		end
		-- The one line a bug report from this client would carry.
		local summary = ns.FlavourSummary()
		if not summary:find(want.flavour, 1, true)
			or not summary:find(tostring(want.interface), 1, true) then
			fail(scenario, "the pasteable summary says: " .. summary)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 121
-- An interface number nobody here has seen.
--
-- Classified, never rejected. A client this addon does not recognise still has
-- somebody sitting in front of it, and an addon that refuses to load is a worse
-- answer than one that carries on with the family it can infer. 40400 is
-- Cataclysm Classic, which is retired -- a number that was live a year ago is
-- exactly the shape the next one will arrive in.
Mock.reset()
Mock.interface = 40400
ns = load("an interface number with no band")
if ns then
	local scenario = "an interface number with no band"
	drive(scenario, ns)
	local f = ns.Flavour or {}
	if f.flavour ~= "unknown" then
		fail(scenario, "claimed to recognise 40400 as " .. tostring(f.flavour))
	end
	if f.family ~= "modern" and f.family ~= "classic" then
		fail(scenario, "left the family as " .. tostring(f.family)
			.. ", so nothing downstream has anything to branch on")
	end
	if f.recognised ~= false then
		fail(scenario, "reported an unknown number as recognised")
	end
	-- Read and written down even though it matched no band. A client nobody
	-- here has seen is precisely the one whose number has to survive into the
	-- bug report, and a detector that gives up on an unknown number loses it.
	if f.interface ~= 40400 then
		fail(scenario, "lost the interface number it could not classify: "
			.. tostring(f.interface))
	end
	if f.err ~= nil then
		fail(scenario, "treated an unrecognised number as a failure: " .. tostring(f.err))
	end
	-- drive() ends with a click, which puts the candidate in the retry
	-- cooldown; the clock has to move before the queue refills.
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	if #ns.BuildQueue() == 0 then
		fail(scenario, "an unrecognised client was left with nobody to offer")
	end
end

-- ------------------------------------------------------------------ 122
-- The nil == nil trap, which is the reason the project id is never compared
-- against a constant directly.
--
-- On a client with none of these globals, `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC`
-- is nil == nil, so every one of those tests passes at once and the first one
-- written wins. Here that would be Mists: a modern client would be handed the
-- Classic family, told the combat log is available, and the registration that
-- follows throws.
Mock.reset()
Mock.interface = 40400
local savedProjects = {
	WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC,
	WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_MISTS_CLASSIC,
}
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = nil, nil, nil
WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_MISTS_CLASSIC = nil, nil
ns = load("a client with no project constants at all")
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC =
	savedProjects[1], savedProjects[2], savedProjects[3]
WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_MISTS_CLASSIC =
	savedProjects[4], savedProjects[5]
if ns then
	local scenario = "a client with no project constants at all"
	drive(scenario, ns)
	local f = ns.Flavour or {}
	if f.flavour ~= "unknown" then
		fail(scenario, "nil == nil decided this client is " .. tostring(f.flavour))
	end
	if f.family == "classic" then
		fail(scenario, "nil == nil put a client with no constants in the classic"
			.. " family, which is where the combat log is assumed to work")
	end
	if f.project ~= nil then
		fail(scenario, "invented a project id of " .. tostring(f.project))
	end
end

-- ------------------------------------------------------------------ 123
-- A client with no GetBuildInfo at all.
--
-- Flavour.lua is the first file the toc names, so anything it throws takes the
-- whole addon with it before there is a slash command to ask what went wrong.
Mock.reset()
local realGetBuildInfo = GetBuildInfo
GetBuildInfo = nil
ns = load("a client with no GetBuildInfo")
GetBuildInfo = realGetBuildInfo
if ns then
	local scenario = "a client with no GetBuildInfo"
	drive(scenario, ns)
	local f = ns.Flavour or {}
	if f.flavour ~= "unknown" then
		fail(scenario, "decided on " .. tostring(f.flavour) .. " with nothing to read")
	end
	if f.family ~= "modern" then
		fail(scenario, "guessed the " .. tostring(f.family)
			.. " family when there was nothing to go on")
	end
	if not ns.FlavourSummary():find("GetBuildInfo", 1, true) then
		fail(scenario, "said nothing about why it could not tell: "
			.. ns.FlavourSummary())
	end
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	if #ns.BuildQueue() == 0 then
		fail(scenario, "a client that will not say what it is was left with"
			.. " nobody to offer")
	end
end

-- ------------------------------------------------------------------ 124
-- What the probe makes of WoW Forever, which is the client that must not move.
Mock.reset()
ns = load("capabilities on Forever")
if ns then
	local scenario = "capabilities on Forever"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	local caps = ns.caps

	if caps.flavour ~= "camelot" or caps.family ~= "modern" then
		fail(scenario, "the probe carried " .. tostring(caps.flavour)
			.. "/" .. tostring(caps.family))
	end
	-- The probe deliberately does NOT run here. Registering the combat log on a
	-- modern client is the forbidden action itself: a pcall catches a throw, but
	-- a client that answers by raising ADDON_ACTION_FORBIDDEN instead puts a
	-- popup with this addon's name on it in front of the user, for a question
	-- the flavour had already answered. nil means "not asked", which is the
	-- whole point, and is distinct from the false an unrecognised client gets.
	if caps.combatLogProbe ~= nil then
		fail(scenario, "asked the client a question that is itself forbidden here: "
			.. tostring(caps.combatLogProbe))
	end
	if caps.combatLog ~= false then
		fail(scenario, "believed the combat log is available here")
	end
	-- The assumption, stated: Forever keeps /target + /targetlasttarget.
	if caps.conditionalTargeting ~= false then
		fail(scenario, "offered conditional targeting on the one client whose"
			.. " behaviour is not allowed to change")
	end
	if caps.unitNameIsSurname ~= true then
		fail(scenario, "read UnitName's second return as a realm here, where it"
			.. " is a surname")
	end
	if caps.targetExact ~= true or caps.unitConditionals ~= true then
		fail(scenario, ("missed a command this client has: /targetexact=%s @unit=%s")
			:format(tostring(caps.targetExact), tostring(caps.unitConditionals)))
	end
end

-- ------------------------------------------------------------------ 125
-- And of a Classic client, where the same questions have the other answers.
Mock.reset()
Mock.interface = 11509
Mock.combatLog = true
ns = load("capabilities on Classic Era")
if ns then
	local scenario = "capabilities on Classic Era"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	local caps = ns.caps

	if caps.combatLog ~= true then
		fail(scenario, "gave up the combat log on a client that still has it")
	end
	if caps.combatLogProbe ~= true then
		fail(scenario, "a registration this client accepts was read as a refusal")
	end
	if caps.conditionalTargeting ~= true then
		fail(scenario, "withheld conditional targeting from a client that has it")
	end
	if caps.unitNameIsSurname ~= false then
		fail(scenario, "read UnitName's second return as a surname off Camelot,"
			.. " which turns a realm into part of somebody's name")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 126
-- Secret restrictions are probed, not inferred from C_Secrets being there.
--
-- The namespace was backported to clients that are not withholding anything, so
-- "the table exists" and "I am being kept out of something" are two questions.
-- This addon has already answered the wrong one once.
Mock.reset()
Mock.secretRestrictions = false
ns = load("C_Secrets present and nothing actually restricted")
if ns then
	local scenario = "C_Secrets present and nothing actually restricted"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	if ns.caps.hasSecrets ~= true then
		fail(scenario, "SKIPPED -- C_Secrets was not there, so this proves nothing")
	elseif ns.caps.secretRestrictions ~= false then
		fail(scenario, "read the namespace being present as restrictions being"
			.. " applied: secretRestrictions=" .. tostring(ns.caps.secretRestrictions))
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 127
-- A client without /targetexact falls back rather than reporting one it has not
-- got. /target matches a name prefix, so believing in a command that is not
-- there is how "/target Mort" ends up buffing Mortimer.
Mock.reset()
local savedSecureCmdList, savedSlashExact = SecureCmdList, SLASH_TARGET_EXACT1
SecureCmdList, SLASH_TARGET_EXACT1 = { TARGET = function() end }, nil
ns = load("a client without /targetexact")
if ns then
	local scenario = "a client without /targetexact"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	if ns.caps.targetExact ~= false then
		fail(scenario, "claimed /targetexact on a client that does not have it")
	end
end
SecureCmdList, SLASH_TARGET_EXACT1 = savedSecureCmdList, savedSlashExact

-- ------------------------------------------------------------------ 128
-- /manners debug names the client, and names it for a class with nothing to
-- cast.
--
-- Four of the five clients cannot be tested by anybody who works on this addon,
-- so one user running one command is the whole of the evidence -- and it is
-- only evidence if it says which client it came from. The rogue is the case
-- that matters: the command returns early for a class with no buffs, and that
-- early return used to be above every line describing the build.
Mock.reset()
Mock.class = "ROGUE"
ns = load("debug names the client for a class with nothing to cast")
if ns then
	local scenario = "debug names the client for a class with nothing to cast"
	drive(scenario, ns)

	Mock.printed = {}
	ns.addon:HandleSlash("debug")
	local said = table.concat(Mock.printed, "\n")
	if not said:find("camelot", 1, true) then
		fail(scenario, "never named the flavour: " .. said)
	end
	if not said:find("interface=16001", 1, true) then
		fail(scenario, "never named the interface number: " .. said)
	end
	if not said:find("conditional=", 1, true) then
		fail(scenario, "never said whether conditional targeting is available: " .. said)
	end
	if not said:find("@unit=", 1, true) then
		fail(scenario, "never said whether the @unit form is available: " .. said)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 129
-- No buff table at all.
--
-- ipairs over nil throws, and a file that throws while loading does not leave a
-- broken addon behind -- it leaves no addon at all: no frame, no slash command,
-- and no error for anybody who has not turned script errors on. From the user's
-- side that is exactly what not having installed it looks like. Nothing can
-- produce it today; the per-flavour split of the buff data is what will, the
-- first time a flavour has no branch.
Mock.reset()
ns = load("no buff table for this client")
if ns then
	local scenario = "no buff table for this client"
	drive(scenario, ns)

	local realPrint = print
	local said = {}
	print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		said[#said + 1] = table.concat(parts, " ")
	end
	ns.BUFFS = nil
	local ok, err = pcall(ns.BuildBuffLookups)
	print = realPrint

	if not ok then
		fail(scenario, "building the lookups with no table threw, which during"
			.. " load means the addon does not exist: " .. tostring(err))
	end
	if not ns.BUFFS_MISSING then
		fail(scenario, "no table, and nothing recorded to say so")
	elseif not tostring(ns.BUFFS_MISSING):find("camelot", 1, true) then
		fail(scenario, "said the table was missing without saying on which"
			.. " client: " .. tostring(ns.BUFFS_MISSING))
	end
	if #said == 0 then
		fail(scenario, "said nothing out loud, so the user sees an addon that"
			.. " is installed and silent")
	end

	-- Leaving an empty table behind is half the guard's job: every reader of
	-- ns.BUFFS downstream indexes it without asking, so a nil here throws from
	-- somewhere else entirely -- the first slash command, in the middle of a
	-- handler nothing wraps -- and the report is about that place instead.
	if type(ns.BUFFS) ~= "table" then
		fail(scenario, "left ns.BUFFS as " .. type(ns.BUFFS)
			.. ", so the next reader of it throws somewhere unrelated")
	end

	-- And /manners debug repeats it, for the report that arrives later.
	Mock.printed = {}
	local spoke = pcall(ns.addon.HandleSlash, ns.addon, "debug")
	if not spoke then
		fail(scenario, "/manners debug threw with no buff table, so the one"
			.. " command that could explain the silence is gone too")
	elseif not table.concat(Mock.printed, "\n"):find("no buff data", 1, true) then
		fail(scenario, "debug did not mention that there is no buff data at all")
	end

	-- The mirror: a real table leaves no complaint behind and rebuilds the
	-- lookups, so deleting the guard's `else` path cannot pass by doing nothing.
	ns.BUFFS = { MAGE = { { key = "intellect", ranks = { 1459 } } } }
	ns.BuildBuffLookups()
	if ns.BUFFS_MISSING then
		fail(scenario, "a table that is there was still reported missing")
	end
	if not ns.ALL_BUFF_IDS[1459] or ns.BUFF_BY_ID[1459] == nil then
		fail(scenario, "the lookups were not rebuilt from a table that is there")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 130
-- A toc whose file list has a typo in it.
--
-- The same dead-addon failure as the one above, arriving from the other
-- direction: the client loads the files it can find, the missing one's chunk
-- never runs, and every symbol it was meant to define is nil. Nothing is said
-- and nothing appears, so it looks exactly like not having installed it.
-- tests/validate.py is what stops a typo reaching a release; this is what keeps
-- the diagnostic alive if one ever does, because /manners debug is then the
-- only thing left that can name the missing file.
--
-- Loaded by hand rather than through load(), since the whole point is a file
-- list that is missing an entry.
Mock.reset()
do
	local scenario = "a toc that lost Flavour.lua from its file list"
	local short = {}
	local loaded = true
	for _, file in ipairs({ "Buffs.lua", "Core.lua", "Prompt.lua", "Options.lua" }) do
		local chunk, err = loadfile(dir .. "/" .. file)
		if not chunk then
			fail(scenario, "load " .. file .. ": " .. tostring(err))
			loaded = false
			break
		end
		local ok, runErr = pcall(chunk, "Manners", short)
		if not ok then
			fail(scenario, "run " .. file .. ": " .. tostring(runErr))
			loaded = false
			break
		end
	end

	if loaded then
		drive(scenario, short)

		Mock.printed = {}
		local spoke = pcall(short.addon.HandleSlash, short.addon, "debug")
		if not spoke then
			fail(scenario, "/manners debug threw with Flavour.lua missing, so"
				.. " the one command that could name the missing file is gone")
		elseif not table.concat(Mock.printed, "\n")
			:find("Flavour.lua did not load", 1, true) then
			fail(scenario, "debug never said which file failed to load: "
				.. table.concat(Mock.printed, "\n"))
		end

		-- And the second consequence, which arrived with the per-flavour split:
		-- the buff tables are chosen from ns.Flavour, so a client that never
		-- loaded it has no spells either. That is the "installed and silent"
		-- failure exactly, so it has to be said as well -- an addon that quietly
		-- fell back to one flavour's data here would be guessing which client
		-- this is, which is the thing Flavour.lua exists to stop.
		if short.BUFFS_MISSING == nil then
			fail(scenario, "no flavour, and the buff data it selects was reported"
				.. " as present anyway")
		end
		if type(short.BUFFS) ~= "table" or type(short.CLASSES_WITHOUT_BUFFS) ~= "table"
			or type(short.EXCLUSIVE_BUFFS) ~= "table" or type(short.CLASS_AUTO) ~= "table" then
			fail(scenario, "left one of the four buff tables as something other"
				.. " than a table, so the next reader of it throws somewhere"
				.. " unrelated")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 131
-- Each client is handed its own spells.
--
-- A wrong table here has no symptom worth the name: the spells still cast, the
-- prompt still appears, and one class is quietly never offered anything because
-- the id it was given belongs to a spell this client deleted six expansions
-- ago. The three vanilla-content flavours share one set on purpose -- Forever
-- runs vanilla content and those tables are the only ones verified in game --
-- and the assertions below say so, so that sharing cannot be undone by accident.
local BUFF_SETS = {
	{
		interface = 11509, flavour = "vanilla", set = "vanilla", classic = true,
		has = { PALADIN = "wisdom", PRIEST = "spirit", DRUID = "thorns", WARLOCK = "breath" },
		absent = { "MONK", "EVOKER", "DEATHKNIGHT" },
		without = { "HUNTER", "ROGUE", "SHAMAN" },
		exclusive = { PALADIN = true },
	},
	{
		interface = 20506, flavour = "tbc", set = "vanilla", classic = true,
		has = { PALADIN = "wisdom", PRIEST = "spirit", DRUID = "thorns" },
		absent = { "MONK", "EVOKER", "DEATHKNIGHT" },
		without = { "HUNTER", "ROGUE", "SHAMAN" },
		exclusive = { PALADIN = true },
	},
	{
		interface = 16001, flavour = "camelot", set = "vanilla",
		has = { PALADIN = "wisdom", PRIEST = "spirit", DRUID = "thorns" },
		absent = { "MONK", "EVOKER", "DEATHKNIGHT" },
		without = { "HUNTER", "ROGUE", "SHAMAN" },
		exclusive = { PALADIN = true },
	},
	{
		interface = 50504, flavour = "mists", set = "mists", classic = true,
		has = { PALADIN = "kings", MONK = "whitetiger", WARLOCK = "darkintent",
			DEATHKNIGHT = "hornofwinter" },
		-- Removed from the game by 5.5, and every one of them a spell this
		-- addon offered on the flavour above.
		gone = { PALADIN = "wisdom", PRIEST = "spirit", DRUID = "thorns" },
		absent = { "EVOKER" },
		without = { "HUNTER", "ROGUE", "SHAMAN" },
		exclusive = { PALADIN = true },
	},
	{
		interface = 120100, flavour = "mainline", set = "mainline",
		has = { SHAMAN = "skyfury", EVOKER = "bronze", MAGE = "intellect",
			PRIEST = "fortitude" },
		absent = { "PALADIN", "DEATHKNIGHT", "MONK", "WARLOCK" },
		-- Three classes that used to be the backbone of this addon, and the
		-- shaman moving the other way: totems on vanilla, Skyfury on retail.
		without = { "PALADIN", "DEATHKNIGHT", "HUNTER", "ROGUE", "WARLOCK", "MONK" },
		exclusive = {},
	},
}
for _, want in ipairs(BUFF_SETS) do
	local scenario = want.flavour .. " gets the " .. want.set .. " spells"
	Mock.reset()
	Mock.interface = want.interface
	-- The client behaves like the one its number claims to be: the three
	-- Classic flavours still hand addons the combat log, the two modern ones
	-- throw on the registration.
	Mock.combatLog = want.classic == true
	ns = load(scenario)
	if ns then
		drive(scenario, ns)

		if not tostring(ns.BUFFS_SOURCE):find(want.set, 1, true) then
			fail(scenario, "says its buff data came from "
				.. tostring(ns.BUFFS_SOURCE))
		end
		if ns.BUFFS_MISSING then
			fail(scenario, "a flavour with a set of its own reported none: "
				.. tostring(ns.BUFFS_MISSING))
		end

		for class, key in pairs(want.has) do
			if not ns.FindBuff(class, key) then
				fail(scenario, ("%s has no %s, which is one of this client's"):format(class, key))
			end
		end
		for class, key in pairs(want.gone or {}) do
			if ns.FindBuff(class, key) then
				fail(scenario, ("%s is still offered %s, which this client does not have")
					:format(class, key))
			end
		end
		for _, class in ipairs(want.absent) do
			if ns.BUFFS[class] then
				fail(scenario, class .. " was given spells on a client where it has none")
			end
		end
		for _, class in ipairs(want.without) do
			if ns.CLASSES_WITHOUT_BUFFS[class] ~= true then
				fail(scenario, class .. " has nothing to give here and the options"
					.. " page is not allowed to say so")
			end
		end
		for class in pairs(want.exclusive) do
			if ns.EXCLUSIVE_BUFFS[class] ~= true then
				fail(scenario, class .. "'s buffs replace one another here, so the"
					.. " walk would take away what the last click gave")
			end
		end

		-- The contradiction, which is the mistake a hand-maintained pair of
		-- lists actually makes: a class in both is told it has nothing while
		-- holding a list of spells, and which of the two the user is shown
		-- depends on which screen they opened.
		for class in pairs(ns.BUFFS) do
			if ns.CLASSES_WITHOUT_BUFFS[class] then
				fail(scenario, class .. " is in the buff tables and in the list of"
					.. " classes with nothing to offer")
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 132
-- A retail paladin, which is the class this round deletes.
--
-- Kings, Might and Wisdom went in 7.0.3 and Blessing of the Seasons in 12.0.0,
-- so a paladin on Midnight has nothing to put on a passer-by. "Nothing" has to
-- arrive as the honest sentence a rogue already gets, not as an empty prompt, a
-- silent addon, or an error -- the class is listed in the tables above it on
-- every other client, so every path here is one that used to find spells.
Mock.reset()
Mock.interface = 120100
Mock.class = "PALADIN"
ns = load("a retail paladin is told so plainly")
if ns then
	local scenario = "a retail paladin is told so plainly"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	if ns.caps.hasClassBuffs ~= false then
		fail(scenario, "found buffs for a class that has none on this client")
	end
	if #ns.BuildQueue() ~= 0 then
		fail(scenario, "offered somebody a spell this class no longer has")
	end

	Mock.printed = {}
	local spoke = pcall(ns.addon.HandleSlash, ns.addon, "debug")
	local said = table.concat(Mock.printed, "\n")
	if not spoke then
		fail(scenario, "/manners debug threw for a class with nothing to cast")
	elseif not said:find("no buffs to cast on other players", 1, true) then
		fail(scenario, "debug did not say the class has nothing: " .. said)
	end
	-- Above the early return, as ever: the report that matters most from a
	-- client nobody here can run is the one that says nothing is happening.
	if not said:find("mainline", 1, true) then
		fail(scenario, "debug never named the client or its buff data: " .. said)
	end

	local page = ns.optionsTable and ns.optionsTable.args.general
		and ns.optionsTable.args.general.args.noBuffs
	if not page then
		fail(scenario, "SKIPPED -- the page has nothing to say about a class with nothing")
	else
		local text = page.name()
		if not text:find("no buffs it can cast", 1, true) then
			fail(scenario, "the page gave the vague answer -- 'could not work out"
				.. " what you can cast' -- for a class we know has nothing: " .. text)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 133
-- One cast, thirteen auras.
--
-- Blessing of the Bronze is cast as 364342 and lands as one of thirteen
-- per-class auras, none of which share an id with it. Matching only the cast id
-- means the buff is never seen on anybody: the person you just blessed reads as
-- missing it, so every evoker in the game rebuffs the same passer-by forever,
-- and a stranger who blessed you is never recognised as having done you a
-- favour. The `group` list is what carries these -- the same field, and the same
-- matching, as the raid-wide vanilla buffs.
Mock.reset()
Mock.interface = 120100
Mock.class = "EVOKER"
ns = load("one cast that lands as thirteen different auras")
if ns then
	local scenario = "one cast that lands as thirteen different auras"
	local bronze = ns.FindBuff("EVOKER", "bronze")
	if not bronze then
		fail(scenario, "SKIPPED -- retail evokers have no Blessing of the Bronze")
	else
		local realKnown = IsSpellKnown
		IsSpellKnown = function(id) return id == bronze.ranks[1] end
		IsPlayerSpell = IsSpellKnown

		drive(scenario, ns)
		Mock.advance(60)
		ns.Guard("probe", ns.ProbeCapabilities)

		-- A stranger's Blessing arrives as one of the thirteen and nothing else,
		-- so this is the whole of "did somebody just do me a favour".
		for _, id in ipairs({ 381732, 381746, 381758 }) do
			if not ns.ALL_BUFF_IDS[id] then
				fail(scenario, id .. " is not recognised as a class buff at all,"
					.. " so being blessed with it is not a favour anybody owes back")
			elseif ns.BUFF_BY_ID[id] ~= bronze then
				fail(scenario, id .. " does not point back at the Blessing")
			end
		end

		local before = ns.BuildQueue()
		if #before == 0 then
			fail(scenario, "SKIPPED -- nobody was offered the Blessing to begin with")
		else
			-- The same person, now carrying one of the thirteen. The default is
			-- to leave somebody alone once they have it, so the queue emptying
			-- is the proof that the aura was recognised as ours.
			-- Past the three-second aura cache, which would otherwise answer
			-- this from the read taken before the buff landed.
			Mock.held = { [381732] = true }
			Mock.advance(10)
			local after = ns.BuildQueue()
			for _, entry in ipairs(after) do
				if entry.name == before[1].name and entry.buff == bronze then
					fail(scenario, "offered the Blessing to somebody already carrying"
						.. " it, because the aura it lands as is not matched")
				end
			end
			Mock.held = nil
		end

		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 134
-- The one spell Automatic must never reach for.
--
-- Unending Breath is a real warlock buff and it is in the tables so that
-- somebody who wants it can pin it. What it is not is a courtesy: handing water
-- breathing to a stranger standing in a city is the sort of thing that gets an
-- addon uninstalled. Automatic walks the class list, so without a way to say
-- "offerable, never automatic" the walk finds it the moment Dark Intent is on
-- cooldown, unknown, or switched off.
Mock.reset()
Mock.interface = 50504
Mock.combatLog = true
Mock.class = "WARLOCK"
ns = load("Automatic never hands over Unending Breath")
if ns then
	local scenario = "Automatic never hands over Unending Breath"
	local dark, breath = ns.FindBuff("WARLOCK", "darkintent"), ns.FindBuff("WARLOCK", "breath")
	if not (dark and breath) then
		fail(scenario, "SKIPPED -- a Mists warlock has no Dark Intent or no Unending Breath")
	else
		local known = { [dark.ranks[1]] = true, [breath.ranks[1]] = true }
		local realKnown = IsSpellKnown
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown

		drive(scenario, ns)
		Mock.advance(60)
		ns.Guard("probe", ns.ProbeCapabilities)

		local keys = {}
		for _, buff in ipairs(ns.CastableBuffs()) do keys[#keys + 1] = buff.key end
		local list = table.concat(keys, ",")
		if not list:find("darkintent", 1, true) then
			fail(scenario, "Dark Intent is not offered at all: " .. list)
		end
		if list:find("breath", 1, true) then
			fail(scenario, "Unending Breath is on the Automatic walk: " .. list)
		end
		if ns.ResolveBuff(true) ~= dark then
			fail(scenario, "Automatic resolved to "
				.. tostring(ns.ResolveBuff(true) and ns.ResolveBuff(true).key))
		end

		-- And with Dark Intent unlearned there is nothing to fall back to, which
		-- is the point: nobody is offered anything rather than being offered
		-- water breathing.
		known[dark.ranks[1]] = nil
		ns.Guard("probe", ns.ProbeCapabilities)
		if #ns.CastableBuffs() ~= 0 then
			fail(scenario, "fell back to Unending Breath when Dark Intent was"
				.. " unlearned")
		end
		if ns.ResolveBuff(true) ~= nil then
			fail(scenario, "Automatic resolved to something with only Unending"
				.. " Breath learned")
		end

		-- And the page says which of the four reasons this is. "Every spell is
		-- switched off" and "you have not learned any" are both false here, and
		-- both send somebody looking at controls that are already right.
		local note = ns.optionsTable and ns.optionsTable.args.who
			and ns.optionsTable.args.who.args.autoNote
		if not note then
			fail(scenario, "SKIPPED -- the page has no explanation of Automatic")
		else
			local text = note.name()
			if text:find("switched off", 1, true) or text:find("not learned any", 1, true) then
				fail(scenario, "the page blamed the switches or the spellbook for a"
					.. " spell Automatic is refusing on purpose: " .. text)
			end
			if not text:find("Unending Breath", 1, true) then
				fail(scenario, "the page does not name the spell it is holding back: "
					.. text)
			end
		end

		-- Pinned, it works like any other spell. "Never automatic" is not "never".
		known[breath.ranks[1]] = true
		ns.db.profile.buff.choice = "breath"
		ns.Guard("probe", ns.ProbeCapabilities)
		local pinned = ns.CastableBuffs()
		if #pinned ~= 1 or pinned[1] ~= breath then
			fail(scenario, "pinning Unending Breath left " .. #pinned
				.. " spells castable, so a pin that PickBuffFor never reads is a"
				.. " silent switch-off")
		end
		ns.db.profile.buff.choice = "auto"

		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 135
-- A spell id that does not exist on the client Manners is actually running on.
--
-- This is the failure with no symptom. A wrong id means the buff is never
-- offered and nothing is ever said: the spell probe reports "not learned", which
-- is indistinguishable from a character who has not learned it, and the bug
-- report is "my shaman does nothing" from a client nobody here can start. Four
-- of the five clients are in that position, so the addon checks its own data
-- against the client and complains where somebody will see it.
Mock.reset()
Mock.interface = 120100
Mock.class = "SHAMAN"
Mock.unknownSpells = { [462854] = true }
ns = load("a spell id this client has never heard of")
if ns then
	local scenario = "a spell id this client has never heard of"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local info = ns.caps.buffs.skyfury
	if not info then
		fail(scenario, "SKIPPED -- retail shamans have no Skyfury to get wrong")
	else
		if not info.unresolved or #info.unresolved == 0 then
			fail(scenario, "an id the client does not have was recorded as fine")
		end
		if ns.caps.unresolvedBuffs ~= 1 then
			fail(scenario, "counted " .. tostring(ns.caps.unresolvedBuffs)
				.. " buffs with ids this client does not have")
		end

		Mock.printed = {}
		local spoke = pcall(ns.addon.HandleSlash, ns.addon, "debug")
		local said = table.concat(Mock.printed, "\n")
		if not spoke then
			fail(scenario, "/manners debug threw on a buff whose ids do not resolve")
		elseif not said:find("462854", 1, true) then
			fail(scenario, "debug never named the id this client does not have: " .. said)
		end

		-- And on the page, for the far larger number of people who will never
		-- type a slash command.
		local diag = ns.optionsTable and ns.optionsTable.args.diagnostics
			and ns.optionsTable.args.diagnostics.args.diag
		if not diag then
			fail(scenario, "SKIPPED -- there is no diagnostics text to read")
		elseif not diag.name():find("462854", 1, true) then
			fail(scenario, "the diagnostics page says nothing about a spell this"
				.. " client does not have: " .. diag.name())
		end
	end

	-- The mirror. Every id resolving must leave no complaint behind, or the
	-- warning is decoration and the next real one is ignored.
	Mock.unknownSpells = nil
	ns.Guard("probe", ns.ProbeCapabilities)
	if ns.caps.unresolvedBuffs ~= 0 then
		fail(scenario, "complained about ids the client answered for")
	end
	Mock.printed = {}
	pcall(ns.addon.HandleSlash, ns.addon, "debug")
	if table.concat(Mock.printed, "\n"):find("never heard of", 1, true) then
		fail(scenario, "debug still reports a spell the client knows about")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 136
-- What UnitName's second return means, which is a different thing on Camelot
-- from everywhere else.
--
-- A surname joins with a space, and that is the form verified in game on
-- Camelot. A realm does not: "Mort Ravencrest" names nobody, and a realm is
-- present at all only for a player from another one. The form the game itself
-- writes is "Mort-Ravencrest", and a same-realm player gets nil back and is
-- simply "Mort".
--
-- This is the identity -- the key debts are filed under, on disk -- so the
-- assertion is about the key, and the spelling the macro aims at gets its own
-- scenario below.
for _, want in ipairs({
	{ interface = 16001, classic = false, flavour = "camelot",
		joined = "Mort Defrette", aimed = "Mort Defrette" },
	{ interface = 11509, classic = true, flavour = "vanilla",
		joined = "Mort-Defrette", aimed = "Mort" },
	{ interface = 120100, classic = false, flavour = "mainline",
		joined = "Mort-Defrette", aimed = "Mort" },
}) do
	local scenario = "UnitName's second return on " .. want.flavour
	Mock.reset()
	Mock.interface = want.interface
	Mock.combatLog = want.classic
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local realName = UnitName

		UnitName = function() return "Mort", "Defrette" end
		local key = ns.UnitFullName("target")
		if key ~= want.joined then
			fail(scenario, "filed them under '" .. tostring(key) .. "', not '"
				.. want.joined .. "'")
		end
		if ns.TargetName(key) ~= want.aimed then
			fail(scenario, "would aim at '" .. tostring(ns.TargetName(key))
				.. "', not '" .. want.aimed .. "'")
		end

		-- On Camelot nothing at all comes off the key, and that is the rule
		-- rather than an accident of the names it happens to produce. Nobody
		-- has documented what the second return is there for a player from
		-- another realm, so the join UnitFullName already makes is the only
		-- thing known to be right and no rule written for realms may reach it.
		-- Off Camelot the same string is a realm and the realm comes off.
		local odd = "Mort Defrette-Ravencrest"
		local kept = want.flavour == "camelot" and odd or "Mort Defrette"
		if ns.TargetName(odd) ~= kept then
			fail(scenario, "'" .. odd .. "' would be aimed at as '"
				.. tostring(ns.TargetName(odd)) .. "', not '" .. kept .. "'")
		end

		-- Nobody from another realm, which off Camelot is nearly everybody:
		-- one name, no separator, and above all no trailing one.
		UnitName = function() return "Mort", nil end
		if ns.UnitFullName("target") ~= "Mort" then
			fail(scenario, "a player with no second return came back as '"
				.. tostring(ns.UnitFullName("target")) .. "'")
		end
		UnitName = function() return "Mort", "" end
		if ns.UnitFullName("target") ~= "Mort" then
			fail(scenario, "an empty second return left '"
				.. tostring(ns.UnitFullName("target")) .. "'")
		end

		UnitName = realName
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 137
-- The identity and the spelling are two different strings, and each has to go
-- to the right place.
--
-- Off Camelot a cross-realm player is filed as "Vann-Ravencrest" -- that is the
-- key for debts, which are written to disk and read back after a reload, so it
-- must not move. But /target is a name search over the units the client has
-- drawn in, not a lookup of a unit id, and the realm is not part of what it
-- searches: the macro has to say "Vann".
--
-- Both halves of the queue are checked, because they get the answer from
-- different places: the main path has a unit token and the owed fallback has
-- nothing but the key.
Mock.reset()
Mock.interface = 11509
Mock.combatLog = true
Mock.unitName = { "Vann", "Ravencrest" }
ns = load("the key keeps the realm and the macro drops it")
if ns then
	local scenario = "the key keeps the realm and the macro drops it"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.tried)
	wipe(ns.owed)

	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff then
		fail(scenario, "SKIPPED -- nobody to build a macro for")
	else
		if entry.name ~= "Vann-Ravencrest" then
			fail(scenario, "filed a cross-realm player as " .. tostring(entry.name))
		end
		if entry.targetName ~= "Vann" then
			fail(scenario, "would aim the macro at " .. tostring(entry.targetName))
		end

		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		local macro = tostring(ns.lastMacro or "")
		local aimed
		for line in macro:gmatch("[^\r\n]+") do
			if line:find("^" .. ns.TargetCommand() .. " ") then aimed = line end
		end
		if aimed ~= ns.TargetCommand() .. " Vann" then
			fail(scenario, "the targeting line is '" .. tostring(aimed) .. "'")
		end

		-- And the console keeps the two apart, because working out what
		-- resolves on a client nobody here can start is the whole of what it is
		-- for. A single token that sometimes means one and sometimes the other
		-- would make every experiment run on it ambiguous.
		local expanded = ns.ExpandTokens("{name}|{aim}")
		if expanded ~= "Vann-Ravencrest|Vann" then
			fail(scenario, "/manners try expands {name}|{aim} to '" .. tostring(expanded) .. "'")
		end

		-- And the debt, which is what the key exists for: the game names the
		-- person the spell reached by the spelling the macro used, and that is
		-- not the string the debt is filed under. Judging the two against each
		-- other by eye is what this record avoids.
		ns.pendingClick = nil
		ns.owed[entry.name] = { expires = GetTime() + 100, at = GetTime() }
		local button = ns.Prompt:GetButton()
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press left nothing to settle")
		else
			if ns.pendingClick.aimedAt ~= "Vann" then
				fail(scenario, "the press recorded aiming at "
					.. tostring(ns.pendingClick.aimedAt))
			end
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Vann", nil,
				entry.buff.ranks[1])
			if ns.owed[entry.name] then
				fail(scenario, "the buff reached them under the name the macro used and"
					.. " the favour was still counted unpaid")
			end
		end
	end

	-- The tokenless half. Somebody who buffed you and walked off is offered from
	-- the debt alone, so the spelling has to come out of the key -- there is no
	-- unit left to ask.
	wipe(ns.tried)
	wipe(ns.owed)
	ns.pendingClick = nil
	ns.owed["Iris-Ravencrest"] = { expires = GetTime() + 100, at = GetTime(),
		class = "PRIEST" }
	local gone
	for _, candidate in ipairs(ns.BuildQueue()) do
		if candidate.name == "Iris-Ravencrest" then gone = candidate end
	end
	if not gone then
		fail(scenario, "SKIPPED -- the tokenless fallback offered nobody")
	elseif gone.targetName ~= "Iris" then
		fail(scenario, "the fallback would aim at " .. tostring(gone.targetName))
	end
	wipe(ns.owed)
end
Mock.reset()

-- ------------------------------------------------------------------ 138
-- The macro writes /target even where the client offers /targetexact.
--
-- That is the opposite of what it looks like it should do, so it is pinned
-- here. /target matches a name prefix, so "/target Mort" finds Mortimer
-- standing beside Mort and buffs -- and speaks at -- the wrong player, which
-- /targetexact cannot do. But the name being written is assembled from
-- UnitName's second return, and what that return MEANS is the single thing
-- this client does differently from the rest: a surname here, a realm
-- everywhere else, undocumented here for somebody from another realm. /target
-- survives a name that is slightly wrong; /targetexact finds nobody, casts
-- nothing, and looks like a broken addon.
--
-- So both clients must build /target. The probe still runs and is still
-- reported, because one live look at an assembled name is all that is needed
-- to change this, and scenario 137 is what will catch it if it changes by
-- accident instead.
for _, want in ipairs({
	{ label = "a client with /targetexact", exact = true, command = "/target" },
	{ label = "a client without /targetexact", exact = false, command = "/target" },
}) do
	Mock.reset()
	local savedList, savedSlash = SecureCmdList, SLASH_TARGET_EXACT1
	if not want.exact then
		SecureCmdList, SLASH_TARGET_EXACT1 = { TARGET = function() end }, nil
	end
	local scenario = want.label .. " builds " .. want.command
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		ns.Guard("probe", ns.ProbeCapabilities)

		if ns.caps.targetExact ~= want.exact then
			fail(scenario, "the probe said targetExact=" .. tostring(ns.caps.targetExact))
		end
		if ns.TargetCommand() ~= want.command then
			fail(scenario, "would write " .. tostring(ns.TargetCommand()))
		end

		wipe(ns.tried)
		local entry = ns.BuildQueue()[1]
		if not entry or not entry.buff or entry.buff.selfCast then
			fail(scenario, "SKIPPED -- nobody to build a targeting line for")
		else
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			local macro = tostring(ns.lastMacro or "")
			local first = macro:match("^([^\r\n]+)")
			if first ~= want.command .. " " .. tostring(entry.targetName) then
				fail(scenario, "the macro opens with '" .. tostring(first) .. "'")
			end
		end
	end
	SecureCmdList, SLASH_TARGET_EXACT1 = savedList, savedSlash
end
Mock.reset()

-- ------------------------------------------------------------------ 139
-- The spoken line's budget is measured against the lines actually built, and
-- /targetexact is five characters longer than /target. A budget that did not
-- follow the command would promise a line the macro then silently dropped --
-- which is the bug the measured budget was written to end.
Mock.reset()
ns = load("the budget follows the targeting command")
if ns then
	local scenario = "the budget follows the targeting command"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	wipe(ns.tried)
	local entry = ns.BuildQueue()[1]
	if not entry or not entry.buff or entry.buff.selfCast then
		fail(scenario, "SKIPPED -- nobody to measure a budget against")
	else
		-- Off a nameplate, so the hand-back is part of what is measured: the
		-- mock walks the target first, and your own target keeps none
		-- (scenario 237).
		entry.unit = "nameplate1"
		local spell = ns.BuffName(entry.buff)
		local want = ns.MACRO_LIMIT
			- #(ns.TargetCommand() .. " " .. tostring(entry.targetName)
				.. "\n/cast " .. spell)
			- 1 - #"/targetlasttarget" - 1
		if ns.PhraseBudget(entry) ~= want then
			fail(scenario, ("the budget is %s, and the lines it has to fit beside come to %s")
				:format(tostring(ns.PhraseBudget(entry)), tostring(ns.MACRO_LIMIT - want)))
		end
		-- The whole macro still fits, which is the limit that actually matters.
		ns.db.profile.speech.enabled = true
		ns.db.profile.speech.onlyWhenReturning = false
		ns.db.profile.speech.phrases = string.rep("x", ns.PhraseBudget(entry) - #"/say ")
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		local macro = tostring(ns.lastMacro or "")
		if not macro:find("\n/say ", 1, true) then
			fail(scenario, "a line measured to fit exactly was dropped")
		end
		if #macro > ns.MACRO_LIMIT then
			fail(scenario, "the macro came out at " .. #macro .. " characters")
		end
		ns.db.profile.speech.enabled = false
		ns.db.profile.speech.onlyWhenReturning = true
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 140
-- The settle path is told what the macro aimed at; it does not work it out.
--
-- Today's only strategy aims at a spelling the settle path could reconstruct
-- from the key on its own -- the bare first name and the name without a
-- cross-realm suffix are both accepted, and they happen to cover it. That is
-- what makes this worth pinning: the reconstruction agrees by luck, and a
-- second targeting strategy added later would break the agreement silently, with
-- every favour reported as having gone to a stranger and never settling.
--
-- So this drives the contract directly, with a record whose aimed-at spelling
-- none of the fallback rules can reach. The pairing is deliberately one no
-- current strategy produces; it is the future one's shape.
Mock.reset()
ns = load("the settle path is told what the macro aimed at")
if ns then
	local scenario = "the settle path is told what the macro aimed at"
	drive(scenario, ns)
	Mock.advance(60)

	local buff = ns.FindBuff("MAGE", "intellect")
	if not buff then
		fail(scenario, "SKIPPED -- no buff to settle a cast of")
	else
		local key, aimed = "Vann Locke", "Locke of Ravencrest"
		local function park()
			Mock.advance(1)
			wipe(ns.tried)
			ns.owed[key] = { expires = GetTime() + 100, at = GetTime() }
			ns.pendingClick = { name = key, at = GetTime(), buffKey = buff.key,
				selfCast = false, targeted = true, aimedAt = aimed }
		end

		-- The client names the person the macro aimed at. That is the favour
		-- returned, whatever the key looks like.
		park()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", aimed, nil, buff.ranks[1])
		if ns.owed[key] then
			fail(scenario, "the buff reached the name the macro itself wrote and the"
				.. " favour was still counted unpaid")
		end

		-- And the mirror, or "accept the builder's word" would quietly become
		-- "accept anything": somebody the macro did not aim at is still a
		-- stranger who got your buff, and the debt stands.
		park()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Mortimer Vale", nil, buff.ranks[1])
		if not ns.owed[key] then
			fail(scenario, "a cast that landed on somebody else counted as the favour"
				.. " returned")
		end
		wipe(ns.owed)
		ns.pendingClick = nil
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 141
-- The combat log is asked for only where the client has one.
--
-- Registering COMBAT_LOG_EVENT_UNFILTERED is refused outright on Forever and on
-- retail 12.0+, and a refused registration inside OnEnable is the exact class of
-- failure that once stopped the aura scanner from ever starting. So it is asked
-- for on the three classic flavours and nowhere else.
for _, want in ipairs({
	{ flavour = "camelot", interface = 16001, log = false },
	{ flavour = "vanilla", interface = 11509, log = true },
	{ flavour = "tbc", interface = 20506, log = true },
	{ flavour = "mists", interface = 50504, log = true },
	{ flavour = "mainline", interface = 120100, log = false },
}) do
	local scenario = "the combat log on " .. want.flavour
	Mock.reset()
	Mock.interface = want.interface
	Mock.combatLog = want.log
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local asked = Mock.registeredEvents["COMBAT_LOG_EVENT_UNFILTERED"] == true
		if asked ~= want.log then
			fail(scenario, "the event was " .. (asked and "asked for" or "never asked for"))
		end
		if ns.logScan.armed ~= want.log then
			fail(scenario, "armed=" .. tostring(ns.logScan.armed))
		end
	end
end

-- ...and a client that is classified as having a log and then refuses is one
-- source, not a broken addon. The refusal is caught and said out loud, the flag
-- stays down, and everything after it in OnEnable still runs -- which is the
-- whole reason this registration is not inside the loop with the others.
Mock.reset()
Mock.interface = 50504
Mock.combatLog = false
ns = load("a classic client that refuses the combat log")
if ns then
	local scenario = "a classic client that refuses the combat log"
	local ok, err = pcall(function()
		ns.addon:OnInitialize()
		ns.addon:OnEnable()
	end)
	if not ok then
		fail(scenario, "the refusal took OnEnable down: " .. tostring(err))
	end
	if ns.logScan.armed ~= false then
		fail(scenario, "armed the log after the client refused it")
	end
	if not ns.addon.scanTimer then
		fail(scenario, "the refusal took the aura scanner with it")
	end
	local said
	for _, e in ipairs(ns.errors or {}) do
		if tostring(e.where):find("COMBAT_LOG_EVENT_UNFILTERED", 1, true) then said = true end
	end
	if not said then fail(scenario, "the refusal was swallowed without a word") end
end
Mock.reset()

-- ------------------------------------------------------------------ 142
-- The one thing the combat log does that the aura scan cannot do on any client.
--
-- aura.sourceUnit is a unit token everywhere, so a stranger the client holds no
-- token for -- not your target, not your mouseover, no nameplate, standing
-- behind you -- reads as nil and cannot be identified at all. SPELL_AURA_APPLIED
-- carries their GUID, and GetPlayerInfoByGUID turns a GUID into a name and a
-- class with no token anywhere in it. On the three flavours with a log, that
-- person can be thanked.
Mock.reset()
Mock.interface = 50504
Mock.combatLog = true
Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
ns = load("a stranger with no nameplate")
if ns then
	local scenario = "a stranger with no nameplate"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)

	ns.db.profile.verbose = true
	Mock.printed = {}
	ns.addon:COMBAT_LOG_EVENT_UNFILTERED()

	-- Through NoteFavour and not past it. The chat line, the debt and the write
	-- to disk are one act, and a source that files the debt by hand gets a
	-- prompt that works and a user who is never told why -- which is the whole
	-- of what "feed the existing machinery" means here.
	local said
	for _, line in ipairs(Mock.printed) do
		if line:find("Petra buffed you", 1, true) then said = true end
	end
	if not said then
		fail(scenario, "the favour was filed without going through NoteFavour"
			.. " -- nothing was said")
	end

	local debt = ns.owed["Petra"]
	if not debt then
		fail(scenario, "the log watched a buff land on us and filed nobody")
	else
		-- The class is the half of this the aura scan could not have supplied
		-- either, and the tokenless fallback in BuildQueue has nothing else to
		-- judge what to offer them with.
		if debt.class ~= "PRIEST" then
			fail(scenario, "filed their class as " .. tostring(debt.class))
		end
		if debt.guid ~= "Player-1-PETRA" then
			fail(scenario, "filed their guid as " .. tostring(debt.guid))
		end
	end

	-- And it reaches the prompt, which is the only thing that ever returns a
	-- favour. A debt nothing offers is a debt nobody repays.
	local offered
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == "Petra" then offered = entry end
	end
	if not offered then
		fail(scenario, "the favour was recorded and never offered")
	elseif offered.reason ~= "owed" then
		fail(scenario, "offered them for " .. tostring(offered.reason))
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 143
-- One buff landing, two sources that cannot see each other, one favour.
--
-- Where the client has a log, the ordinary case is that both sources see the
-- same cast: the log line arrives, and the aura scan then reads the same aura
-- off a nameplate. Announcing it twice would say "Petra buffed you" twice and
-- write the debt through twice for one courtesy.
--
-- Both orders, because nothing decides which source gets there first.
for _, order in ipairs({ "log first", "aura scan first" }) do
	local scenario = "one landing seen twice, " .. order
	Mock.reset()
	Mock.interface = 50504
	Mock.combatLog = true
	-- The two sources have to spell the same person the same way or the
	-- duplicate is invisible: two keys are two people, and each would be filed
	-- and offered on its own.
	Mock.unitName = { "Petra", "Stonewell" }
	Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "Stonewell" } }
	Mock.extraAuraSpell = 21562
	Mock.extraAuraSource = "nameplate1"
	Mock.extraAuraUntil = 5000
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.db.profile.verbose = true

		local function announced()
			local n = 0
			for _, line in ipairs(Mock.printed) do
				if line:find("buffed you", 1, true) then n = n + 1 end
			end
			return n
		end

		local function fromTheLog() ns.addon:COMBAT_LOG_EVENT_UNFILTERED() end
		local function fromTheScan()
			-- A new aura in the list, which is what the scan has to read to
			-- notice anything at all.
			Mock.extraAura = 3003
			ns.ScanOwnBuffs()
		end

		Mock.printed = {}
		if order == "log first" then
			fromTheLog()
			fromTheScan()
		else
			fromTheScan()
			fromTheLog()
		end

		if announced() ~= 1 then
			fail(scenario, "one courtesy was announced " .. announced() .. " times")
		end
		if not ns.owed["Petra-Stonewell"] then
			fail(scenario, "neither source filed the favour at all")
		end
		local people = 0
		for _ in pairs(ns.owed) do people = people + 1 end
		if people ~= 1 then
			fail(scenario, "one person who buffed us was filed as " .. people .. " debts")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 144
-- The mark the two sources agree on is CONSUMED, not left to time out.
--
-- That difference is the whole of it. A suppression window would swallow the
-- next cast of the same buff by the same person, which really is a second
-- favour; consuming the mark means the second source takes it away and the
-- landing after that starts again from nothing.
Mock.reset()
Mock.interface = 50504
Mock.combatLog = true
Mock.unitName = { "Petra", "Stonewell" }
Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "Stonewell" } }
Mock.extraAuraSpell = 21562
Mock.extraAuraSource = "nameplate1"
Mock.extraAuraUntil = 5000
ns = load("the mark is consumed rather than timed out")
if ns then
	local scenario = "the mark is consumed rather than timed out"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.db.profile.verbose = true

	local function announced()
		local n = 0
		for _, line in ipairs(Mock.printed) do
			if line:find("buffed you", 1, true) then n = n + 1 end
		end
		return n
	end

	-- The log sees it, the scan reads the same aura, one favour. The scan has
	-- taken the mark away on its way past.
	Mock.printed = {}
	ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
	Mock.extraAura = 3003
	ns.ScanOwnBuffs()
	if announced() ~= 1 then
		fail(scenario, "the pair was announced " .. announced() .. " times")
	end

	-- Now the same person casts the same buff again, with no clock moved at
	-- all. Nothing is left to suppress it, so it is a favour and is said.
	wipe(ns.owed)
	Mock.printed = {}
	ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
	if announced() ~= 1 then
		fail(scenario, "a second cast inside the window was announced "
			.. announced() .. " times -- the mark was a timer, not a claim")
	end
	if not ns.owed["Petra-Stonewell"] then
		fail(scenario, "a second favour from the same person was not filed")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 145
-- What the log is allowed to skip, and what it is not.
--
-- The corroboration and the settled baseline exist because a scan of your own
-- aura list can misread it. A log line is an event and there is nothing to
-- doubt, so none of that applies -- a favour arrives whether or not the aura
-- scan has ever produced a reading it believes. The switches are a different
-- thing entirely: they are the user saying no, and they mean here exactly what
-- they mean to the scan.
Mock.reset()
Mock.interface = 50504
Mock.combatLog = true
Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
-- The client will not show the aura list at all, so the baseline never settles
-- and the scan is doubted for the whole session. On Forever that is the end of
-- the matter; here it is not.
Mock.auraBlackout = true
ns = load("the log does not wait for the aura scan")
if ns then
	local scenario = "the log does not wait for the aura scan"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)

	if ns.auraScan.primed then
		fail(scenario, "SKIPPED -- the baseline settled and the case is not modelled")
	else
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		if not ns.owed["Petra"] then
			fail(scenario, "a log line was held back by machinery built for the aura scan")
		end
	end
end
Mock.reset()

for _, want in ipairs({
	{ label = "the addon switched off", apply = function(db) db.enabled = false end },
	{ label = "the owed source switched off", apply = function(db) db.sources.owed = false end },
}) do
	local scenario = "the log obeys " .. want.label
	Mock.reset()
	Mock.interface = 50504
	Mock.combatLog = true
	Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		want.apply(ns.db.profile)

		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		if ns.owed["Petra"] then
			fail(scenario, "a favour was filed with " .. want.label)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 146
-- What comes off the log before anything is looked up.
--
-- Everything within fifty yards arrives here, so each of these is both a
-- correctness rule and the reason the handler is cheap. Each case changes one
-- field of the line and nothing else, so a test cannot pass by accident for
-- having moved something it does not mention.
for _, case in ipairs({
	{ label = "a subevent that is not an aura landing",
		cleu = { subevent = "SPELL_DAMAGE" } },
	{ label = "a debuff", cleu = { auraType = "DEBUFF" } },
	{ label = "a buff that landed on somebody else",
		cleu = { destGUID = "Player-1-VANN" } },
	{ label = "our own buff on ourselves",
		cleu = { sourceGUID = "Player-1-player" } },
	{ label = "a caster the log would not name",
		cleu = { sourceGUID = Mock.NONE } },
	{ label = "a spell the log would not name", cleu = { spellId = Mock.NONE } },
	{ label = "a heal-over-time rather than a class buff", cleu = { spellId = 774 } },
	{ label = "an NPC", cleu = { sourceGUID = "Creature-1-FLAMEWAKER" } },
}) do
	local scenario = "the log ignores " .. case.label
	Mock.reset()
	Mock.interface = 50504
	Mock.combatLog = true
	Mock.guids = {
		["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" },
		-- Ourselves, nameable from our own GUID the way the client really does
		-- name us. Without this the "our own buff" case below would file nobody
		-- because the log could not name the caster, which is a different rule
		-- from the one it is about -- and it passed for that reason with the
		-- rule it is about deleted.
		["Player-1-player"] = { class = "MAGE", name = "Mort", realm = "" },
	}
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)

		-- The control first: the line as it stands is a favour, so a case that
		-- files nothing is doing it for the field it changed and not because
		-- this whole setup files nothing.
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		if not ns.owed["Petra"] then
			fail(scenario, "SKIPPED -- the unaltered line was not a favour either")
		end
		wipe(ns.owed)
		-- Far enough on that the control's claim has gone stale.
		--
		-- Most of these cases leave the caster and the spell alone, so the mark
		-- the control left behind is the mark the case would claim -- and the
		-- case would then file nothing because the mark was consumed rather
		-- than because the field it changed was filtered. Every one of these
		-- passed for that reason before the clock was moved, and four of them
		-- went on passing with the filter they are about deleted.
		Mock.advance(30)

		Mock.cleu = case.cleu
		-- Ignored, not thrown on. A handler that dies on a line it cannot use
		-- stops being a source, and the log carries every shape of line there
		-- is -- so "we filed nobody" is only half the guarantee.
		local before = #ns.errors
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		local filed
		for name in pairs(ns.owed) do filed = name end
		if filed then
			fail(scenario, "filed " .. tostring(filed) .. " as owing a favour")
		end
		if #ns.errors > before then
			fail(scenario, "threw on it: " .. tostring(ns.errors[#ns.errors].err))
		end
		Mock.cleu = nil
	end
end
Mock.reset()

-- ...and the class-buff filter is the setting it says it is, on this source as
-- much as on the scan. Somebody who has turned it off has asked for every aura
-- that lands to count.
Mock.reset()
Mock.interface = 50504
Mock.combatLog = true
Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
Mock.cleu = { spellId = 774 }
ns = load("every incoming aura counts when the filter is off")
if ns then
	local scenario = "every incoming aura counts when the filter is off"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	ns.db.profile.sources.owedClassBuffsOnly = false

	ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
	if not ns.owed["Petra"] then
		fail(scenario, "the filter was switched off and a stray aura still did not count")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 147
-- Both sources spell the same person the same way, because the key is what
-- debts are filed under and the two would otherwise be two people.
--
-- The aura scan joins UnitName's two returns; the log joins the name and realm
-- GetPlayerInfoByGUID gives back. One function makes the join for both, and this
-- is the proof it is reached from the log as well -- a cross-realm player keeps
-- the realm in the key and loses it on the /target line, and a same-realm player
-- whose realm comes back empty must not be left with a trailing separator.
Mock.reset()
Mock.interface = 50504
Mock.combatLog = true
Mock.cleu = { sourceGUID = "Player-1-IRIS", sourceName = "Iris-Ravencrest" }
ns = load("a cross-realm favour off the log")
if ns then
	local scenario = "a cross-realm favour off the log"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)

	ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
	if not ns.owed["Iris-Ravencrest"] then
		local filed
		for name in pairs(ns.owed) do filed = name end
		fail(scenario, "filed them as " .. tostring(filed) .. ", not Iris-Ravencrest")
	elseif ns.owed["Iris-Ravencrest"].class ~= "DRUID" then
		fail(scenario, "filed their class as "
			.. tostring(ns.owed["Iris-Ravencrest"].class))
	else
		local offered
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Iris-Ravencrest" then offered = entry end
		end
		if not offered then
			fail(scenario, "a cross-realm favour was filed and never offered")
		elseif offered.targetName ~= "Iris" then
			fail(scenario, "would aim the macro at " .. tostring(offered.targetName))
		end
	end
end
Mock.reset()

Mock.interface = 50504
Mock.combatLog = true
Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
ns = load("a same-realm favour off the log")
if ns then
	local scenario = "a same-realm favour off the log"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)

	ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
	local filed
	for name in pairs(ns.owed) do filed = name end
	if filed ~= "Petra" then
		fail(scenario, "an empty realm left them filed as " .. tostring(filed))
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 148
-- The mock can be any of the five clients, and it and the addon agree about
-- which one it is.
--
-- Four of the five cannot be started by anybody working on this addon, so every
-- claim made about them below is really a claim about the mock. Setting the
-- interface number, the project id, the combat log, UnitName and UnitBuff by
-- hand in each scenario lets a test be a client that does not exist -- Forever
-- with a combat log, retail with surnames -- and such a test agrees with
-- whatever the code happens to do. Mock.setFlavour is the one place those five
-- facts are kept together, and this is the check that they are the right five.
--
-- The band trap is asserted from here as well as from 120 because this is the
-- route everything below takes. 16001 and 11509 are both five digits beginning
-- with a 1, and Camelot is handed the vanilla spells on purpose, so a detector
-- that called Camelot vanilla would be wrong in a way that very nearly works.
local CLIENTS = {
	{ flavour = "camelot", family = "modern", interface = 16001,
		project = WOW_PROJECT_MAINLINE, set = "vanilla", surname = true },
	{ flavour = "mainline", family = "modern", interface = 120100,
		project = WOW_PROJECT_MAINLINE, set = "mainline", surname = false },
	{ flavour = "mists", family = "classic", interface = 50504,
		project = WOW_PROJECT_MISTS_CLASSIC, set = "mists", surname = false },
	{ flavour = "tbc", family = "classic", interface = 20506,
		project = WOW_PROJECT_BURNING_CRUSADE_CLASSIC, set = "vanilla", surname = false },
	{ flavour = "vanilla", family = "classic", interface = 11509,
		project = WOW_PROJECT_CLASSIC, set = "vanilla", surname = false },
}
for _, want in ipairs(CLIENTS) do
	local scenario = "the mock as " .. want.flavour
	Mock.reset()
	Mock.setFlavour(want.flavour)
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		ns.Guard("probe", ns.ProbeCapabilities)

		-- What the client says about itself, before the addon reads any of it.
		-- A mock that set the flavour name and left GetBuildInfo alone would make
		-- every detection assertion below a tautology.
		if select(4, GetBuildInfo()) ~= want.interface then
			fail(scenario, "GetBuildInfo reports interface "
				.. tostring(select(4, GetBuildInfo())))
		end
		if WOW_PROJECT_ID ~= want.project then
			fail(scenario, "reports project id " .. tostring(WOW_PROJECT_ID))
		end

		-- And what the addon made of it.
		local f = ns.Flavour or {}
		if f.flavour ~= want.flavour or f.family ~= want.family then
			fail(scenario, "was read as " .. tostring(f.flavour) .. "/" .. tostring(f.family))
		end
		if f.recognised ~= true then
			fail(scenario, "did not recognise a client it has a band for")
		end
		-- The interface number and the project id tell the same story here, and
		-- the disagreement line in a bug report means nothing if it is on
		-- permanently.
		if f.agrees == false then
			fail(scenario, "the two say different things: " .. ns.FlavourSummary())
		end
		if not tostring(ns.BUFFS_SOURCE):find(want.set, 1, true) then
			fail(scenario, "was handed the " .. tostring(ns.BUFFS_SOURCE) .. " spells")
		end

		-- The four differences that have no probe and no second opinion.
		if ns.caps.combatLog ~= (want.family == "classic") then
			fail(scenario, "combatLog=" .. tostring(ns.caps.combatLog))
		end
		if ns.caps.unitNameIsSurname ~= want.surname then
			fail(scenario, "unitNameIsSurname=" .. tostring(ns.caps.unitNameIsSurname))
		end
		if (type(_G.UnitBuff) == "function") ~= (want.family == "classic") then
			fail(scenario, "UnitBuff is " .. (_G.UnitBuff and "present" or "absent")
				.. " on a client where it is not")
		end
		if ns.caps.conditionalTargeting ~= Mock.conditionalTargeting then
			fail(scenario, ("the addon believes conditional targeting is %s and the"
				.. " client behaves as though it is %s"):format(
				tostring(ns.caps.conditionalTargeting), tostring(Mock.conditionalTargeting)))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 149
-- The project id cannot name a flavour on its own, from either direction.
--
-- Two failures, and the mock can now produce both. Camelot and retail report the
-- same project id, so anything that reads it to tell them apart gets whichever
-- one it tested against. And on a client where the constants are missing
-- altogether, `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC` is nil == nil and every
-- such test is true at once -- which would hand a modern client the classic
-- family, the combat log with it, and a registration that throws.
Mock.reset()
Mock.setFlavour("camelot")
local camelotProject = WOW_PROJECT_ID
Mock.setFlavour("mainline")
if WOW_PROJECT_ID ~= camelotProject then
	fail("the project id cannot tell Camelot from retail",
		"the two clients report different project ids -- " .. tostring(camelotProject)
			.. " and " .. tostring(WOW_PROJECT_ID) .. " -- so this suite is no longer"
			.. " modelling the thing that makes the interface number load-bearing")
end
Mock.reset()

-- Each flavour in turn, with the project constants taken away. The interface
-- number is the one thing left, and it has to be enough -- on every one of them,
-- not just on the one whose number happened to be tried first.
for _, want in ipairs(CLIENTS) do
	local scenario = "no project constants on " .. want.flavour
	Mock.reset()
	Mock.setFlavour(want.flavour)
	local saved = {
		WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC,
		WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_MISTS_CLASSIC,
	}
	WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = nil, nil, nil
	WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_MISTS_CLASSIC = nil, nil
	ns = load(scenario)
	WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = saved[1], saved[2], saved[3]
	WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_MISTS_CLASSIC = saved[4], saved[5]
	if ns then
		drive(scenario, ns)
		local f = ns.Flavour or {}
		if f.flavour ~= want.flavour or f.family ~= want.family then
			fail(scenario, "with nothing but the interface number it decided "
				.. tostring(f.flavour) .. "/" .. tostring(f.family))
		end
		-- nil == nil comparing true would have left a project entry standing, and
		-- the disagreement line would then be on for every user of this client.
		if f.agrees ~= nil then
			fail(scenario, "compared the interface number against a project id that"
				.. " is not there, and got " .. tostring(f.agrees))
		end
		if f.project ~= nil then
			fail(scenario, "invented a project id of " .. tostring(f.project))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 150
-- The macro, on every client, for a stranger and for somebody in the group.
--
-- There is one targeting strategy in this version and it ships everywhere:
-- /target them, cast, hand the target back. [@nameplateN] is invalid on every
-- client and [@PlayerName] resolves only for party and raid members, so the
-- /target route is the only way to reach an ungrouped stranger anywhere -- and a
-- stranger is the whole reason this addon exists. It works perfectly well for a
-- group member too, so there is no second shape.
--
-- Asserted on all five because the cost of being wrong is silent: a conditional
-- that resolves to nothing casts nothing and says nothing, so an addon that
-- quietly never worked would look exactly like an addon nobody had buffed.
for _, want in ipairs(CLIENTS) do
	for _, who in ipairs({ "a stranger", "a group member" }) do
		local scenario = who .. " on " .. want.flavour .. " gets the /target macro"
		Mock.reset()
		Mock.setFlavour(want.flavour)
		-- A mage on every client: Arcane Intellect is in all three buff sets and
		-- carries id 1459 in each, which is the one spell the mock's IsSpellKnown
		-- answers for. Anything else would test the buff tables rather than the
		-- macro.
		Mock.class = "MAGE"
		-- Off Camelot a same-realm player has no second return, and nearly
		-- everybody is same-realm; on Camelot every player has a surname.
		local aimedAt = want.surname and "Petra Stonewell" or "Petra"
		if who == "a group member" then
			Mock.groupSize = 3
			Mock.unitNames = { party1 = { "Rell" } }
			-- In the group by name as well as by count, so the conditional the
			-- next scenario tries would genuinely resolve for them. A group
			-- member who is not in the group is not a test of anything.
			Mock.groupNames = { Rell = true }
			aimedAt = "Rell"
		end
		ns = load(scenario)
		if ns then
			drive(scenario, ns)
			Mock.advance(60)
			wipe(ns.tried)

			local entry
			for _, candidate in ipairs(ns.BuildQueue()) do
				if candidate.name == aimedAt then entry = candidate end
			end
			if not entry then
				fail(scenario, "nobody called " .. aimedAt .. " was offered")
			else
				-- A stranger off a nameplate, which is how they usually come.
				-- Every token in the mock is Petra and the target is walked
				-- first, and your own target is never handed back (scenario 237).
				if entry.unit == "target" then entry.unit = "nameplate1" end
				ns.Prompt:InvalidateMacro()
				ns.Prompt:ApplyTarget(entry)
				local macro = tostring(ns.lastMacro or "")
				local lines = {}
				for line in macro:gmatch("[^\r\n]+") do lines[#lines + 1] = line end

				if #lines ~= 3 then
					fail(scenario, "armed " .. #lines .. " lines: " .. macro:gsub("\n", " | "))
				end
				if lines[1] ~= ns.TargetCommand() .. " " .. aimedAt then
					fail(scenario, "the targeting line is '" .. tostring(lines[1]) .. "'")
				end
				if lines[2] ~= "/cast Arcane Intellect" then
					fail(scenario, "the cast line is '" .. tostring(lines[2]) .. "'")
				end
				if lines[3] ~= "/targetlasttarget" then
					fail(scenario, "the last line is '" .. tostring(lines[3])
						.. "', so the player's own target is not handed back")
				end

				-- The strategy that is deliberately not built. A conditional here
				-- would be untested on four clients and silent when it failed, and
				-- a bare trailing clause -- the shape somebody reaches for next --
				-- always matches and casts on whatever is currently targeted,
				-- which is the exact bug this addon exists to avoid.
				if macro:find("[@", 1, true) then
					fail(scenario, "took the conditional route: " .. macro:gsub("\n", " | "))
				end
				if #macro > ns.MACRO_LIMIT then
					fail(scenario, "the macro came out at " .. #macro .. " characters")
				end
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 151
-- The identity and the spelling, on every client.
--
-- The key is what debts are filed under, and it is written to disk and read back
-- after a reload, so it must be the same string on both sides of a login. The
-- /target line is a name search over the units the client has drawn in, and the
-- realm is not part of what it searches. Off Camelot those are two different
-- strings for the same person and each has to go to its own place.
--
-- Camelot is in the loop for the opposite reason: nothing at all comes off the
-- key there, and that is a rule rather than an accident of the names the mock
-- happens to produce. Nobody has documented what the second return is on Camelot
-- for a player from another realm, so the join that is verified in game is the
-- only thing known to be right and no rule written for realms may reach it.
for _, want in ipairs(CLIENTS) do
	local scenario = "a player from another realm on " .. want.flavour
	Mock.reset()
	Mock.setFlavour(want.flavour)
	Mock.crossRealm = true
	Mock.unitName = { "Vann", "Ravencrest" }
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.tried)
		wipe(ns.owed)

		local key = want.surname and "Vann Ravencrest" or "Vann-Ravencrest"
		local aim = want.surname and "Vann Ravencrest" or "Vann"

		local entry
		for _, candidate in ipairs(ns.BuildQueue()) do
			if candidate.name == key then entry = candidate end
		end
		if not entry then
			fail(scenario, "filed them under something other than '" .. key .. "'")
		else
			if entry.targetName ~= aim then
				fail(scenario, "would aim the macro at " .. tostring(entry.targetName))
			end

			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			local first = tostring(ns.lastMacro or ""):match("^([^\r\n]+)")
			if first ~= ns.TargetCommand() .. " " .. aim then
				fail(scenario, "the targeting line is '" .. tostring(first) .. "'")
			end

			-- And the debt, which is the whole reason the two are kept apart. The
			-- game names the person the spell reached by the spelling the macro
			-- used, and off Camelot that is not the string the debt is filed
			-- under; a settle path that compared them by eye would leave every
			-- cross-realm favour unpaid for ever.
			ns.pendingClick = nil
			ns.owed[key] = { expires = GetTime() + 100, at = GetTime() }
			local button = ns.Prompt:GetButton()
			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to settle")
			else
				if ns.pendingClick.aimedAt ~= aim then
					fail(scenario, "the press recorded aiming at "
						.. tostring(ns.pendingClick.aimedAt))
				end
				ns.addon:UNIT_SPELLCAST_SENT(nil, "player", aim, nil, entry.buff.ranks[1])
				if ns.owed[key] then
					fail(scenario, "the buff reached them under the name the macro"
						.. " itself wrote and the favour was still counted unpaid")
				end
			end
			wipe(ns.owed)
			ns.pendingClick = nil
		end
	end
end
Mock.reset()

-- ...and the ordinary case off Camelot, which is nearly every player: no realm
-- at all. A join that always ran would leave a trailing separator on a name the
-- client will never find, and it would do it for everybody rather than for the
-- handful of people the case above is about.
for _, want in ipairs(CLIENTS) do
	if not want.surname then
		local scenario = "a same-realm player on " .. want.flavour
		Mock.reset()
		Mock.setFlavour(want.flavour)
		Mock.unitName = { "Vann", "Ravencrest" }
		ns = load(scenario)
		if ns then
			drive(scenario, ns)
			local realName = UnitName
			local key = ns.UnitFullName("target")
			UnitName = realName
			if key ~= "Vann" then
				fail(scenario, "a player with no realm was filed as '" .. tostring(key) .. "'")
			end
			if ns.TargetName(key) ~= "Vann" then
				fail(scenario, "would aim at '" .. tostring(ns.TargetName(key)) .. "'")
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 152
-- The classes retail left with nothing at all.
--
-- The Blessings died in 7.0.3 and Blessing of the Seasons in 12.0.0; Horn of
-- Winter went in 11.2.0. A paladin and a death knight on Midnight have nothing
-- to put on a passer-by, and "nothing" has to arrive as the plain sentence a
-- rogue already gets rather than as an empty prompt, a silent addon or an error.
--
-- Both classes hold spells on another client, which is what makes this worth
-- asserting rather than assuming: every path here is one that finds something on
-- the flavour below, so the emptiness is a fact about retail and not about the
-- addon having stopped looking.
for _, want in ipairs({
	{ class = "PALADIN", elsewhere = { flavour = "mists", key = "kings" } },
	{ class = "DEATHKNIGHT", elsewhere = { flavour = "mists", key = "hornofwinter" } },
}) do
	-- Deliberately not the name scenario 132 uses. selftest matches a mutation
	-- against the failing line by substring, and two scenarios whose names are
	-- one word apart make every attribution between them a coin toss.
	local scenario = "a retail " .. want.class:lower() .. " has nothing to offer"
	Mock.reset()
	Mock.setFlavour("mainline")
	Mock.class = want.class
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		ns.Guard("probe", ns.ProbeCapabilities)

		if ns.caps.hasClassBuffs ~= false then
			fail(scenario, "found buffs for a class that has none on this client")
		end
		if #ns.BuildQueue() ~= 0 then
			fail(scenario, "offered somebody a spell this class no longer has")
		end
		-- Named, so the honest sentence is reachable. A class that is simply
		-- absent from the tables gets the vague one -- "could not work out what
		-- you can cast" -- which reads as a broken addon.
		if ns.CLASSES_WITHOUT_BUFFS[want.class] ~= true then
			fail(scenario, "has nothing to give here and is not listed as such, so"
				.. " the page cannot say so plainly")
		end

		Mock.printed = {}
		local spoke = pcall(ns.addon.HandleSlash, ns.addon, "debug")
		local said = table.concat(Mock.printed, "\n")
		if not spoke then
			fail(scenario, "/manners debug threw for a class with nothing to cast")
		elseif not said:find("no buffs to cast on other players", 1, true) then
			fail(scenario, "debug did not say the class has nothing: " .. said)
		elseif not said:find("mainline", 1, true) then
			fail(scenario, "debug never named the client, which is the one thing a"
				.. " report from a client nobody here can run has to carry: " .. said)
		end

		local page = ns.optionsTable and ns.optionsTable.args.general
			and ns.optionsTable.args.general.args.noBuffs
		if not page then
			fail(scenario, "SKIPPED -- the page has nothing to say about a class with nothing")
		elseif not page.name():find("no buffs it can cast", 1, true) then
			fail(scenario, "the page gave the vague answer for a class we know has"
				.. " nothing: " .. page.name())
		end
	end

	-- The same class, on a client where it has something. Without this the
	-- assertions above pass just as well for a class the addon has forgotten how
	-- to look up at all.
	local other = "a " .. want.elsewhere.flavour .. " " .. want.class:lower()
		.. " still has something"
	Mock.reset()
	Mock.setFlavour(want.elsewhere.flavour)
	Mock.class = want.class
	ns = load(other)
	if ns then
		drive(other, ns)
		if not ns.FindBuff(want.class, want.elsewhere.key) then
			fail(other, "lost " .. want.elsewhere.key .. " on a client that has it")
		end
		if ns.CLASSES_WITHOUT_BUFFS[want.class] then
			fail(other, "is listed as having nothing while holding a list of spells")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 153
-- UnitBuff is never called, on the clients that still have it.
--
-- UnitBuff and UnitAura were removed from retail and from Forever and are alive
-- on the three Classic flavours. C_UnitAuras is on all five, so there is no
-- client where a fallback to the old pair would be reached by anybody who needs
-- it -- it would be a second scanner that only ever runs where it is not wanted,
-- and it would rot unnoticed because the client that has it is not the client
-- anybody tests on.
--
-- An absent function proves nothing: not calling something that is not there is
-- not a choice. So the mock puts a working UnitBuff where the addon could reach
-- it and counts the times it did.
for _, want in ipairs(CLIENTS) do
	local scenario = "the aura scan on " .. want.flavour .. " does not use UnitBuff"
	Mock.reset()
	Mock.setFlavour(want.flavour)
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		ns.ScanOwnBuffs()

		if Mock.counts.unitBuff ~= 0 then
			fail(scenario, "called UnitBuff " .. Mock.counts.unitBuff .. " times")
		end
		-- And it read the auras some other way, or the count above is zero
		-- because nothing scanned at all.
		if Mock.counts.auraRead == 0 then
			fail(scenario, "read no auras through C_UnitAuras either, so nothing"
				.. " was scanning and the count above proves nothing")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 154
-- Why the /target route ships on every client, stated as the clients' own
-- behaviour rather than as a comment.
--
-- [@PlayerName] resolves for a player in your party or raid and for nobody else,
-- on all five. The person this addon exists for -- somebody who buffed you in
-- passing and is not in your group -- therefore resolves nowhere, and a
-- conditional aimed at them casts nothing and says nothing.
for _, want in ipairs(CLIENTS) do
	local scenario = "a conditional aimed at a stranger on " .. want.flavour
	Mock.reset()
	Mock.setFlavour(want.flavour)
	Mock.groupNames = { Rell = true }

	local stranger = SecureCmdOptionParse("[@Petra,help,nodead] Arcane Intellect")
	if stranger ~= nil then
		fail(scenario, "resolved to '" .. tostring(stranger) .. "' for somebody who"
			.. " is not in the group")
	end

	-- And a group member, where the two modern-engine clients part company: the
	-- restriction that rules this out on Camelot is the reason Camelot keeps the
	-- route verified in game there.
	local member = SecureCmdOptionParse("[@Rell,help,nodead] Arcane Intellect")
	local reaches = member ~= nil
	if reaches ~= (want.flavour ~= "camelot") then
		fail(scenario, "a conditional naming a group member " ..
			(reaches and "resolved" or "resolved to nothing")
			.. ", which is not what this client does")
	end

	-- An ordinary conditional with no unit in it is not this question and must
	-- still come back, or the probe above is measuring the parser being broken.
	if SecureCmdOptionParse("[nocombat] Arcane Intellect") ~= "Arcane Intellect" then
		fail(scenario, "a conditional naming nobody resolved to '"
			.. tostring(SecureCmdOptionParse("[nocombat] Arcane Intellect")) .. "'")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 155
-- The combat log, on each client in turn and through the one knob that decides
-- which client this is.
--
-- Registering COMBAT_LOG_EVENT_UNFILTERED is refused outright on Forever and on
-- retail 12.0+, and a refused registration inside OnEnable is the exact failure
-- that once stopped the aura scanner from ever starting. So it is asked for on
-- the three Classic flavours and nowhere else.
for _, want in ipairs(CLIENTS) do
	local classic = want.family == "classic"
	-- Not the name 141 uses, for the reason given above scenario 152: this asks
	-- the same question of a client that is this flavour in every respect rather
	-- than in two, and the two checks have to be tellable apart when one fires.
	local scenario = "the combat log on a whole " .. want.flavour .. " client"
	Mock.reset()
	Mock.setFlavour(want.flavour)
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local asked = Mock.registeredEvents["COMBAT_LOG_EVENT_UNFILTERED"] == true
		if asked ~= classic then
			fail(scenario, "the event was " .. (asked and "asked for" or "never asked for"))
		end
		if ns.logScan.armed ~= classic then
			fail(scenario, "armed=" .. tostring(ns.logScan.armed))
		end
	end
end
Mock.reset()

-- The one thing the log does that no aura scan can do on any client: name
-- somebody the client holds no unit token for.
--
-- aura.sourceUnit is a unit token everywhere, so a stranger who is not your
-- target, not your mouseover and has no nameplate reads as nil and cannot be
-- identified at all. SPELL_AURA_APPLIED carries their GUID, and
-- GetPlayerInfoByGUID turns a GUID into a name and a class with no token
-- anywhere in it. Asserted on each of the three flavours that have a log, not
-- just the one it was first written against: the buff sets differ between them,
-- and a filter that consults the buff tables is the obvious way for this to work
-- on one client and silently stop on another.
for _, want in ipairs(CLIENTS) do
	if want.family == "classic" then
		local scenario = "a stranger with no nameplate on " .. want.flavour
		Mock.reset()
		Mock.setFlavour(want.flavour)
		-- Nobody the aura scan could have seen, so nothing but the log can
		-- possibly account for the name below.
		Mock.extraAuraSource = nil
		Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
		ns = load(scenario)
		if ns then
			drive(scenario, ns)
			Mock.advance(60)
			wipe(ns.owed)
			wipe(ns.tried)
			ns.db.profile.verbose = true
			Mock.printed = {}

			ns.addon:COMBAT_LOG_EVENT_UNFILTERED()

			-- Through NoteFavour and not past it: the chat line, the debt and the
			-- write to disk are one act, and a source that files the debt by hand
			-- gets a prompt that works and a user who is never told why.
			local said
			for _, line in ipairs(Mock.printed) do
				if line:find("Petra buffed you", 1, true) then said = true end
			end
			if not said then
				fail(scenario, "the favour was filed without going through"
					.. " NoteFavour -- nothing was said")
			end

			local debt = ns.owed["Petra"]
			if not debt then
				fail(scenario, "the log watched a buff land on us and filed nobody")
			elseif debt.class ~= "PRIEST" then
				-- The half the aura scan could not have supplied either, and the
				-- only thing the tokenless fallback has to judge what to offer.
				fail(scenario, "filed their class as " .. tostring(debt.class))
			end

			local offered
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.name == "Petra" then offered = entry end
			end
			if not offered then
				fail(scenario, "the favour was recorded and never offered")
			elseif offered.reason ~= "owed" then
				fail(scenario, "offered them for " .. tostring(offered.reason))
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 144
-- A press during the global cooldown must not reach the server.
--
-- Found by playing it, not by testing it, and no test here could have found it:
-- the addon never asked about a cooldown, so the mock never had one. Click,
-- cast, and the prompt offered the next person immediately -- so a second press
-- inside the next second and a half hit a server that could not possibly accept
-- it. The cast was refused, the refusal was filed against the person it was
-- aimed at, and they were marked tried and dropped. The chat log filled with
-- "could not cast" and the people being offered a courtesy went unbuffed.
Mock.reset()
ns = load("a press during the global cooldown casts nothing")
if ns then
	local scenario = "a press during the global cooldown casts nothing"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)

	local entry = ns.BuildQueue()[1]
	local button = ns.Prompt:GetButton()
	if not entry or not entry.buff or not button then
		fail(scenario, "SKIPPED -- nobody to press against")
	else
		local spell = entry.buff.ranks[1]

		-- Nothing has been cast, so a press is free to go.
		local ready = ns.CastReady()
		if ready ~= true then
			fail(scenario, "blocked a press before anything had been cast")
		end

		-- The game reports a cast going out. That starts the cooldown whoever
		-- it was aimed at -- a spell cast by hand blocks the prompt exactly as
		-- it blocks the action bars.
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", nil, spell)

		local blocked, left = ns.CastReady()
		if blocked ~= false then
			fail(scenario, "a cast went out and the next press was still allowed")
		end
		if type(left) ~= "number" or left <= 0 or left > 3 then
			fail(scenario, "nonsense time remaining: " .. tostring(left))
		end

		-- And the press itself: armed beforehand, disarmed by PreClick, with
		-- nothing recorded against the person it would have gone to.
		--
		-- Through Refresh rather than ApplyTarget alone, because PreClick's
		-- first act is to check the button is shown and say "nobody to buff
		-- right now" if it is not -- which an earlier draft of this scenario
		-- tripped, so it passed whether the guard was there or not.
		-- Shown explicitly rather than through Refresh. PreClick's first act is
		-- to check the button is up and say "nobody to buff right now" if it is
		-- not, and an earlier draft tripped exactly that, so it passed whether
		-- the guard was there or not. What is under test is the guard, not the
		-- visibility rules, so the press is given a prompt that is up.
		ns.Prompt:ApplyTarget(entry)
		button:Show()
		if not button.attributes["macrotext1"] then
			fail(scenario, "SKIPPED -- the arm did not take, so losing it proves nothing")
		else
			ns.pendingClick = nil
			wipe(ns.tried)
			local pre = button.scripts.PreClick
			if pre then pcall(pre, button, "LeftButton", true) end

			if button.attributes["macrotext1"] then
				fail(scenario, "a macro stayed armed during the global cooldown, so the"
					.. " press reached a server that would refuse it")
			end
			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end
			if ns.pendingClick then
				fail(scenario, "filed a press that could not have cast, against "
					.. tostring(ns.pendingClick.name))
			end
			if next(ns.tried) ~= nil then
				fail(scenario, "blamed somebody for a cooldown that had nothing to"
					.. " do with them")
			end
		end

		-- Once it has run out, the prompt works again. A guard that never lets
		-- go is worse than the bug.
		Mock.advance(3)
		if ns.CastReady() ~= true then
			fail(scenario, "the cooldown never expired, so the prompt is now inert")
		end
	end
end

-- ------------------------------------------------------------------ 156
-- A passer-by has to be near, not merely in casting range.
--
-- Found by playing it, and no test here could have found it: every assertion
-- about who is offered was about whether the client would allow the cast, which
-- is the question the addon was asking and answering correctly. Arcane
-- Intellect reaches thirty yards, the author was standing in a city with
-- twenty-odd nameplates up, and every one of them got a card. "/manners look"
-- on the person who prompted the complaint printed inRangeById=true.
--
-- What follows is the only thing that was wrong: "in range" is a far weaker
-- idea of "near me" than a person's.
local function inQueue(ns)
	local names = {}
	for _, entry in ipairs(ns.BuildQueue()) do names[entry.name] = entry end
	return names
end

-- Everything a scenario below needs before it can judge a distance: the debts
-- and blocks that driving the lifecycle leaves behind cleared away, two
-- nameplates the queue will actually walk, and a fresh capability probe, which
-- is what decides which signal measures.
local function settle(ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.nameplateUnits["nameplate1"] = true
	ns.nameplateUnits["nameplate2"] = true
	ns.Guard("probe", ns.ProbeCapabilities)
end

Mock.reset()
Mock.unitNames = {
	nameplate1 = { "Close", "By" },
	nameplate2 = { "Far", "Away" },
}
-- Both well inside Arcane Intellect's thirty yards, which is the whole point:
-- the old filter has nothing to say about either of them.
Mock.yards = { nameplate1 = 4, nameplate2 = 20 }
ns = load("a passer-by in range but not near")
if ns then
	local scenario = "a passer-by in range but not near"
	drive(scenario, ns)
	settle(ns)

	ns.db.profile.filters.proximity = "near"
	local near = inQueue(ns)
	if not near["Close By"] then
		fail(scenario, "SKIPPED -- the passer-by four yards away was not offered"
			.. " either, so nothing below is about distance")
	else
		if near["Far Away"] then
			fail(scenario, "a passer-by twenty yards off was offered under \"nearby\"")
		end

		-- Measured, rather than dropped for some other reason that happens to
		-- coincide. A drop with nothing behind it would pass the line above.
		if ns.proximity.source ~= "CheckInteractDistance" then
			fail(scenario, "measured with " .. tostring(ns.proximity.source)
				.. ", and this client has nothing else to measure with")
		end
		if ns.proximity.answered == 0 then
			fail(scenario, ("the signal was put %d questions and answered none,"
				.. " so the drop above was not a measurement"):format(ns.proximity.asked))
		end

		-- The loosest step is the old behaviour, exactly. A filter that cannot
		-- be switched off is not a setting, and somebody who wants the whole
		-- square has to be able to have it.
		ns.db.profile.filters.proximity = "cast"
		if not inQueue(ns)["Far Away"] then
			fail(scenario, "\"anywhere I can cast\" dropped somebody the game"
				.. " would have cast on")
		end

		-- And a client that cannot measure at all offers everybody it could
		-- cast on, as it always did. Silently offering nobody would be far
		-- worse than the noise this fixes, so the fallback is asserted rather
		-- than assumed.
		ns.db.profile.filters.proximity = "near"
		Mock.setInteract("gone")
		ns.Guard("probe", ns.ProbeCapabilities)
		if not inQueue(ns)["Far Away"] then
			fail(scenario, "a client with no way to measure distance offered"
				.. " nobody past four yards")
		end
		if ns.proximity.source ~= nil then
			fail(scenario, "claimed to be measuring with "
				.. tostring(ns.proximity.source) .. " on a client that has no such thing")
		end
		local said = tostring(ns.ProximitySummary()):lower()
		if not said:find("no signal", 1, true) then
			fail(scenario, "nothing in the diagnostic says the distance is not"
				.. " being measured: " .. said)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 157
-- Who the distance is not applied to, which is the whole reason it is applied
-- to passers-by.
--
-- Each of the three carries its own evidence of nearness and none of them is
-- what filled the queue. Measuring them again would throw that evidence away
-- for a reading that is coarser than it.
Mock.reset()
-- Nobody is near. Every offer that survives below survives on something other
-- than a measurement.
Mock.yardsDefault = 25
Mock.unitNames = {
	target = { "Tara", "Aimed" },
	focus = { "Fen", "Fixed" },
	mouseover = { "Mo", "Passing" },
	nameplate1 = { "Nora", "Plate" },
	nameplate2 = { "Nils", "Plate" },
}
ns = load("who the proximity setting does not apply to")
if ns then
	local scenario = "who the proximity setting does not apply to"
	drive(scenario, ns)
	settle(ns)
	ns.db.profile.filters.proximity = "near"

	local out = inQueue(ns)
	if out["Nora Plate"] then
		fail(scenario, "SKIPPED -- the passer-by twenty-five yards away was not"
			.. " dropped either, so the exemptions below prove nothing")
	else
		if not out["Tara Aimed"] then
			fail(scenario, "dropped the player you have targeted, which is the"
				.. " plainest statement of intent there is")
		end
		if not out["Fen Fixed"] then
			fail(scenario, "dropped the player you have set as your focus")
		end
		-- Mouseover is deliberately not one of the three. It is wherever the
		-- cursor happens to be this tenth of a second, and at a scan every four
		-- tenths a distant stranger brushed on the way across the screen would
		-- flash onto the prompt -- which is the noise, not an exemption from it.
		if out["Mo Passing"] then
			fail(scenario, "a stranger the cursor happened to cross was offered"
				.. " from twenty-five yards")
		end
	end

	-- Somebody who buffed you was inside casting range the instant they did it.
	-- That instant is the evidence, and it is better than any reading taken now.
	ns.owed["Nora Plate"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
	if not inQueue(ns)["Nora Plate"] then
		fail(scenario, "a favour owed was dropped for being too far away, against"
			.. " proof that they were close enough to buff you")
	end
	wipe(ns.owed)

	-- And your group is your group wherever they are standing.
	Mock.groupSize = 3
	if not inQueue(ns)["Nora Plate"] then
		fail(scenario, "a party member was dropped for distance")
	end
	Mock.groupSize = 0
end
Mock.reset()

-- ------------------------------------------------------------------ 158
-- Which signal is measuring, what it really measures, and what happens when it
-- turns out to measure nothing.
--
-- The setting names a feeling and every signal underneath it is an
-- approximation with its own blind spot, so the one thing that must never
-- happen is a filter that has quietly stopped working: from the prompt that is
-- indistinguishable from a quiet evening, and from a crowded one it is the
-- complaint all over again.

-- The library, when it is there and working. Its estimate arrives in buckets
-- whose edges are whatever checkers this class and client happen to have, so
-- "within ten yards" really means "inside the largest edge at or below ten".
Mock.reset()
Mock.rangeCheck = { buckets = { 30, 28, 8 } }
Mock.unitNames = {
	nameplate1 = { "Close", "By" },
	nameplate2 = { "Far", "Away" },
}
Mock.yards = { nameplate1 = 4, nameplate2 = 20 }
ns = load("the library measures, and owns up to what it measured")
if ns then
	local scenario = "the library measures, and owns up to what it measured"
	drive(scenario, ns)
	settle(ns)
	ns.db.profile.filters.proximity = "near"

	Mock.counts.proximity = 0
	Mock.counts.interact = 0
	local out = inQueue(ns)
	if ns.proximity.source ~= "LibRangeCheck-3.0" then
		fail(scenario, "the library was there and " .. tostring(ns.proximity.source)
			.. " was used instead")
	end
	-- Named as the signal and actually consulted are different claims, and only
	-- the second one filters anybody. The eight-yard edge is the duel prompt,
	-- which the library's checker flattens, so it is asked of the client call
	-- underneath -- either count is somebody being measured.
	if Mock.counts.proximity + Mock.counts.interact == 0 then
		fail(scenario, "named the library as the signal and never once asked it")
	end
	if ns.proximity.yards ~= 8 then
		fail(scenario, "claims to be measuring at " .. tostring(ns.proximity.yards)
			.. " yards, and the tightest edge this client has under ten is eight")
	end
	if not out["Close By"] then
		fail(scenario, "dropped somebody four yards away, who is inside every"
			.. " bucket this client has")
	end
	-- Twenty yards lands in the eight-to-twenty-eight bucket, which holds both
	-- a person beside you and a person across the square. "Certainly within
	-- ten" is the only half of that the estimate can honour, so they go.
	if out["Far Away"] then
		fail(scenario, "kept somebody whose estimate tops out at twenty-eight"
			.. " yards under a ten-yard setting")
	end
	local said = tostring(ns.ProximitySummary())
	if not said:find("8yd", 1, true) then
		fail(scenario, "the label promises about ten yards, the client is really"
			.. " filtering at eight, and the diagnostic does not say so: " .. said)
	end
end

-- A client whose only friendly checker under ten yards is melee. Two yards
-- standing in for "nearby" would drop the square, so the library is declined
-- and the plain client call gets it -- but for "right beside me" two yards is
-- exactly what was asked for, and it is taken.
Mock.reset()
Mock.rangeCheck = { buckets = { 30, 2 } }
Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
Mock.yards = { nameplate1 = 1, nameplate2 = 20 }
ns = load("a checker too tight for the step it would stand in for")
if ns then
	local scenario = "a checker too tight for the step it would stand in for"
	drive(scenario, ns)
	settle(ns)

	ns.db.profile.filters.proximity = "near"
	inQueue(ns)
	if ns.proximity.source ~= "CheckInteractDistance" then
		fail(scenario, "a two-yard checker was kept for a ten-yard setting: "
			.. tostring(ns.proximity.source) .. " at " .. tostring(ns.proximity.yards)
			.. " yards")
	end

	ns.db.profile.filters.proximity = "beside"
	ns.Guard("probe", ns.ProbeCapabilities)
	inQueue(ns)
	if ns.proximity.source ~= "LibRangeCheck-3.0" or ns.proximity.yards ~= 2 then
		fail(scenario, "\"right beside me\" turned down a two-yard checker in"
			.. " favour of " .. tostring(ns.proximity.source) .. " at "
			.. tostring(ns.proximity.yards) .. " yards")
	end
end

-- The library is there, resolves, and then every estimate it is asked for blows
-- up. On this client that is not hypothetical: the library builds its cache key
-- by concatenating a unit GUID, and a GUID here can be a secret value, which
-- throws on concatenation.
--
-- Every throw reads as "cannot tell". That used to offer the person outright,
-- so the queue was exactly as crowded as it was under a setting that said
-- otherwise; now the person is handed to the rung underneath, which answers
-- for them. So the drop is immediate, and what a run of silence buys is the
-- cost: a rung that answers nobody stops being asked.
--
-- A six-yard edge rather than the eight the others use: eight is the duel
-- prompt, which is asked of the client call under the library and never
-- reaches the estimate that throws.
Mock.reset()
Mock.rangeCheck = { buckets = { 30, 28, 6 }, throws = true }
Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
Mock.yards = { nameplate1 = 4, nameplate2 = 20 }
ns = load("a signal that resolves and then answers nobody")
if ns then
	local scenario = "a signal that resolves and then answers nobody"
	drive(scenario, ns)
	settle(ns)
	ns.db.profile.filters.proximity = "near"

	local first = inQueue(ns)
	if ns.proximity.source ~= "LibRangeCheck-3.0" then
		fail(scenario, "SKIPPED -- the library was not picked up, so there is"
			.. " nothing here to demote")
	else
		if first["Far Away"] then
			fail(scenario, "a rung that could not tell let somebody twenty yards off"
				.. " straight through, with a working rung underneath it")
		end
		if not first["Close By"] then
			fail(scenario, "dropped somebody four yards away")
		end

		-- Scans, not one long one: the count is about a source that never
		-- answers, and it must not be reset by a scan boundary.
		for _ = 1, 60 do ns.BuildQueue() end

		if ns.proximity.source ~= "CheckInteractDistance" then
			fail(scenario, "still measuring with " .. tostring(ns.proximity.source)
				.. " after sixty scans of it answering nothing")
		end
		if not tostring(ns.proximity.note or ""):find("answered for nobody", 1, true) then
			fail(scenario, "nothing says why the signal changed: "
				.. tostring(ns.proximity.note))
		end
		if inQueue(ns)["Far Away"] then
			fail(scenario, "the rung underneath was picked up and still offered"
				.. " somebody twenty yards away")
		end

		-- And it stays dropped through the capability probe, which runs on
		-- every SPELLS_CHANGED. A talent change moves a bucket edge; it does
		-- not make a withheld GUID readable.
		ns.Guard("probe", ns.ProbeCapabilities)
		inQueue(ns)
		if ns.proximity.source ~= "CheckInteractDistance" then
			fail(scenario, "the capability probe put back a rung dropped for answering"
				.. " nobody: " .. tostring(ns.proximity.source))
		end
	end
end

-- Nobody is measured in a fight.
--
-- Every signal is restricted there: the interact prompts refuse outright for a
-- friendly unit, and the library falls back to a spell-only checker list whose
-- every bucket is wider than any step this setting offers. Measuring anyway
-- would drop the whole square on a reading nobody took -- and the prompt cannot
-- rearm during a fight in any case.
Mock.reset()
Mock.inCombat = true
Mock.yardsDefault = 25
Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
ns = load("nobody is measured in a fight")
if ns then
	local scenario = "nobody is measured in a fight"
	drive(scenario, ns)
	settle(ns)
	ns.db.profile.filters.proximity = "beside"

	Mock.counts.interact = 0
	if not inQueue(ns)["Far Away"] then
		fail(scenario, "dropped somebody during a fight, on a distance the client"
			.. " will not answer during one")
	end
	if Mock.counts.interact > 0 then
		fail(scenario, ("asked the client how far away somebody was %d times"
			.. " during a fight"):format(Mock.counts.interact))
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 159
-- The first login.
--
-- Installing this addon used to do nothing you could see: no line in chat, no
-- indication it had loaded, and no prompt until -- at some unpredictable later
-- moment -- a stranger buffed you and a panel appeared somewhere on screen.
--
-- Two things make or break the fix and neither is the wording. It has to
-- happen at all, and it has to happen once: a greeting that comes back on
-- every /reload, on the client that makes you reload for every settings
-- change, is worse than the silence it replaced.

-- Nobody targeted and no nameplates up: what coming off a loading screen
-- actually looks like.
--
-- The mock answers yes to UnitExists for every token there is, "target"
-- included, so a bare session in it always has somebody on the prompt already.
-- That is the crowded case, and the greeting is deliberately different for it
-- -- scenario 163 is where it belongs. Without this, the three scenarios below
-- would be testing that case while claiming to test the empty one.
local function withEmptyPrompt(fn)
	local real = UnitExists
	UnitExists = function(unit) return unit == "player" end
	local ok, err = pcall(fn)
	UnitExists = real
	if not ok then error(err, 0) end
end

-- A login, up to and including the delay the greeting hangs off. Returns
-- everything said from the moment the world was ready, or nil if the session
-- would not start at all -- which is a different failure and says so.
local function firstLogin(ns)
	if not pcall(function() ns.addon:OnInitialize() end) then return nil end
	if not pcall(function() ns.addon:OnEnable() end) then return nil end
	Mock.printed = {}
	-- Nothing has been said yet: the greeting is parked on the same two-second
	-- delay as the build line, because anything printed before the default
	-- chat frame exists is printed to nobody.
	if not pcall(function() withEmptyPrompt(function() Mock.runTimers(2) end) end) then
		return nil
	end
	return table.concat(Mock.printed, "\n")
end

Mock.reset()
Mock.sv = {}
ns = load("the first login says what this is, once")
if ns then
	local scenario = "the first login says what this is, once"
	local said = firstLogin(ns)
	if not said then
		fail(scenario, "the first session would not start at all")
	else
		if not said:find("Manners", 1, true) then
			fail(scenario, "a fresh install said nothing whatever: " .. said)
		end

		-- The one thing that is not automatic, named both ways it can be done.
		-- An explanation that leaves out the part the person has to do is the
		-- tour without the point of it: the prompt sits there and nothing ever
		-- presses it.
		if not said:find("/manners macro", 1, true) then
			fail(scenario, "never named the command that makes the macro: " .. said)
		end
		if not said:find("Create the macro", 1, true) then
			fail(scenario, "never named the button on the options page that does"
				.. " the same thing: " .. said)
		end
		if not said:find("Keybindings", 1, true) then
			fail(scenario, "never mentioned the keybinding: " .. said)
		end

		-- And it is shown, not only described. Where the prompt sits is the
		-- half of this that words cannot do.
		if not ns.Prompt:InTest() then
			fail(scenario, "never put the prompt on screen, so nobody knows what it"
				.. " looks like or where it is")
		end
		if not (ns.db.char and ns.db.char.welcomed) then
			fail(scenario, "nothing was written down, so this happens again every login")
		end
	end

	-- /reload: the same saved file, a fresh namespace.
	ns.Prompt:ExitTest()
	local again = load("the first login says what this is, once")
	if not again then
		fail(scenario, "the second session would not load")
	else
		local saidAgain = firstLogin(again)
		if not saidAgain then
			fail(scenario, "the second session would not start")
		elseif saidAgain:find("not automatic", 1, true) then
			fail(scenario, "greeted all over again after a reload: " .. saidAgain)
		elseif again.Prompt:InTest() then
			fail(scenario, "put a preview up again after a reload")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 160
-- A class that can never fill the prompt gets the sentence it already had, and
-- none of the rest.
--
-- There is no point previewing a panel that will never have anybody on it, and
-- less than none in telling somebody to put it on a bar. The honest line
-- already exists -- /manners debug has printed it for as long as it has
-- existed -- so it is the same line, from the same string.
Mock.reset()
Mock.sv = {}
Mock.class = "ROGUE"
ns = load("a rogue is told the truth, not sold a macro")
if ns then
	local scenario = "a rogue is told the truth, not sold a macro"
	local said = firstLogin(ns) or ""
	-- The greeting's own line, not the sentence alone: the login line says the
	-- same sentence now, so finding it anywhere proves nothing about the
	-- greeting.
	if not said:find("is installed, but " .. tostring(ns.NO_CLASS_BUFFS), 1, true) then
		fail(scenario, "did not say the one honest thing there is to say here: " .. said)
	end
	if said:find("/manners macro", 1, true) then
		fail(scenario, "told a class with nothing to cast to put it on a bar: " .. said)
	end
	if ns.Prompt:InTest() then
		fail(scenario, "previewed a prompt that can never have anybody on it")
	end
	-- Once, like the rest of it. A line about a permanent state, repeated on
	-- every login, is nagging.
	if not (ns.db.char and ns.db.char.welcomed) then
		fail(scenario, "did not write it down, so the rogue hears this every login")
	end
end
Mock.reset()

-- The same character, logging straight into a pull. Every other greeting waits
-- for the fight to end because half of it is a panel that cannot be shown
-- during one; this one is two lines of words, and made to wait it would arrive
-- at the end of the pull attached to nothing.
Mock.reset()
Mock.sv = {}
Mock.class = "ROGUE"
Mock.inCombat = true
ns = load("a rogue is told the truth, not sold a macro")
if ns then
	local scenario = "a rogue is told the truth, not sold a macro"
	local said = firstLogin(ns) or ""
	if not said:find("is installed, but " .. tostring(ns.NO_CLASS_BUFFS), 1, true) then
		fail(scenario, "made a words-only greeting wait for a fight to end: " .. said)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 161
-- A class the buff data has never heard of is not told it has nothing.
--
-- hasClassBuffs is false for this character exactly as it is for the rogue
-- above, and the two deserve opposite treatment: one is a fact recorded in the
-- tables, the other is an unrecognised client's guessed set coming up empty.
-- Stating the guess as a fact -- on the one screenful somebody reads before
-- deciding whether to keep the addon -- is the failure this guards.
Mock.reset()
Mock.sv = {}
Mock.class = "EVOKER"
ns = load("an unknown class is not told it has nothing")
if ns then
	local scenario = "an unknown class is not told it has nothing"
	local said = firstLogin(ns) or ""
	if said:find(tostring(ns.NO_CLASS_BUFFS), 1, true) then
		fail(scenario, "told a class it has never heard of that it has nothing to"
			.. " give, which it does not know: " .. said)
	end
	if said:find("/manners macro", 1, true) then
		fail(scenario, "greeted a character it could work nothing out about: " .. said)
	end
	-- And left the slate clean, so a build with the right data for this client
	-- still gets its one chance to say hello.
	if ns.db.char and ns.db.char.welcomed then
		fail(scenario, "used up the one greeting there is on a character it could"
			.. " not read")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 162
-- Logging straight into a pull.
--
-- The panel is a protected frame: it cannot be shown during lockdown at all.
-- Firing here would spend the one greeting this character ever gets on a
-- picture nobody sees, so it stands down and the end of the fight comes back
-- for it.
Mock.reset()
Mock.sv = {}
Mock.inCombat = true
ns = load("the greeting waits for the fight to end")
if ns then
	local scenario = "the greeting waits for the fight to end"
	local said = firstLogin(ns) or ""
	if said:find("not automatic", 1, true) then
		fail(scenario, "greeted in the middle of a fight, where the prompt cannot be"
			.. " put on screen at all: " .. said)
	end
	if ns.db.char and ns.db.char.welcomed then
		fail(scenario, "wrote the greeting off without anybody having seen it")
	end

	-- Asked for outright, it says why nothing happened rather than printing
	-- three lines about a panel that is not going to appear.
	Mock.printed = {}
	ns.addon:HandleSlash("welcome")
	local forced = table.concat(Mock.printed, "\n")
	if not forced:find("not during a fight", 1, true) then
		fail(scenario, "/manners welcome in a fight said nothing about why nothing"
			.. " happened: " .. forced)
	end

	Mock.inCombat = false
	Mock.printed = {}
	withEmptyPrompt(function() ns.addon:PLAYER_REGEN_ENABLED() end)
	local after = table.concat(Mock.printed, "\n")
	if not after:find("not automatic", 1, true) then
		fail(scenario, "never came back for it once the fight ended: " .. after)
	end
	if not ns.Prompt:InTest() then
		fail(scenario, "came back with the words and not the picture")
	end
	ns.Prompt:ExitTest()
end
Mock.reset()

-- ------------------------------------------------------------------ 163
-- A crowded city, which is where this addon is actually used.
--
-- Refresh drops a mock-up the moment a real person is waiting, and rightly so.
-- That means a greeting that starts a preview regardless would print "preview
-- on", have it taken away on the next scan, and leave three lines in chat
-- pointing at a panel it did not put there and cannot explain.
Mock.reset()
Mock.sv = {}
Mock.unitNames = { nameplate1 = { "Close", "By" } }
ns = load("the greeting does not cover somebody real")
if ns then
	local scenario = "the greeting does not cover somebody real"
	drive(scenario, ns)
	settle(ns)
	if #ns.BuildQueue() == 0 then
		fail(scenario, "SKIPPED -- nobody was on the prompt, so nothing below is"
			.. " about a crowded city")
	else
		ns.Prompt:ExitTest()
		Mock.printed = {}
		ns.Welcome(true)
		local said = table.concat(Mock.printed, "\n")

		-- Asserted on what was said, not on whether the preview is still up.
		-- Starting one here does not leave one running: ToggleTest refreshes
		-- on its way out, the refresh sees a real person waiting and drops the
		-- mock-up inside the same call. So InTest() is false either way, and a
		-- scenario resting on it would have measured nothing. What is left
		-- behind is three contradictory lines in chat -- "preview on", "preview
		-- off -- somebody real turned up", and a greeting claiming the panel
		-- has a pretend name on it -- and that is the damage.
		if said:find("preview on", 1, true) then
			fail(scenario, "started a preview in front of a real person who is"
				.. " waiting, and had it taken away in the same breath: " .. said)
		end
		if said:find("pretend name", 1, true) then
			fail(scenario, "told somebody the panel has a mock-up on it while a real"
				.. " person is standing on it: " .. said)
		end
		if not said:find("somebody real on it already", 1, true) then
			fail(scenario, "did not point at the panel that is actually on screen: " .. said)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 164
-- Somebody will want to see it again -- after moving the prompt, or to show a
-- guildmate what it looks like. So there is a command, and it plays for
-- somebody who has already been greeted.
--
-- The trap is that the preview is a toggle. A command that says "here is the
-- prompt" and takes the prompt off the screen is the whole feature undoing
-- itself, and it is one keypress away: type it twice.
Mock.reset()
Mock.sv = {}
ns = load("welcome can be asked for again without undoing itself")
if ns then
	local scenario = "welcome can be asked for again without undoing itself"
	drive(scenario, ns)
	ns.db.char.welcomed = true
	ns.Prompt:ExitTest()

	Mock.printed = {}
	withEmptyPrompt(function() ns.addon:HandleSlash("welcome") end)
	local said = table.concat(Mock.printed, "\n")
	if not said:find("not automatic", 1, true) then
		fail(scenario, "would not play for somebody who has seen it before: " .. said)
	end
	if not ns.Prompt:InTest() then
		fail(scenario, "said here is the prompt and put nothing on screen")
	end

	Mock.printed = {}
	withEmptyPrompt(function() ns.addon:HandleSlash("welcome") end)
	if not ns.Prompt:InTest() then
		fail(scenario, "a second /manners welcome took the preview back down again")
	end
	ns.Prompt:ExitTest()
end
Mock.reset()

-- ------------------------------------------------------------------ 165
-- The second character on the account, which is the whole of why the flag is
-- kept in db.char.
--
-- OnInitialize builds the AceDB with `true` for its third argument: every
-- character on the account starts on the one profile named "Default". A flag
-- kept there would greet whoever logged in first and no other character, ever
-- -- which is exactly the silence this feature exists to end. And what the
-- greeting asks for is per character anyway: a macro dragged onto this
-- character's bars, or a key bound for it.
Mock.reset()
Mock.sv = {}
ns = load("an alt on the same account is greeted too")
if ns then
	local scenario = "an alt on the same account is greeted too"
	local first = firstLogin(ns) or ""
	if not first:find("not automatic", 1, true) then
		fail(scenario, "SKIPPED -- the first character was not greeted, so nothing"
			.. " below is about the second: " .. first)
	else
		ns.Prompt:ExitTest()

		-- Log out, log in as somebody else: the same saved file, the same
		-- shared profile, a different character.
		Mock.character = "Perrin Stonewell"
		local alt = load("an alt on the same account is greeted too")
		if not alt then
			fail(scenario, "the alt's session would not load")
		else
			local said = firstLogin(alt) or ""
			if alt.db.profile ~= ns.db.profile then
				fail(scenario, "SKIPPED -- the alt was handed a profile of its own, so"
					.. " nothing here says where the flag is kept")
			elseif not said:find("not automatic", 1, true) then
				fail(scenario, "an alt sharing the account's one profile was never"
					.. " greeted at all: " .. said)
			end
			alt.Prompt:ExitTest()
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 166
-- Greeted on an alt of somebody who switched the addon off.
--
-- The profile is shared across the account, so /manners off taken on one
-- character is /manners off on every character made afterwards. The greeting
-- would otherwise describe a prompt that is never going to appear, which reads
-- as an addon that does not work rather than as a setting.
Mock.reset()
Mock.sv = {}
ns = load("a greeting on a switched-off profile says so")
if ns then
	local scenario = "a greeting on a switched-off profile says so"
	drive(scenario, ns)
	ns.db.profile.enabled = false
	ns.Prompt:ExitTest()

	Mock.printed = {}
	withEmptyPrompt(function() ns.addon:HandleSlash("welcome") end)
	local said = table.concat(Mock.printed, "\n")
	if not said:find("switched off", 1, true) then
		fail(scenario, "explained a prompt that `enabled` keeps off the screen,"
			.. " without saying so: " .. said)
	end
	if not said:find("/manners on", 1, true) then
		fail(scenario, "said it was off without saying how to turn it on: " .. said)
	end
	ns.Prompt:ExitTest()
	ns.db.profile.enabled = true
end
Mock.reset()

-- ------------------------------------------------------------------ 167
-- A setting changed from somewhere that is not the control for it.
--
-- AceConfig asks a control for its value, its name and its `hidden` only while
-- it is drawing, so an options page left open goes on showing whatever was true
-- when it was last painted. /manners off is the one anybody meets: the addon
-- switches off, the prompt vanishes, and the page still has Enable ticked with
-- the red notice written for exactly that moment still hidden -- which reads as
-- a command that did not take.
--
-- The list below is retyped rather than derived, because the addon's own list
-- is a file local and there is nothing on the namespace to walk. That is a real
-- gap and worth naming: a command added later that writes a setting, and not
-- added to the repaint list, is not covered by anything here.
Mock.reset()
ns = load("a setting changed from outside the page repaints it")
if ns then
	local scenario = "a setting changed from outside the page repaints it"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	local function repaintsFor(word)
		Mock.optionsRepaints = 0
		ns.addon:HandleSlash(word)
		return Mock.optionsRepaints
	end

	for _, word in ipairs({ "on", "off", "verbose", "clicks", "restore", "lock", "unlock" }) do
		if repaintsFor(word) == 0 then
			fail(scenario, ("/manners %s wrote a setting and left an open page drawing"
				.. " the value it had before"):format(word))
		end
	end
	-- Put back what the walk above left changed: it ended on `unlock`, and an
	-- unlocked prompt never casts.
	ns.addon:HandleSlash("on")
	ns.addon:HandleSlash("lock")

	-- And why the repaint is worth making. A count of NotifyChange calls says
	-- only that something was asked to redraw; these two say the page has
	-- something different to draw -- a box whose answer has flipped, and a
	-- notice that has become the one thing on the tab worth reading.
	local general = ns.optionsTable and ns.optionsTable.args.general
	local enable = general and general.args.enabled
	local notice = general and general.args.offNotice
	if not (enable and enable.get and notice and notice.hidden) then
		fail(scenario, "SKIPPED -- no Enable box and no switched-off notice to read,"
			.. " so the repaints counted above are not shown to matter")
	else
		ns.addon:HandleSlash("off")
		if enable.get({ "enabled" }) ~= false then
			fail(scenario, "the Enable box still answers `ticked` after /manners off")
		end
		if notice.hidden() then
			fail(scenario, "the red switched-off notice stayed hidden through the one"
				.. " moment it was written for")
		end
		ns.addon:HandleSlash("on")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 168
-- What a broker display actually shows.
--
-- The launcher's text was the constant "Manners" -- the addon's name, written
-- beside the addon's icon -- and its tooltip said "Right click: enable or
-- disable", which is true of every press and says nothing about this one. So on
-- a broker bar the only way to learn whether Manners was on was to click it and
-- read chat, and clicking changes the answer.
--
-- Off is the state that needs carrying, because off is invisible from outside:
-- the prompt simply never appears, which is indistinguishable from the addon
-- being broken. Somebody who ran /manners off last week is the case.
Mock.reset()
ns = load("the launcher says whether the addon is on")
if ns then
	local scenario = "the launcher says whether the addon is on"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	local broker = Mock.broker
	if not (broker and broker.OnTooltipShow) then
		fail(scenario, "SKIPPED -- no data object was registered, so there is no launcher"
			.. " to read")
	else
		local function tooltipSays()
			local lines = {}
			local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
			local ok, err = pcall(broker.OnTooltipShow, tt)
			if not ok then
				fail(scenario, "the launcher tooltip threw -> " .. tostring(err))
				return ""
			end
			return table.concat(lines, "\n"):lower()
		end

		ns.addon:HandleSlash("on")
		local onText, onTip = tostring(broker.text), tooltipSays()
		ns.addon:HandleSlash("off")
		local offText, offTip = tostring(broker.text), tooltipSays()

		if onText == offText then
			fail(scenario, ("the launcher reads the same on as off (%q), so the only way"
				.. " to ask a broker bar what state this is in is to click it --"
				.. " which changes the answer"):format(onText))
		end
		if not offText:lower():find("off", 1, true) then
			fail(scenario, "the launcher's text does not say it is off: " .. offText)
		end
		if onText:lower():find("off", 1, true) then
			fail(scenario, "the launcher says off while it is on: " .. onText)
		end

		-- The tooltip as well as the text, because a broker display is free to
		-- show the icon on its own -- and on the minimap that is the only shape
		-- it has. Then the tooltip is the last place left that can say why no
		-- prompt has appeared all evening.
		if not offTip:find("switched off", 1, true) then
			fail(scenario, "the tooltip never names the state, which on a minimap button"
				.. " is the only place it can be named: " .. offTip)
		end
		if onTip:find("switched off", 1, true) then
			fail(scenario, "the tooltip says switched off while it is on: " .. onTip)
		end

		-- And the click that flips it puts both back in step, since that click is
		-- itself one of the ways the state changes behind an open page.
		Mock.optionsRepaints = 0
		local ok, err = pcall(broker.OnClick, broker, "RightButton")
		if not ok then
			fail(scenario, "right-clicking the launcher threw -> " .. tostring(err))
		else
			if tostring(broker.text) ~= onText then
				fail(scenario, "right-clicking switched it back on and left the launcher"
					.. " still reading " .. tostring(broker.text))
			end
			if Mock.optionsRepaints == 0 then
				fail(scenario, "the minimap button flipped the switch and left an open"
					.. " options page drawing the old value")
			end
		end
		if not ns.db.profile.enabled then ns.addon:HandleSlash("on") end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 169
-- "Show minimap button" on a client where LibDBIcon never loaded.
--
-- The button takes both libraries and SetupOptions only registers one when it
-- has both -- but the checkbox was drawn unconditionally. Ticking it wrote a
-- setting nothing reads and called Show on a button that was never registered:
-- a control that saves, reports success and does nothing at all, which from the
-- outside is the addon being broken rather than a library being absent.
--
-- Not a hypothetical. Both libraries are fetched with LibStub's silent flag
-- precisely because they are embedded copies, and an embedded copy is the kind
-- of thing a packaging mistake drops.
Mock.reset()
Mock.missingLibs = { ["LibDBIcon-1.0"] = true }
ns = load("no LibDBIcon, no minimap checkbox")
if ns then
	local scenario = "no LibDBIcon, no minimap checkbox"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	local general = ns.optionsTable and ns.optionsTable.args.general
	local toggle = general and general.args.minimap
	local header = general and general.args.miscHeader
	if not toggle then
		fail(scenario, "SKIPPED -- there is no minimap control to look for")
	else
		if not (toggle.hidden and toggle.hidden()) then
			fail(scenario, "the minimap checkbox is on the page with no library behind it,"
				.. " so ticking it writes a setting nothing reads and shows a button"
				.. " that was never registered")
		end
		if header and not (header.hidden and header.hidden()) then
			fail(scenario, "the Minimap header is drawn over nothing at all")
		end
		-- Whatever the page shows, the setter has to survive being reached: a
		-- profile carried over from a client that had the library arrives with
		-- the setting already in it, and AceDB restores it without asking.
		if toggle.set then
			local ok, err = pcall(toggle.set, { "minimap" }, true)
			if not ok then
				fail(scenario, "the minimap setter threw without the library -> " .. tostring(err))
			end
		end
	end
end
Mock.missingLibs = nil
Mock.reset()

-- The other half, and the half that keeps the check above honest: with the
-- libraries there the control is on the page. Hiding it always would satisfy
-- everything above and quietly take the minimap button off everybody's page.
ns = load("the minimap checkbox is there when the library is")
if ns then
	local scenario = "the minimap checkbox is there when the library is"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	local general = ns.optionsTable and ns.optionsTable.args.general
	local toggle = general and general.args.minimap
	if not toggle then
		fail(scenario, "SKIPPED -- there is no minimap control to look for")
	elseif toggle.hidden and toggle.hidden() then
		fail(scenario, "the minimap checkbox is hidden on a client that has both"
			.. " libraries, so the button can never be turned back on")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 170
-- /manners try, measured against the same budget as every other macro here.
--
-- What goes on the button is the expansion, and the client truncates a macro
-- body over the limit without a word -- so the expansion this command echoes to
-- chat was presented as what will run while the button held a cut-off version
-- of it. On a console whose entire purpose is one experiment per reload, that
-- is the experiment quietly answering a different question.
Mock.reset()
ns = load("the console measures the macro it arms")
if ns then
	local scenario = "the console measures the macro it arms"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	local function arming(text)
		Mock.printed = {}
		ns.addon:HandleSlash("try " .. text)
		return table.concat(Mock.printed, "\n"):lower()
	end

	-- Well inside the budget. A warning here would be noise on every experiment
	-- anybody ever runs, which is how a warning stops being read.
	local short = arming("/cast {spell}")
	if short:find("over the", 1, true) then
		fail(scenario, "a macro comfortably inside the budget was reported as too long: "
			.. short)
	end

	local long = arming("/cast " .. string.rep("x", ns.MACRO_LIMIT + 40))
	if not long:find("over the", 1, true) then
		fail(scenario, "macro text longer than a macro body was armed and echoed to chat"
			.. " as though that is what will run: " .. long)
	end
	if not long:find(tostring(ns.MACRO_LIMIT), 1, true) then
		fail(scenario, "the warning never names the budget it measured against, so there"
			.. " is nothing to cut the macro down to: " .. long)
	end
	-- Still armed. Refusing the one experiment somebody is running is the worse
	-- half of the choice; telling them it will be cut is the whole point.
	if not ns.tryMacro then
		fail(scenario, "a macro over the limit was refused outright rather than armed"
			.. " and reported")
	end
	ns.addon:HandleSlash("try")
end
Mock.reset()

-- ------------------------------------------------------------------ 171
-- The framed look on a panel colour that is not the default dark one.
--
-- The border is derived from the panel rather than fixed, and the comment above
-- it says why: a light panel with a hardcoded pale border has no border at all.
-- The derivation was brightening towards white, which is that same failure
-- reached from the other side -- the lighter the panel, the less room there is
-- above it, so the edge converges on the panel exactly as the panel goes pale,
-- and on a white panel the two are the same colour.
Mock.reset()
ns = load("the framed border does not converge on a pale panel")
if ns then
	local scenario = "the framed border does not converge on a pale panel"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	local p = ns.db.profile.prompt
	p.style = "framed"

	-- How far the border sits from the panel it is drawn on, in the channel that
	-- carries most of the apparent brightness. Zero is a frame nobody can see.
	local function edgeGap(r, g, b)
		p.bgColor = { r, g, b, 1 }
		ns.Prompt:ApplyStyle()
		local edges = ns.Prompt:Regions().edges
		local c = edges and edges[1] and edges[1]._color
		if not c then return nil end
		return math.abs(c[2] - g)
	end

	local dark = edgeGap(0.04, 0.04, 0.06)
	local pale = edgeGap(0.95, 0.96, 0.98)
	local white = edgeGap(1, 1, 1)
	if not (dark and pale and white) then
		fail(scenario, "SKIPPED -- the framed look painted no edge to measure")
	else
		if white < 0.20 then
			fail(scenario, ("a white panel got a border %0.3f away from it: the framed look"
				.. " has no frame, which is the one thing the comment above the"
				.. " derivation says it exists to prevent"):format(white))
		end
		if pale < dark * 0.5 then
			fail(scenario, ("the border closes on the panel as the panel gets lighter --"
				.. " %0.3f of separation on a dark panel, %0.3f on a pale one")
				:format(dark, pale))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 172
-- The count chip, at the top of the font slider.
--
-- It was a fixed 20x14 box with a fixed 28px reserved beside it, holding a
-- number drawn at fontSize - 3. The slider goes to 32, where those digits are
-- twice the height of the box they sit in and wider than the gap left for it:
-- the chip reads as a smudge behind a number lying across the name. Nothing
-- throws and nothing looks broken from inside the code.
Mock.reset()
ns = load("the count chip is sized from the font inside it")
if ns then
	local scenario = "the count chip is sized from the font inside it"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	local p = ns.db.profile.prompt
	p.showCount = true

	local function chipAt(fontSize)
		p.fontSize = fontSize
		ns.Prompt:ApplyStyle()
		local r = ns.Prompt:Regions()
		local inset
		for _, point in ipairs(r.name and r.name.points or {}) do
			if point[1] == "RIGHT" then inset = point[2] end
		end
		return r.chip and r.chip._width, r.chip and r.chip._height,
			r.count and r.count._font and r.count._font.size, inset
	end

	local w, h, size, inset = chipAt(32)
	if not (w and h and size) then
		fail(scenario, "SKIPPED -- nothing recorded the chip's size or the font in it")
	else
		-- A digit is roughly as tall as the font's size and about half of it
		-- across. A box shorter than one digit, or narrower than two, is a
		-- number drawn outside its own background.
		if h < size then
			fail(scenario, ("the chip is %d high around a %d font, so the digits stand out"
				.. " of the top and bottom of it"):format(h, size))
		end
		if w < size then
			fail(scenario, ("the chip is %d wide around a %d font, so two digits run out"
				.. " of both ends of it"):format(w, size))
		end
		-- And the room the name is told to leave has to move with the chip, or
		-- the number sits on top of the name whatever size the box is.
		if not inset then
			fail(scenario, "SKIPPED -- the name has no right-hand anchor to read")
		elseif math.abs(inset) < w then
			fail(scenario, ("the name may run to %d of the right edge while the chip is %d"
				.. " wide, so the two overlap"):format(math.abs(inset), w))
		end
	end

	-- Same font at both ends of the slider would mean it is not sized from the
	-- font at all, whatever the numbers above happen to be.
	local small = chipAt(8)
	local large = chipAt(32)
	if small and large and small == large then
		fail(scenario, "the chip is the same width at font 8 and font 32, so nothing"
			.. " about it comes from the font")
	end
	p.fontSize = 13
	ns.Prompt:ApplyStyle()
end
Mock.reset()

-- ------------------------------------------------------------------ 173
-- How many things have broken, as opposed to how many are still in the list.
--
-- The list is a ring thirty deep, so its length stopped being the answer the
-- moment the thirty-first thing broke -- and "the last 5 of 30" printed whether
-- thirty things had gone wrong or thirty thousand had. Those want opposite
-- responses: one is a bug worth sending in, the other is a handler throwing on
-- every frame, which is this addon grinding a client to a halt and wants a
-- /reload now.
Mock.reset()
ns = load("errors says how much broke, not how much was kept")
if ns then
	local scenario = "errors says how much broke, not how much was kept"
	drive(scenario, ns)
	ns.Prompt:ExitTest()

	-- Guard wraps the tick, so a failure that repeats does so two and a half
	-- times a second: this is a couple of minutes of one broken handler, not a
	-- pathological case.
	local BROKEN = 400
	for _ = 1, BROKEN do
		ns.Guard("a scenario breaking something", function() error("boom", 0) end)
	end
	local kept = #ns.errors
	if kept >= BROKEN then
		fail(scenario, "SKIPPED -- nothing was dropped, so the two numbers are the same"
			.. " and nothing below distinguishes them")
	else
		Mock.printed = {}
		ns.addon:HandleSlash("errors")
		local said = table.concat(Mock.printed, "\n")
		if not said:find(tostring(BROKEN), 1, true) then
			fail(scenario, ("/manners errors gave the size of the ring as the number of"
				.. " failures: %d things broke and it said %d -- %s")
				:format(BROKEN, kept, said))
		end
		if not said:find(tostring(kept) .. " kept", 1, true) then
			fail(scenario, "the header names a number far larger than the list under it"
				.. " without saying how many were kept: " .. said)
		end

		-- The same two numbers in the block somebody pastes into a bug report,
		-- where whoever reads it cannot ask a follow-up question.
		local diagnostics = ns.optionsTable and ns.optionsTable.args.diagnostics
		local report = diagnostics and diagnostics.args.report
		if not (report and report.get) then
			fail(scenario, "SKIPPED -- no bug-report box to read")
		else
			local text = tostring(report.get({ "report" }))
			if not text:find("errors: " .. BROKEN, 1, true) then
				fail(scenario, "the bug report gives the ring's size as the session's"
					.. " failure count: " .. (text:match("errors:[^\n]*") or text))
			end
			if not text:find("(" .. kept .. " kept)", 1, true) then
				fail(scenario, "the bug report never says how many of them are listed"
					.. " below it: " .. (text:match("errors:[^\n]*") or text))
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ presses
-- Helpers for the scenarios below, which are all about who a press reaches.
--
-- Named strangers on nameplates and nobody else: no target, focus or mouseover.
-- The mock answers yes to UnitExists for every token there is, so without this
-- the target slot is a third person, and a scenario about which of two people a
-- press went to is about three. Hands back the undo, because UnitExists is a
-- global that Mock.reset does not own.
local function strangers(names)
	Mock.unitNames = names
	local real = UnitExists
	UnitExists = function(unit)
		if unit == "player" then return true end
		return names[unit] ~= nil
	end
	return function() UnitExists = real end
end

-- A clean slate after the lifecycle: the debts, the blocks and the parked click
-- that driving it leaves behind cleared, the clock moved well clear of any
-- cooldown, and the nameplates the queue is to walk registered.
local function clearClicks(ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.pendingClick = nil
	for unit in pairs(Mock.unitNames or {}) do
		if unit:find("^nameplate") then ns.nameplateUnits[unit] = true end
	end
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.verbose = true
	Mock.printed = {}
end

local function freshPrompt(ns, scenario)
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	clearClicks(ns)
end

-- One press as the client delivers it: PreClick, then the secure handler reads
-- whatever macro is on the button at that moment -- which is what this hands
-- back, nil for nothing -- then PostClick.
local function pressButton(ns, mouseButton)
	local button = ns.Prompt:GetButton()
	mouseButton = mouseButton or "LeftButton"
	if button.scripts.PreClick then button.scripts.PreClick(button, mouseButton, true) end
	local ran = button:GetAttribute("macrotext1")
	if button.scripts.PostClick then button.scripts.PostClick(button, mouseButton, true) end
	return ran
end

local function owe(ns, name)
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
end

-- ------------------------------------------------------------------ 174
-- The second half of a press fires only what the first half armed.
--
-- PreClick is debounced: down and up both land in it, and one rebuild per press
-- is enough. The debounce used to let anything at all through. A press the
-- client refuses -- out of range arrives as an error and no cast -- repaints the
-- prompt onto the next person in the same frame, so a second press a tenth of a
-- second later ran *their* macro without being resolved, and PostClick,
-- debounced as well, filed nothing for it. The record from the refused press was
-- still parked, and the cast that went out settled it: the first person was
-- counted repaid, and the one who actually got the buff -- and the /say --
-- stayed owed, to be offered and spoken to all over again.
Mock.reset()
local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
ns = load("the second half of a press fires only what the first half armed")
if ns then
	local scenario = "the second half of a press fires only what the first half armed"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	owe(ns, "Bert Beside")
	ns.addon:Tick()
	local first = pressButton(ns)
	if not (first and first:find("Anna Aim", 1, true)) then
		fail(scenario, "SKIPPED -- the first press was not aimed at Anna: " .. tostring(first))
	else
		ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
		local rearmed = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if not (rearmed and rearmed:find("Bert Beside", 1, true)) then
			fail(scenario, "SKIPPED -- the refusal did not move the prompt on to Bert, so"
				.. " there is nothing stale for the debounce to let through")
		else
			Mock.advance(0.1)
			local second = pressButton(ns)
			if second then
				fail(scenario, "a press inside the debounce ran a macro nothing resolved: "
					.. (second:gsub("\n", " / ")))
				ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-2", 1459)
				if not ns.owed["Anna Aim"] then
					fail(scenario, "Anna was counted repaid by the cast that went to Bert")
				end
			end
		end
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 175
-- A cast a second after a refused press is not that press's answer.
--
-- The client reports a cast it accepted in the same frame. An error means it
-- accepted nothing, and the record stays parked for the rest of the window only
-- so a cast arriving just behind the error can still settle it -- and anything
-- inside the window used to. This client names nobody in the cast event, so a
-- hand-cast Arcane Intellect on somebody else a second later was taken for the
-- refused press landing, and the favour was repaid to a person who got nothing.
-- A hand-cast Frostbolt was worse: the panel flashed red about a spell id, and
-- the chat blamed the Frostbolt for a press the game had refused for range.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("a cast a second after a refused press is not its answer")
if ns then
	local scenario = "a cast a second after a refused press is not its answer"
	freshPrompt(ns, scenario)
	for _, spell in ipairs({ 1459, 116 }) do
		clearClicks(ns)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		if not pressButton(ns) then
			fail(scenario, "SKIPPED -- nothing was armed to press")
		else
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
			Mock.advance(0.4)
			ns.addon:Tick()
			Mock.advance(0.6)
			Mock.printed = {}
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", spell)
			local said = table.concat(Mock.printed, "\n")
			if not ns.owed["Anna Aim"] then
				fail(scenario, ("a hand-cast %s a second after a refused press repaid Anna,"
					.. " who got nothing"):format(tostring(spell)))
			end
			if said:find("counted as repaid", 1, true) or said:find("went out instead", 1, true) then
				fail(scenario, "a cast a second later was judged against the refused press: " .. said)
			end
		end
	end

	-- Inside the moment a cast can answer, the spell that went out instead is
	-- named. "116 went out instead" is a number only the client knows.
	clearClicks(ns)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if pressButton(ns) then
		Mock.printed = {}
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-3", 116)
		local said = table.concat(Mock.printed, "\n")
		if not said:find("Frostbolt", 1, true) then
			fail(scenario, "the spell that went out instead was not named: " .. said)
		end
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 176
-- In a fight, a press inside the global cooldown is not filed.
--
-- The guard that stops such a press is out-of-combat only: the macro is frozen
-- in a fight and cannot be disarmed. PreClick returned on the lockdown before it
-- ever asked about the cooldown, so PostClick filed the press against the frozen
-- person, and the game's "not ready yet" was booked against them exactly as it
-- was before the guard existed -- a buff confirmed eight seconds earlier had its
-- block cut to two, and the panel flashed that they could not be buffed. In a
-- fight the cooldown is running almost all the time.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("in a fight, a press inside the cooldown is not filed")
if ns then
	local scenario = "in a fight, a press inside the cooldown is not filed"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local entry = ns.BuildQueue()[1]
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	if not (entry and entry.buff and pressButton(ns)) then
		fail(scenario, "SKIPPED -- nothing was armed when the fight started")
	else
		local key = entry.name .. "\0" .. entry.buff.key
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-1", 1459)
		Mock.advance(3)
		ns.addon:Tick()
		-- Something cast by hand, so the next press lands in its cooldown.
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-hand", 116)
		Mock.advance(0.5)
		local blocked = ns.tried[key]
		if ns.CastReady() or not blocked then
			fail(scenario, "SKIPPED -- no cooldown running, or nothing blocked to be cut")
		else
			pressButton(ns)
			if ns.pendingClick then
				fail(scenario, "a press the cooldown refused was filed against "
					.. tostring(ns.pendingClick.name))
			end
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "Spell is not ready yet.")
			if ns.tried[key] ~= blocked then
				fail(scenario, ("the cooldown's refusal cut the block on a confirmed buff from"
					.. " %.1f seconds to %.1f"):format(blocked - GetTime(),
					(ns.tried[key] or GetTime()) - GetTime()))
			end
		end
	end
	Mock.inCombat = false
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 176b
-- In a fight, a press in the spell-queue window is filed.
--
-- The client does not refuse a /cast pressed in the last stretch of the global
-- cooldown: it holds it and casts it the moment the cooldown ends. Treating
-- that press as turned away -- which 176 rightly does for one made early --
-- dropped the bookkeeping for a buff that did land, so the person stayed owed
-- and was offered, and cast at, again. How long that stretch is comes from the
-- player's own setting when the client will say.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("in a fight, a press in the spell-queue window is filed")
if ns then
	local scenario = "in a fight, a press in the spell-queue window is filed"
	local realCVar = _G.GetCVar
	for _, case in ipairs({
		{ cvar = nil, wait = 1.2, filed = true, label = "the default window" },
		{ cvar = "100", wait = 1.2, filed = false, label = "a 100 ms window" },
		{ cvar = "100", wait = 1.45, filed = true, label = "a 100 ms window, late press" },
	}) do
		freshPrompt(ns, scenario)
		clearClicks(ns)
		_G.GetCVar = case.cvar and function(name)
			if name == "SpellQueueWindow" then return case.cvar end
		end or realCVar
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		-- Something cast by hand, so the press lands in its cooldown.
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-hand", 116)
		Mock.advance(case.wait)
		if ns.CastReady() then
			fail(scenario, "SKIPPED -- the cooldown had already ended (" .. case.label .. ")")
		else
			pressButton(ns)
			local filed = ns.pendingClick ~= nil
			if filed ~= case.filed then
				fail(scenario, (case.filed
					and "a press the client queues was treated as refused, so the buff"
						.. " that goes out is never counted (%s)"
					or "a press too early to be queued was filed against the person"
						.. " (%s)"):format(case.label))
			end
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		Mock.advance(3)
		ns.addon:Tick()
	end
	_G.GetCVar = realCVar
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 177
-- A press the cooldown turned away does not swallow the next one.
--
-- The guard disarmed the press and filed nothing -- right -- but both debounces
-- still took their stamps. The cooldown ends mid-click as often as not, and a
-- press a tenth of a second later was swallowed: it did nothing at all, or, if a
-- scan had re-armed the button in between, it cast with nothing recorded, so the
-- buff that went out was never counted and the person stayed owed, to be
-- offered, cast at and spoken to again.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("a press the cooldown turned away does not swallow the next one")
if ns then
	local scenario = "a press the cooldown turned away does not swallow the next one"
	freshPrompt(ns, scenario)
	for _, rescan in ipairs({ false, true }) do
		clearClicks(ns)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-hand", 116)
		Mock.advance(1.45)
		if pressButton(ns) then
			fail(scenario, "SKIPPED -- the guard let the first press through")
		else
			Mock.advance(0.06)
			if rescan then ns.addon:Tick() end
			Mock.advance(0.04)
			local label = rescan and " (a scan in between)" or ""
			if not ns.CastReady() then
				fail(scenario, "SKIPPED -- the cooldown had not ended" .. label)
			else
				local second = pressButton(ns)
				if not second then
					fail(scenario, "a press after the cooldown ended was swallowed by the"
						.. " one it turned away" .. label)
				elseif not ns.pendingClick then
					fail(scenario, "a press that cast was filed as nothing, so the buff that"
						.. " went out is never counted" .. label)
				end
			end
		end
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 178
-- A cast with a cast time holds the press the way the cooldown does.
--
-- The guard tracked the global cooldown from the moment a cast was sent, and a
-- cast with a cast time goes on after it. Conjuring is what a mage does out of
-- combat more than anything else, and from a second and a half into a
-- three-second conjure the guard called the press ready: it reached the client,
-- was refused, and the person offered was blamed, blocked and flashed red --
-- the failure the guard was written for.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("a cast with a cast time holds the press")
if ns then
	local scenario = "a cast with a cast time holds the press"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.casting = { spellId = 5504, startsAt = GetTime(), endsAt = GetTime() + 3 }
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-conjure", 5504)
	Mock.advance(2)
	local ready, left = ns.CastReady()
	if ready then
		fail(scenario, "half-way through a three-second cast, a press was called ready")
	elseif type(left) ~= "number" or left < 0.5 then
		fail(scenario, "the wait quoted is not the cast's: " .. tostring(left))
	end
	local ran = pressButton(ns)
	if ran then
		fail(scenario, "a macro stayed armed while a cast was in progress: " .. (ran:gsub("\n", " / ")))
	end
	if ns.pendingClick then
		fail(scenario, "a press that could not have cast was filed against "
			.. tostring(ns.pendingClick.name))
	end
	Mock.advance(1.1)
	if not ns.CastReady() then
		fail(scenario, "the cast is over and the press is still held")
	end
	Mock.casting = nil
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 179
-- An error answers a press once.
--
-- A refusal the client raises itself -- out of range -- rewinds the press, puts
-- the game's words on the panel, and leaves the record parked in case a cast
-- turns up behind it. When none did, the window running out treated the same
-- press as never answered: a second rewind written from that moment, so one
-- out-of-range press blocked the person for four seconds instead of two; a
-- second red flash saying "nothing was cast", over a button by then armed at
-- somebody else; and a chat line claiming the game had answered with nothing at
-- all. And that line said "is still owed" of whoever it was, owed or not.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
ns = load("an error answers a press once")
if ns then
	local scenario = "an error answers a press once"
	freshPrompt(ns, scenario)
	local flashes = 0
	local realShow = ns.Prompt.ShowOutcome
	ns.Prompt.ShowOutcome = function(self, kind, name, detail)
		if kind == "failed" and name == "Anna Aim" then flashes = flashes + 1 end
		return realShow(self, kind, name, detail)
	end
	for _, owedAnna in ipairs({ true, false }) do
		clearClicks(ns)
		flashes = 0
		if owedAnna then owe(ns, "Anna Aim") end
		ns.addon:Tick()
		local ran = pressButton(ns)
		local label = owedAnna and "" or " (Anna owed nothing)"
		if not (ran and ran:find("Anna Aim", 1, true)) then
			fail(scenario, "SKIPPED -- the press was not aimed at Anna" .. label)
		else
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
			for _ = 1, 6 do
				Mock.advance(0.4)
				ns.addon:Tick()
			end
			local said = table.concat(Mock.printed, "\n")
			if flashes ~= 1 then
				fail(scenario, ("one refused press flashed red %d times%s"):format(flashes, label))
			end
			if said:find("nothing at all", 1, true) then
				fail(scenario, "the chat said the game answered with nothing, after it said"
					.. " out of range" .. label .. ": " .. said)
			end
			if ns.IsBlocked("Anna Aim") then
				fail(scenario, "one refused press kept Anna off the prompt for more than the"
					.. " two seconds a refusal is worth" .. label)
			end
			if not owedAnna and said:find("Anna Aim is still owed", 1, true) then
				fail(scenario, "somebody who never buffed you was announced as still owed: " .. said)
			end
		end
	end
	ns.Prompt.ShowOutcome = realShow
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 180
-- A press goes to whoever the panel names.
--
-- PreClick re-resolves the queue, and the queue hands the panel to somebody
-- strictly better at once. That is right for the next repaint and wrong for a
-- press made on this one: somebody the player targeted a tenth of a second ago
-- was cast at, and spoken to, under a panel still naming somebody else. And a red
-- flash about a refused press sits over a button that refusal has already
-- re-armed at the next person, so pressing again to retry the one named in red
-- cast at, and spoke to, the other.
Mock.reset()
local seen = { nameplate1 = { "Anna", "Aim" } }
restoreUnits = strangers(seen)
ns = load("a press goes to whoever the panel names")
if ns then
	local scenario = "a press goes to whoever the panel names"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(0.1)
	seen.target = { "Bert", "Beside" }
	local top = ns.BuildQueue()[1]
	if not (top and top.name == "Bert Beside") then
		fail(scenario, "SKIPPED -- the target did not outrank the debt, so nothing is"
			.. " promoted over the panel")
	else
		local ran = pressButton(ns)
		if not (ran and ran:find("Anna Aim", 1, true)) then
			fail(scenario, "a press on a panel naming Anna ran: " .. tostring(ran and ran:gsub("\n", " / ")))
		end
	end
	seen.target = nil

	-- The flash.
	seen.nameplate2 = { "Bert", "Beside" }
	ns.nameplateUnits["nameplate2"] = true
	clearClicks(ns)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local first = pressButton(ns)
	ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
	Mock.advance(0.3)
	local named = tostring(ns.Prompt:Regions().name:GetText())
	if not (first and named:find("Anna Aim", 1, true)) then
		fail(scenario, "SKIPPED -- no red flash about Anna to press under: " .. named)
	else
		local retry = pressButton(ns)
		if retry then
			fail(scenario, "a press under a flash naming Anna ran: " .. (retry:gsub("\n", " / ")))
		end
		local said = table.concat(Mock.printed, "\n")
		if not said:find("Bert Beside", 1, true) then
			fail(scenario, "the press did nothing and nothing said who the prompt had moved on to")
		end
		if not tostring(ns.Prompt:Regions().name:GetText()):find("Bert Beside", 1, true) then
			fail(scenario, "the panel was not brought up to date with who the next press is for")
		end
		Mock.advance(0.3)
		local again = pressButton(ns)
		if not (again and again:find("Bert Beside", 1, true)) then
			fail(scenario, "the press after the panel moved on did not go to Bert: " .. tostring(again))
		end
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 181
-- A right-click skip holds against the next left press.
--
-- The skip blocked the person and left them named and armed on the panel until
-- the next scan -- and with the queue empty, the fuse that keeps a panel up for a
-- moment kept them there longer. The press path asked only whether the fuse was
-- burning, never whether the person under it had been retired, so a left press in
-- that time cast at, spoke to, and filed a press against somebody just declined.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Petra", "Stonewell" } })
ns = load("a right-click skip holds against the next left press")
if ns then
	local scenario = "a right-click skip holds against the next left press"
	freshPrompt(ns, scenario)
	local button = ns.Prompt:GetButton()
	for _, how in ipairs({ "right-click", "block" }) do
		clearClicks(ns)
		Mock.inRange = true
		ns.addon:Tick()
		Mock.inRange = false
		Mock.advance(0.1)
		ns.addon:Tick()
		if not (button:IsShown() and button:GetAttribute("macrotext1")) then
			fail(scenario, "SKIPPED -- the fuse did not keep Petra up (" .. how .. ")")
		else
			Mock.advance(0.1)
			if how == "right-click" then
				pressButton(ns, "RightButton")
				-- The skip moves the panel on at once, rather than leaving the
				-- declined person named until a scan gets round to it.
				if button:IsShown() then
					fail(scenario, "the panel still names somebody the right-click just skipped")
				end
			else
				-- The retired state without the skip's own repaint, which is the
				-- press path's own check on it.
				ns.BlockPerson("Petra Stonewell")
			end
			Mock.advance(0.1)
			local ran = pressButton(ns)
			if ran then
				fail(scenario, ("a left press after a %s cast at Petra: %s"):format(how, (ran:gsub("\n", " / "))))
			end
			if ns.pendingClick then
				fail(scenario, "a press was filed against somebody just skipped (" .. how .. ")")
			end
		end
	end
	Mock.inRange = true
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 182
-- The cooldown follows the longest lockout, not the latest report.
--
-- Each cast event set the block to its own figure. A second one inside a running
-- cooldown that reports a shorter figure -- a spell off the global cooldown,
-- with a shorter one of its own -- reopened the button under a cooldown that was
-- still running.
Mock.reset()
Mock.spellCooldowns = { [1459] = 1.5, [99999] = 0.5 }
ns = load("the cooldown follows the longest lockout")
if ns then
	local scenario = "the cooldown follows the longest lockout"
	drive(scenario, ns)
	Mock.advance(60)
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-a", 1459)
	Mock.advance(0.2)
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-b", 99999)
	Mock.advance(0.6)
	if ns.CastReady() then
		fail(scenario, "a shorter figure reported inside the cooldown reopened the button"
			.. " with seven tenths of a second of it still to run")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 183
-- The waiting line does not recolour the reason line for good.
--
-- "ready in 1.2s" was written in a lighter grey by setting the font string's
-- colour, and only ApplyStyle ever set it back -- the repaint sets text, not
-- colour -- so after one press inside the cooldown the reason line stayed in the
-- waiting grey for the rest of the session.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("the waiting line does not recolour the reason line")
if ns then
	local scenario = "the waiting line does not recolour the reason line"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	local sub = ns.Prompt:Regions().sub
	local styled = table.concat(sub._textColor or {}, ",")
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-hand", 116)
	Mock.advance(0.5)
	pressButton(ns)
	if not tostring(sub:GetText()):find("ready in", 1, true) then
		fail(scenario, "SKIPPED -- the press was not turned away: " .. tostring(sub:GetText()))
	else
		for _ = 1, 10 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
		local now = table.concat(sub._textColor or {}, ",")
		if styled == "" then
			fail(scenario, "SKIPPED -- nothing recorded the reason line's colour")
		elseif now ~= styled then
			fail(scenario, ("the reason line is still in the waiting colour %s, not its"
				.. " own %s"):format(now, styled))
		end
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 184
-- A press turned away just before a pull leaves the prompt armed for it.
--
-- The guard disarms the button so the secure handler finds nothing, and nothing
-- put it back until the next scan. A fight starting in between froze it empty:
-- the prompt sat there for the whole of the fight saying nothing was armed,
-- with somebody owed a favour standing next to it.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("a press turned away before a pull leaves the prompt armed")
if ns then
	local scenario = "a press turned away before a pull leaves the prompt armed"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-hand", 116)
	Mock.advance(0.5)
	if pressButton(ns) then
		fail(scenario, "SKIPPED -- the press was not turned away")
	else
		Mock.advance(0.1)
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		for _ = 1, 5 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
		local ran = pressButton(ns)
		if not (ran and ran:find("Anna Aim", 1, true)) then
			fail(scenario, "the fight froze the prompt with nothing armed, with Anna owed"
				.. " and standing beside it")
		end
		Mock.inCombat = false
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 185
-- A refusal read through the library is still a refusal.
--
-- The eight-yard edge LibRangeCheck hands a mage is the duel prompt, and the
-- library's checker for it is `CheckInteractDistance(...) and true or false`.
-- On a client that will not answer about a stranger, that turned "I will not
-- say" into "outside": everybody came back twenty-eight to forty yards away, a
-- person standing a yard off included, and "Nearby" offered nobody -- while the
-- page said the filter had answered for every one of them, so it was never
-- dropped. A value the client withheld is truthy, which flipped the same
-- flattening the other way: everybody inside eight yards, answered for all.
for _, mode in ipairs({ "restricted", "secret" }) do
	Mock.reset()
	Mock.rangeCheck = { buckets = { 30, 28, 8 } }
	Mock.setInteract(mode)
	Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
	Mock.yards = { nameplate1 = 1, nameplate2 = 20 }
	ns = load("a refusal read through the library is still a refusal")
	if ns then
		local scenario = "a refusal read through the library is still a refusal"
		drive(scenario, ns)
		settle(ns)
		ns.db.profile.filters.proximity = "near"
		local out = inQueue(ns)
		if not out["Close By"] then
			fail(scenario, ("dropped somebody a yard away because the client would not"
				.. " answer about a stranger (interact %s)"):format(mode))
		end
		if ns.proximity.answered > 0 then
			fail(scenario, ("counted %d answers from a client that answered nobody"
				.. " (interact %s)"):format(ns.proximity.answered, mode))
		end
		for _ = 1, 60 do ns.BuildQueue() end
		local said = tostring(ns.ProximitySummary())
		if not said:find("no signal", 1, true) then
			fail(scenario, ("a filter nothing answers for still reads as working"
				.. " (interact %s): %s"):format(mode, said))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 186
-- A rung that answers for some people hands the rest to the rung below.
--
-- A library whose estimate fails for half the square -- a secret GUID here, a
-- missing cache entry there -- answered "cannot tell" for them, and "cannot
-- tell" offered them outright, from thirty yards, while a working rung sat
-- underneath that could have measured them.
Mock.reset()
Mock.rangeCheck = { buckets = { 30, 28, 6 }, silentFor = { nameplate2 = true } }
Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
Mock.yards = { nameplate1 = 4, nameplate2 = 20 }
ns = load("a rung that cannot tell hands the person down")
if ns then
	local scenario = "a rung that cannot tell hands the person down"
	drive(scenario, ns)
	settle(ns)
	ns.db.profile.filters.proximity = "near"
	local out = inQueue(ns)
	if ns.proximity.source ~= "LibRangeCheck-3.0" then
		fail(scenario, "SKIPPED -- the library was not the rung in use: "
			.. tostring(ns.proximity.source))
	else
		if not out["Close By"] then
			fail(scenario, "dropped somebody four yards away the library measured")
		end
		if out["Far Away"] then
			fail(scenario, "somebody the library could not measure was offered from"
				.. " twenty yards, with the duel prompt there to ask")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 187
-- "Right beside me" is never looser than "Nearby".
--
-- The duel prompt is the only fixed distance a client with no library has, and
-- it declined the five-yard step outright, since it cannot say anybody is
-- inside five yards. So the tightest step on the page had no signal at all and
-- offered everybody in casting range -- twice as many as the step above it. It
-- can still say who is past eight yards, and anybody past eight is past five.
Mock.reset()
Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
Mock.yards = { nameplate1 = 4, nameplate2 = 20 }
ns = load("right beside me is never looser than nearby")
if ns then
	local scenario = "right beside me is never looser than nearby"
	drive(scenario, ns)
	settle(ns)
	ns.db.profile.filters.proximity = "near"
	local near = inQueue(ns)
	ns.db.profile.filters.proximity = "beside"
	local beside = inQueue(ns)
	if near["Far Away"] or not near["Close By"] then
		fail(scenario, "SKIPPED -- \"nearby\" did not separate the two, so there is no"
			.. " step above to compare with")
	else
		if beside["Far Away"] then
			fail(scenario, "\"right beside me\" offered somebody twenty yards away that"
				.. " \"nearby\" drops")
		end
		local said = tostring(ns.ProximitySummary())
		if not said:find("only rules out", 1, true) then
			fail(scenario, "the step is measured by a coarser signal and the"
				.. " diagnostic does not say so: " .. said)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 188
-- The line under the dropdown describes the step that is selected.
--
-- It described whatever the last scan left behind, and the page redraws itself
-- straight after the dropdown's setter, before any scan. Choosing "Nearby" after
-- "Anywhere I can cast" read "no signal, so everybody in casting range is
-- offered" over a working duel prompt; choosing "Right beside me" put the
-- previous step's rung and its counts under the new step's name. With passers-by
-- switched off it claimed, in red, that everybody was offered. And looking at one
-- person by hand was counted into the last scan.
Mock.reset()
Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
Mock.yards = { nameplate1 = 4, nameplate2 = 20 }
ns = load("the line under the dropdown describes the step that is selected")
if ns then
	local scenario = "the line under the dropdown describes the step that is selected"
	drive(scenario, ns)
	settle(ns)
	local who = ns.optionsTable and ns.optionsTable.args.who
	local control = who and who.args.proximity
	local note = who and who.args.proximityNote
	if not (control and control.set and note and type(note.name) == "function") then
		fail(scenario, "SKIPPED -- no proximity dropdown and note to read")
	else
		ns.db.profile.filters.proximity = "cast"
		for _ = 1, 3 do inQueue(ns) end
		control.set({ "proximity" }, "near")
		local said = tostring(note.name())
		if said:find("no signal", 1, true) or not said:find("CheckInteractDistance", 1, true) then
			fail(scenario, "picking Nearby, the page described a step that is not"
				.. " selected: " .. said)
		end

		inQueue(ns)
		control.set({ "proximity" }, "beside")
		said = tostring(note.name())
		if said:find("really 8yd", 1, true) or said:find("answered for", 1, true) then
			fail(scenario, "picking Right beside me, the page kept the previous step's"
				.. " measurement: " .. said)
		end

		inQueue(ns)
		local asked = ns.proximity.asked
		ns.addon:HandleSlash("look nameplate1")
		if ns.proximity.asked ~= asked then
			fail(scenario, ("looking at one person by hand made the last scan %d people"
				.. " instead of %d"):format(ns.proximity.asked, asked))
		end

		-- Nobody is measured with passers-by off, and the line has to say that
		-- rather than go on describing a filter that is not being consulted --
		-- or, before any scan, claim in red that everybody is offered.
		ns.db.profile.sources.strangers = false
		said = tostring(ns.ProximitySummary())
		if said:find("everybody in casting range is offered", 1, true)
			or not said:find("passers-by are switched off", 1, true) then
			fail(scenario, "with passers-by switched off, the line does not say so: " .. said)
		end
		ns.db.profile.sources.strangers = true
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 189
-- One client call, one distance.
--
-- The duel prompt was reported as ten yards when it was asked directly and as
-- eight when LibRangeCheck asked it -- the library's own measurement, and the
-- only one in the tree. The same call cannot be both, and the "really" in the
-- diagnostic is a promise about which.
Mock.reset()
Mock.unitNames = { nameplate1 = { "Close", "By" } }
ns = load("one client call, one distance")
if ns then
	local scenario = "one client call, one distance"
	drive(scenario, ns)
	settle(ns)
	ns.db.profile.filters.proximity = "near"
	inQueue(ns)
	local direct = ns.proximity.yards
	Mock.rangeCheck = { buckets = { 30, 28, 8 } }
	ns.Guard("probe", ns.ProbeCapabilities)
	inQueue(ns)
	local viaLibrary = ns.proximity.yards
	if ns.proximity.source ~= "LibRangeCheck-3.0" then
		fail(scenario, "SKIPPED -- the library was not picked up")
	elseif direct ~= viaLibrary then
		fail(scenario, ("the duel prompt is %s yards asked directly and %s through the"
			.. " library"):format(tostring(direct), tostring(viaLibrary)))
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 190
-- A prompt placed under 0.9.x comes back where it was left.
--
-- 0.9.x anchored the prompt to the middle of the screen; beta.1 moved the
-- default to the bottom edge. AceDB strips a value equal to its default when it
-- saves, so a 0.9.x prompt dragged somewhere whose nearest anchor was the middle
-- had its two offsets on disk and nothing else -- and those offsets were then
-- read against the bottom edge. Dropped below the middle of the screen, it came
-- back below the bottom of it, clamped over the action bars, with the position
-- dropdown blank.
Mock.reset()
Mock.sv = {}
ns = load("a prompt placed under 0.9.x comes back where it was left")
if ns then
	local scenario = "a prompt placed under 0.9.x comes back where it was left"
	drive(scenario, ns)
	-- What AceDB hands back for that file: the new default anchor, the old
	-- offsets, and no stamp, since nothing written before this had one.
	local p = ns.db.profile.prompt
	p.point, p.relPoint, p.x, p.y = "BOTTOM", "BOTTOM", 37, -61
	p.anchorCarried = nil
	ns.ClampSettings()
	if p.point ~= "CENTER" or p.relPoint ~= "CENTER" or p.x ~= 37 or p.y ~= -61 then
		fail(scenario, ("a 0.9.x prompt came back at %s/%s %s,%s, below the bottom of"
			.. " the screen"):format(tostring(p.point), tostring(p.relPoint),
			tostring(p.x), tostring(p.y)))
	end

	-- Once. A bottom anchor with a negative offset typed in afterwards, on the
	-- sliders, is a choice somebody made.
	p.point, p.relPoint, p.y = "BOTTOM", "BOTTOM", -20
	ns.ClampSettings()
	if p.point ~= "BOTTOM" then
		fail(scenario, "the carry-over ran again on a profile it had already moved")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 191
-- A profile switch puts the launcher's text back.
--
-- The launcher says "Manners off" when the addon is off, and that text was only
-- ever put back by the fight ending, the minimap click or /manners on|off. A
-- switch, copy or reset changes the on switch with everything else, and the
-- launcher went on saying the old state -- off over a profile that was on.
Mock.reset()
ns = load("a profile switch puts the launcher's text back")
if ns then
	local scenario = "a profile switch puts the launcher's text back"
	drive(scenario, ns)
	ns.addon:HandleSlash("off")
	local off = Mock.broker and Mock.broker.text
	if not (off and off:find("off", 1, true)) then
		fail(scenario, "SKIPPED -- the launcher never said it was off: " .. tostring(off))
	else
		-- What a switch to a profile that is on leaves behind, and the
		-- callback AceDB fires for it.
		ns.db.profile.enabled = true
		ns.addon:RefreshConfig()
		if Mock.broker.text ~= "Manners" then
			fail(scenario, "switched to a profile that is on, and the launcher still says: "
				.. tostring(Mock.broker.text))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 192
-- The macro 0.9.x made is brought up to date on login.
--
-- 0.9.x's /manners macro wrote "/click MannersPrompt", which is an up click, and
-- the button only acts on the way down. It is already on somebody's bar, and
-- only running /manners macro again ever rewrote it -- so an upgrade left a key
-- that pressed nothing, with nothing anywhere to say why. A macro somebody has
-- edited since is theirs, and is left exactly as it is.
Mock.reset()
local macros = {}
local realIndex, realBody, realEdit = GetMacroIndexByName, GetMacroBody, EditMacro
GetMacroIndexByName = function(name)
	for i, m in ipairs(macros) do if m.name == name then return i end end
	return 0
end
GetMacroBody = function(i) return macros[i] and macros[i].body end
EditMacro = function(i, name, _, body)
	if macros[i] then
		if name then macros[i].name = name end
		if body then macros[i].body = body end
	end
	return i
end
for _, case in ipairs({
	{ body = "/click MannersPrompt", fixed = true },
	{ body = "/click MannersPrompt\n/say hello", fixed = false },
}) do
	macros[1] = { name = "Manners", body = case.body }
	ns = load("the macro 0.9.x made is brought up to date")
	if ns then
		local scenario = "the macro 0.9.x made is brought up to date"
		ns.addon:OnInitialize()
		ns.addon:OnEnable()
		Mock.runTimers(3)
		local now = macros[1].body
		if case.fixed and now == case.body then
			fail(scenario, "a login left the old up-click macro on the bar: " .. now)
		elseif not case.fixed and now ~= case.body then
			fail(scenario, "rewrote a macro somebody had edited: " .. (now:gsub("\n", " / ")))
		end
	end
	Mock.reset()
end
GetMacroIndexByName, GetMacroBody, EditMacro = realIndex, realBody, realEdit

-- ------------------------------------------------------------------ 193
-- The wording boxes keep what they were given.
--
-- The options page accepted an empty line for the session, and the repair at
-- load put the default back at the next login. For the first line that meant a
-- prompt naming nobody for the rest of the session; for a reason line it was a
-- reasonable wish -- no second line for passers-by -- granted and then quietly
-- taken back. And one wording was rewritten on every login and every nudge of
-- the height slider: "needs {buff}" in the group box, by a carry-over for a
-- profile no version ever wrote.
Mock.reset()
Mock.sv = {}
ns = load("the wording boxes keep what they were given")
if ns then
	local scenario = "the wording boxes keep what they were given"
	drive(scenario, ns)
	local app = ns.optionsTable and ns.optionsTable.args.appearance.args
	if not (app and app.format and app.reasonNearby and app.reasonGroup and app.height) then
		fail(scenario, "SKIPPED -- the wording boxes are not on the page")
	else
		app.format.set({ "format" }, "")
		if not ns.UsableFormat(ns.db.profile.prompt.format) then
			fail(scenario, "the first line was left empty, so the prompt names nobody")
		end
		app.reasonNearby.set({ "reasonNearby" }, "")
		app.reasonGroup.set({ "reasonGroup" }, "needs {buff}")
		app.height.set({ "height" }, 46)
		if ns.db.profile.prompt.reasonGroup ~= "needs {buff}" then
			fail(scenario, "moving the height slider rewrote the group wording to "
				.. tostring(ns.db.profile.prompt.reasonGroup))
		end

		-- /reload: the same saved file, a fresh namespace.
		local again = load("the wording boxes keep what they were given")
		if again then
			again.addon:OnInitialize()
			local p = again.db.profile.prompt
			if p.reasonNearby ~= "" then
				fail(scenario, "an emptied reason line came back after a reload as "
					.. tostring(p.reasonNearby))
			end
			if p.reasonGroup ~= "needs {buff}" then
				fail(scenario, "a wording somebody typed came back after a reload as "
					.. tostring(p.reasonGroup))
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 194
-- The font list names fonts.
--
-- LibSharedMedia's table maps a font's name to its file, and AceConfig labels
-- each entry with the value -- so the list read "Fonts\FRIZQT__.TTF", sorted by
-- path, with the current choice displayed as a file. The sound list beside it
-- had the same bug fixed, and the fix never reached this one. The mock's own
-- font table maps "font.ttf" to "font.ttf", which is why nothing saw it.
Mock.reset()
ns = load("the font list names fonts")
if ns then
	local scenario = "the font list names fonts"
	drive(scenario, ns)
	local LSM = LibStub("LibSharedMedia-3.0")
	LSM:Register("font", "Friz Quadrata TT", [[Fonts\FRIZQT__.TTF]])
	LSM:Register("font", "Arial Narrow", [[Fonts\ARIALN.TTF]])
	local control = ns.optionsTable and ns.optionsTable.args.appearance.args.font
	if not (control and control.values) then
		fail(scenario, "SKIPPED -- no font dropdown to read")
	else
		local values = type(control.values) == "function" and control.values() or control.values
		for _, name in ipairs({ "Friz Quadrata TT", "Arial Narrow" }) do
			if values[name] ~= name then
				fail(scenario, ("the font %s is listed as %s"):format(name, tostring(values[name])))
			end
		end
	end
	LSM.media.font["Friz Quadrata TT"], LSM.media.font["Arial Narrow"] = nil, nil
end
Mock.reset()

-- ------------------------------------------------------------------ 195
-- The size controls say what the prompt really does with them.
--
-- "Show a second line" said it needed a prompt 34 pixels tall; the prompt had
-- stopped using 34 and needs 39 at the default font, so from 34 to 38 the page
-- said there was room and the line was missing. And the width slider never
-- applied the bound the icon has on the width: narrowing the prompt left a big
-- icon in place, with the name's insets crossed and nowhere to draw -- while
-- the notice about the icon being held knew only about the height, so it named
-- the wrong dimension or stayed hidden.
Mock.reset()
ns = load("the size controls say what the prompt really does")
if ns then
	local scenario = "the size controls say what the prompt really does"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local app = ns.optionsTable and ns.optionsTable.args.appearance.args
	local p = ns.db.profile.prompt
	if not (app and app.showSub and app.height and app.width and app.iconSize and app.iconSizeCapped) then
		fail(scenario, "SKIPPED -- the size controls are not on the page")
	else
		p.showSub = true
		local desc = type(app.showSub.desc) == "function" and app.showSub.desc() or app.showSub.desc
		local promised = tonumber(tostring(desc):match("(%d+) pixels"))
		if not promised then
			fail(scenario, "the second-line control names no height: " .. tostring(desc))
		else
			app.height.set({ "height" }, promised)
			if not ns.Prompt:Regions().sub:IsShown() then
				fail(scenario, ("the page promises a second line at %d pixels and there is"
					.. " none"):format(promised))
			end
			app.height.set({ "height" }, promised - 1)
			if ns.Prompt:Regions().sub:IsShown() then
				fail(scenario, ("the page says %d pixels and the line fits in %d, so the"
					.. " figure is not the one the prompt uses"):format(promised, promised - 1))
			end
		end
		app.height.set({ "height" }, 44)

		p.iconSize = 36
		app.width.set({ "width" }, 80)
		if p.iconSize > ns.IconCeiling(p) then
			fail(scenario, ("narrowing the prompt to 80 left a %d icon in it"):format(p.iconSize))
		end
		app.iconSize.set({ "iconSize" }, 40)
		local notice = tostring(app.iconSizeCapped.name())
		if app.iconSizeCapped.hidden() then
			fail(scenario, "the icon is held by the width and the page says nothing")
		elseif not notice:find("wide", 1, true) then
			fail(scenario, "the icon is held by the width and the page blames the height: " .. notice)
		end
		app.width.set({ "width" }, 220)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 196
-- "When someone buffs you" works with the icon hidden.
--
-- The flash has two halves: a glow round the icon, and a sweep down the stripe.
-- It gave up the moment the icon was hidden, before the sweep, so with the
-- reason colour on the stripe and no icon both flash styles did nothing at all
-- -- and the control stayed on the page, enabled, saying nothing.
Mock.reset()
ns = load("the flash works with the icon hidden")
if ns then
	local scenario = "the flash works with the icon hidden"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local r = ns.Prompt:Regions()
	if not (r.sweep and r.sweep.anim and r.glow) then
		fail(scenario, "SKIPPED -- the flash's frames are not reachable")
	else
		local played = {}
		local realPlay = r.sweep.anim.Play
		r.sweep.anim.Play = function(self) played.sweep = true return self end
		local p = ns.db.profile.prompt
		p.accentMode, p.showIcon, p.flashStyle = "stripe", false, "once"
		ns.Prompt:ApplyStyle()
		ns.Prompt:StartAttention(true)
		if not played.sweep then
			fail(scenario, "with the icon hidden and the colour on the stripe, a new favour"
				.. " played nothing")
		end
		r.sweep.anim.Play = realPlay

		local control = ns.optionsTable and ns.optionsTable.args.appearance.args.flashStyle
		if control and control.disabled then
			if control.disabled() then
				fail(scenario, "the flash control is disabled while the stripe can show it")
			end
			-- With the icon hidden and the colour on the ring, the only thing
			-- left for the setting to move is the light the panel catches on
			-- arrival -- which Effects on Full draws and Calm does not.
			p.accentMode = "icon"
			if control.disabled() then
				fail(scenario, "with Effects on Full the panel still catches the light on"
					.. " arrival, and the flash control was greyed out anyway")
			end
			p.effects = "calm"
			if not control.disabled() then
				fail(scenario, "with no icon and no stripe there is nothing to flash, and the"
					.. " control is still offered")
			end
			p.effects = "full"
		else
			fail(scenario, "the flash control never says when it has nothing to act on")
		end
		p.accentMode, p.showIcon, p.flashStyle = "icon", true, "pulse"
		ns.Prompt:ApplyStyle()
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 197
-- The options page keeps up with what is happening.
--
-- Four places it did not. Diagnostics gave the ring's length as the session's
-- failure count -- thirty whether thirty things had broken or thirty thousand
-- -- and went on reading "Nothing has broken" over a failure that had just
-- happened, because nothing caught by the guard ever asked the page to redraw.
-- Dropping the prompt after a drag locked it and left the Locked box unticked.
-- And the icon slider asked for a redraw on every tick of a drag, which rebuilds
-- the slider under the finger holding it.
Mock.reset()
ns = load("the options page keeps up with what is happening")
if ns then
	local scenario = "the options page keeps up with what is happening"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local diag = ns.optionsTable and ns.optionsTable.args.diagnostics.args
	local app = ns.optionsTable and ns.optionsTable.args.appearance.args

	Mock.optionsRepaints = 0
	ns.Guard("a label nothing has used", function() error("boom", 0) end)
	if Mock.optionsRepaints == 0 then
		fail(scenario, "something broke and the page was never asked to show it")
	end
	for _ = 1, 44 do ns.Guard("a label nothing has used", function() error("boom", 0) end) end
	local said = diag and tostring(diag.errorList.name()) or ""
	if not said:find("45 in all", 1, true) then
		fail(scenario, "forty-five failures, and the page gives the count as: "
			.. (said:match("%(.-%-%-") or said))
	end

	Mock.optionsOpen = true
	app.locked.set({ "locked" }, false)
	local button = ns.Prompt:GetButton()
	Mock.optionsRepaints = 0
	button.scripts.OnDragStart(button)
	button.scripts.OnDragStop(button)
	if Mock.optionsRepaints == 0 then
		fail(scenario, "a drop locked the prompt and the page still shows it unlocked")
	end
	Mock.optionsOpen = false

	Mock.optionsRepaints = 0
	for size = 20, 24 do app.iconSize.set({ "iconSize" }, size) end
	if Mock.optionsRepaints > 0 then
		fail(scenario, ("five ticks of the icon slider asked for %d redraws, each one"
			.. " rebuilding the slider being dragged"):format(Mock.optionsRepaints))
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 198
-- "Load a set" can load the set it is showing.
--
-- The dropdown showed the last set loaded even after the box under it had been
-- edited, and AceGUI's dropdown only fires when the item clicked becomes checked
-- -- clicking the checked one just re-checks it. So somebody who had edited the
-- Roleplay lines and wanted them back picked Roleplay and got nothing: no
-- question, no reload. Blank once the box has been edited, any set can be
-- picked.
Mock.reset()
ns = load("load a set can load the set it is showing")
if ns then
	local scenario = "load a set can load the set it is showing"
	drive(scenario, ns)
	local click = ns.optionsTable and ns.optionsTable.args.click.args
	if not (click and click.preset and click.phrases) then
		fail(scenario, "SKIPPED -- the phrase controls are not on the page")
	else
		ns.db.profile.speech.enabled = true
		if click.preset.get({ "preset" }) ~= "roleplay" then
			fail(scenario, "the untouched box does not read as the set it holds: "
				.. tostring(click.preset.get({ "preset" })))
		end
		click.phrases.set({ "phrases" }, "Hi {name}!")
		if click.preset.get({ "preset" }) ~= nil then
			fail(scenario, "after editing the lines, the dropdown still shows "
				.. tostring(click.preset.get({ "preset" })) .. ", which cannot then be picked")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 199
-- The greeting does not promise a panel the profile will not show.
--
-- It counted the queue to decide whether the prompt already had somebody real
-- on it, and the queue knows nothing about the switch or the lock. An alt
-- logging into a shared profile that had been switched off, in a city, was told
-- "no prompt will appear" and then "the prompt is on screen now, with somebody
-- real on it" -- over a hidden button. Unlocked, the panel said "Drag to move".
for _, how in ipairs({ "switched off", "unlocked" }) do
	Mock.reset()
	Mock.sv = {}
	Mock.unitNames = { nameplate1 = { "Close", "By" } }
	ns = load("the greeting does not promise a panel the profile will not show")
	if ns then
		local scenario = "the greeting does not promise a panel the profile will not show"
		drive(scenario, ns)
		settle(ns)
		ns.Prompt:ExitTest()
		if #ns.BuildQueue() == 0 then
			fail(scenario, "SKIPPED -- nobody real around, so there is nothing to mistake")
		else
			if how == "switched off" then
				ns.db.profile.enabled = false
			else
				ns.db.profile.prompt.locked = false
			end
			ns.addon:Tick()
			Mock.printed = {}
			ns.Welcome(true)
			local said = table.concat(Mock.printed, "\n")
			if said:find("somebody real on it", 1, true) then
				fail(scenario, ("on a profile that is %s the greeting says somebody real is on"
					.. " the prompt: %s"):format(how, said))
			end
			ns.Prompt:ExitTest()
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 200
-- A class whose buffs only reach its group is not promised strangers.
--
-- The greeting told every class with buffs that strangers nearby missing one of
-- theirs go on the prompt. A warrior's Battle Shout reaches the party and
-- nobody else: the queue turns every stranger down on its first line, and the
-- options page, in the same session, hides the passer-by switch and says there
-- is nothing to give one. And a stranger who buffs that warrior was announced as
-- "on the prompt" when the prompt could not offer them anything.
Mock.reset()
Mock.sv = {}
Mock.class = "WARRIOR"
local realKnown200, realPlayer200 = IsSpellKnown, IsPlayerSpell
IsSpellKnown = function() return true end
IsPlayerSpell = IsSpellKnown
ns = load("a class whose buffs reach its group only is not promised strangers")
if ns then
	local scenario = "a class whose buffs reach its group only is not promised strangers"
	local said = firstLogin(ns) or ""
	if not said:find("Battle Shout", 1, true) then
		fail(scenario, "SKIPPED -- the warrior has no shout to greet with: " .. said)
	elseif said:find("stranger", 1, true) then
		fail(scenario, "told a warrior their shout reaches strangers: " .. said)
	end
	ns.Prompt:ExitTest()

	-- A stranger buffs the warrior. The debt is kept -- they may join the group
	-- -- but the line does not say it is on the prompt.
	Mock.advance(10)
	for _ = 1, 3 do
		ns.ScanOwnBuffs()
		Mock.runTimers(0.3)
	end
	Mock.printed = {}
	Mock.extraAura = 4001
	Mock.extraAuraSpell = 10938
	ns.addon:UNIT_AURA(nil, "player")
	local line = table.concat(Mock.printed, "\n")
	if not line:find("buffed you", 1, true) then
		fail(scenario, "SKIPPED -- no favour was noticed: " .. line)
	elseif line:find("on the prompt", 1, true) then
		fail(scenario, "a stranger who buffed a solo warrior was announced as on the prompt: " .. line)
	end
end
IsSpellKnown, IsPlayerSpell = realKnown200, realPlayer200
Mock.reset()

-- ------------------------------------------------------------------ 201
-- A class that can cast nothing records no favour.
--
-- A rogue has no buff to give, and neither has a character that has not learned
-- one yet. A favour noticed for either was written to the saved variables and
-- announced as "on the prompt", for a prompt that will never offer anybody
-- anything -- the lie a switched-off addon had already been stopped telling.
Mock.reset()
Mock.class = "ROGUE"
ns = load("a class that can cast nothing records no favour")
if ns then
	local scenario = "a class that can cast nothing records no favour"
	drive(scenario, ns)
	Mock.advance(10)
	for _ = 1, 3 do
		ns.ScanOwnBuffs()
		Mock.runTimers(0.3)
	end
	Mock.printed = {}
	Mock.extraAura = 4001
	Mock.extraAuraSpell = 10938
	ns.addon:UNIT_AURA(nil, "player")
	local said = table.concat(Mock.printed, "\n")
	if next(ns.owed) then
		fail(scenario, "a rogue recorded a favour nothing can ever repay: " .. tostring(next(ns.owed)))
	end
	if said:find("on the prompt", 1, true) then
		fail(scenario, "a rogue was told returning a favour is on the prompt: " .. said)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 202
-- The login line for a class with nothing to cast says so.
--
-- "Ready to cast nothing -- no buff learned", on every login, to a rogue --
-- which suggests there is one to learn. The greeting and /manners debug both
-- give this character the one honest sentence, and this line was a third,
-- different one.
Mock.reset()
Mock.sv = {}
Mock.class = "ROGUE"
ns = load("the login line for a class with nothing to cast")
if ns then
	local scenario = "the login line for a class with nothing to cast"
	local said = firstLogin(ns) or ""
	if said:find("no buff learned", 1, true) then
		fail(scenario, "a rogue is told there is a buff to learn: " .. said)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 203
-- /manners test does not announce a preview it just took down.
--
-- With somebody real on the prompt, the refresh inside the command stands the
-- mock-up aside at once and says so -- and the command then printed "preview on
-- ... /manners test to stop" underneath, about a preview that was not running.
-- Typed again to stop it, it did the same thing again.
Mock.reset()
Mock.unitNames = { nameplate1 = { "Close", "By" } }
ns = load("/manners test does not announce a preview it took down")
if ns then
	local scenario = "/manners test does not announce a preview it took down"
	drive(scenario, ns)
	settle(ns)
	ns.Prompt:ExitTest()
	ns.addon:Tick()
	if #ns.BuildQueue() == 0 then
		fail(scenario, "SKIPPED -- nobody real on the prompt")
	else
		Mock.printed = {}
		ns.addon:HandleSlash("test")
		local said = table.concat(Mock.printed, "\n")
		if not ns.Prompt:InTest() and said:find("preview on", 1, true) then
			fail(scenario, "announced a preview that was not running: " .. said)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 204
-- A spell learned in a burst is not missed.
--
-- The capability probe is rate-limited, and a SPELLS_CHANGED inside the limit
-- was dropped with nothing coming back for it. Buying spells at a trainer one
-- after another is exactly such a burst, and a buff learned second stayed
-- unknown -- never offered, greyed out on the options page -- until some
-- unrelated event or a loading screen.
Mock.reset()
Mock.class = "PRIEST"
local known204 = { [1243] = true }
local realKnown204, realPlayer204 = IsSpellKnown, IsPlayerSpell
IsSpellKnown = function(id) return known204[id] == true end
IsPlayerSpell = IsSpellKnown
ns = load("a spell learned in a burst is not missed")
if ns then
	local scenario = "a spell learned in a burst is not missed"
	drive(scenario, ns)
	Mock.advance(10)
	known204[1244] = true
	ns.addon:SPELLS_CHANGED()
	Mock.advance(1)
	known204[976] = true
	ns.addon:SPELLS_CHANGED()
	Mock.runTimers(10)
	local shadow = ns.caps.buffs.shadow
	if not (shadow and shadow.known) then
		fail(scenario, "Shadow Protection, learned a second after Fortitude, is still"
			.. " unknown ten seconds later")
	end
end
IsSpellKnown, IsPlayerSpell = realKnown204, realPlayer204
Mock.reset()

-- ------------------------------------------------------------------ 205
-- A monk who buffed you is not judged manaless once their nameplate goes.
--
-- The tokenless fallback has only the class to go on, and the list of classes
-- with a mana bar was the vanilla seven. A Mists monk was offered Arcane
-- Brilliance while the nameplate let the client answer, and dropped for it the
-- moment it could not.
Mock.reset()
Mock.setFlavour("mists")
ns = load("a monk who buffed you keeps their mana")
if ns then
	local scenario = "a monk who buffed you keeps their mana"
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.owed["Lin"] = { expires = GetTime() + 100, at = GetTime(), class = "MONK" }
	local real = UnitExists
	UnitExists = function(unit) return unit == "player" end
	local offered
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == "Lin" then offered = entry end
	end
	UnitExists = real
	if not offered then
		fail(scenario, "a monk who buffed you was dropped as manaless the moment their"
			.. " nameplate went")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 206
-- The range library is found through a LibStub shaped like the game's.
--
-- LibStub is a table made callable by a metatable, not a function, and the
-- library was fetched through a helper that refuses anything that is not a
-- function. So in the game the library rung was never built: "Nearby" cut at
-- the eight-yard duel prompt instead of the library's ten-yard edge, dropping
-- somebody nine yards away, and "Right beside me" could only rule people out
-- past eight, so it kept somebody seven yards away that the library's five-yard
-- edge would have dropped. Every scenario passed, because the mock LibStub was
-- a plain function.
Mock.reset()
Mock.rangeCheck = { buckets = { 30, 28, 10, 5, 2 } }
Mock.unitNames = { nameplate1 = { "Seven", "Yards" }, nameplate2 = { "Nine", "Yards" } }
Mock.yards = { nameplate1 = 7, nameplate2 = 9 }
ns = load("the range library is found through a LibStub shaped like the game's")
if ns then
	local scenario = "the range library is found through a LibStub shaped like the game's"
	drive(scenario, ns)
	settle(ns)
	if type(LibStub) ~= "table" or type(LibStub.GetLibrary) ~= "function" then
		fail(scenario, "SKIPPED -- the mock LibStub is a " .. type(LibStub)
			.. ", not the callable table the game has")
	else
		ns.db.profile.filters.proximity = "near"
		ns.Guard("probe", ns.ProbeCapabilities)
		local near = inQueue(ns)
		local nearSource, nearYards = ns.proximity.source, ns.proximity.yards

		ns.db.profile.filters.proximity = "beside"
		ns.Guard("probe", ns.ProbeCapabilities)
		local beside = inQueue(ns)
		local besideSource, besideYards = ns.proximity.source, ns.proximity.yards

		if nearSource ~= "LibRangeCheck-3.0" or besideSource ~= "LibRangeCheck-3.0" then
			fail(scenario, ("the library was loaded and never used: Nearby measured with"
				.. " %s at %s yards, Right beside me with %s at %s yards"):format(
				tostring(nearSource), tostring(nearYards),
				tostring(besideSource), tostring(besideYards)))
		end
		if not near["Nine Yards"] then
			fail(scenario, "\"Nearby\" dropped somebody nine yards away, inside the"
				.. " library's ten-yard edge")
		end
		if beside["Seven Yards"] then
			fail(scenario, "\"Right beside me\" kept somebody seven yards away, outside"
				.. " the library's five-yard edge")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 207
-- The duel prompt's distance follows the player's race.
--
-- It is six yards for a tauren and seven for the undead, by the same library
-- measurement that says eight for everybody else. The prompt rung reported a
-- flat eight, so for a tauren one client call was "really 6yd" through the
-- library and "really 8yd" asked directly, and "Nearby" dropped somebody seven
-- yards away while saying it filtered at eight. "Right beside me" likewise
-- claimed to rule out only people past eight.
for _, case in ipairs({
	{ race = "Human", yards = 8, follow = 28 },
	{ race = "Tauren", yards = 6, follow = 25 },
	{ race = "Scourge", yards = 7, follow = 27 },
}) do
	Mock.reset()
	Mock.playerRace = case.race
	Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "In", "Between" } }
	Mock.yards = { nameplate1 = 4, nameplate2 = 7.5 }
	local scenario = "the duel prompt's distance follows the player's race ("
		.. case.race .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		settle(ns)

		ns.db.profile.filters.proximity = "beside"
		ns.Guard("probe", ns.ProbeCapabilities)
		inQueue(ns)
		local besideSaid = tostring(ns.ProximitySummary())

		ns.db.profile.filters.proximity = "near"
		ns.Guard("probe", ns.ProbeCapabilities)
		inQueue(ns)
		local direct = ns.proximity.yards
		local nearSaid = tostring(ns.ProximitySummary())

		Mock.rangeCheck = { buckets = { 30, case.follow, case.yards } }
		ns.Guard("probe", ns.ProbeCapabilities)
		inQueue(ns)
		local viaLibrary = ns.proximity.yards

		if direct ~= case.yards then
			fail(scenario, ("the duel prompt was reported at %s yards asked directly, and"
				.. " it is %d for this race"):format(tostring(direct), case.yards))
		end
		if ns.proximity.source ~= "LibRangeCheck-3.0" then
			fail(scenario, "SKIPPED -- the library was not picked up")
		elseif direct ~= viaLibrary then
			fail(scenario, ("one client call, %s yards asked directly and %s through the"
				.. " library"):format(tostring(direct), tostring(viaLibrary)))
		end
		if not nearSaid:find(("really %dyd"):format(case.yards), 1, true) then
			fail(scenario, "Nearby does not name this race's distance: " .. nearSaid)
		end
		if not besideSaid:find(("past %dyd"):format(case.yards), 1, true) then
			fail(scenario, "Right beside me does not name this race's distance: "
				.. besideSaid)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 208
-- A warrior is not told that strangers are measured or offered.
--
-- Battle Shout reaches the party and nobody else, so a warrior never offers a
-- passer-by. But the scan still put every stranger to the distance check before
-- the shout was turned down, which fed the counts and, on a client whose duel
-- prompt says nothing about strangers, dropped that rung after forty silences.
-- The summary then told the warrior in red that everybody in casting range was
-- offered, or that the check "answered for" strangers who can never be offered
-- anything. The beta.4 notes promised warriors would no longer be told that.
for _, mode in ipairs({ "restricted", "on" }) do
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.groupSize = 0
	Mock.setInteract(mode)
	Mock.unitNames = { nameplate1 = { "Close", "By" }, nameplate2 = { "Far", "Away" } }
	Mock.yards = { nameplate1 = 4, nameplate2 = 20 }
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "a warrior is not told that strangers are measured (interact "
		.. mode .. ")"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		drive(scenario, ns)
		settle(ns)
		ns.db.profile.filters.proximity = "near"
		for _ = 1, 60 do ns.BuildQueue() end
		if ns.proximity.asked ~= 0 or ns.proximity.note then
			fail(scenario, ("strangers a warrior can never offer were measured: %d asked"
				.. " last scan, note %s"):format(ns.proximity.asked,
				tostring(ns.proximity.note)))
		end
		local said = tostring(ns.ProximitySummary())
		if said:find("everybody in casting range is offered", 1, true)
			or said:find("answered for", 1, true)
			or not said:find("only your group", 1, true) then
			fail(scenario, "the line does not say a warrior's buffs reach only the group: "
				.. said)
		end
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

-- Shared by the warrior scenarios below: the shout learned in every rank, and
-- the aura baseline settled so the next buff to land is noticed as a favour.
local function knowShout(ns)
	local known = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
end

local function primeAuras(ns)
	Mock.advance(10)
	for _ = 1, 3 do
		ns.ScanOwnBuffs()
		Mock.runTimers(0.3)
	end
end

-- A buff landing on the player from `source`, and everything said about it.
local function favourFrom(ns, source, spellId, instanceId)
	Mock.printed = {}
	Mock.extraAura = instanceId or 4001
	Mock.extraAuraSpell = spellId
	Mock.extraAuraSource = source
	ns.addon:UNIT_AURA(nil, "player")
	return table.concat(Mock.printed, "\n")
end

-- The prompt armed at `entry` and pressed, and the game reporting `spellId`
-- going out on the player. What a shout looks like from the settle path.
local function pressAndSend(ns, entry, spellId)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, spellId)
	return true
end

-- ------------------------------------------------------------------ 209
-- In a raid, Battle Shout is offered to the warrior's own subgroup and nobody
-- else in it.
--
-- The shout reaches the caster's party, and in a raid that is the caster's
-- subgroup of five. The scan asked whether somebody was in the group at all --
-- UnitInParty or UnitInRaid -- and UnitInRaid answers with an index for every
-- member of the raid. So a warrior in a forty-man raid was offered the
-- thirty-five people in other subgroups the shout cannot reach, back every
-- twelve seconds; pressing the prompt for one of them who was owed counted as
-- repaying them; and a favour from one of them was announced as "on the
-- prompt". Both ways of asking are covered: UnitInSubgroup where the client has
-- it, and the raid roster's subgroup numbers where it does not.
for _, case in ipairs({ { api = "UnitInSubgroup" }, { api = "the raid roster" } }) do
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.raid = { size = 40, player = 1 }
	Mock.unitNames = {}
	for i = 1, 40 do Mock.unitNames["raid" .. i] = { "Raider" .. i, "Stone" } end
	local realKnown, realPlayer, realSubgroup = IsSpellKnown, IsPlayerSpell, UnitInSubgroup
	if case.api ~= "UnitInSubgroup" then UnitInSubgroup = nil end
	local scenario = "Battle Shout in a raid reaches the warrior's own subgroup ("
		.. case.api .. ")"
	ns = load(scenario)
	if ns then
		knowShout(ns)
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.Guard("probe", ns.ProbeCapabilities)

		local offered = inQueue(ns)
		local own, outside = 0, 0
		for i = 2, 40 do
			if offered["Raider" .. i .. " Stone"] then
				if i <= 5 then own = own + 1 else outside = outside + 1 end
			end
		end
		if own ~= 4 then
			fail(scenario, ("SKIPPED -- %d of the warrior's own four subgroup mates were"
				.. " offered the shout"):format(own))
		elseif outside > 0 then
			fail(scenario, ("offered Battle Shout to %d raid members in other subgroups,"
				.. " whom it cannot reach"):format(outside))
		end

		-- Raider20 is in subgroup four and buffed the warrior. Owed, and still
		-- out of earshot of the shout.
		ns.owed["Raider20 Stone"] = { expires = GetTime() + 100, at = GetTime() }
		local queue = ns.BuildQueue()
		for _, entry in ipairs(queue) do
			if entry.name == "Raider20 Stone" then
				fail(scenario, "an owed raider in another subgroup was offered a shout that"
					.. " cannot reach them")
			end
		end
		local shout = ns.FindBuff("WARRIOR", "battleshout").ranks[1]
		if queue[1] and pressAndSend(ns, queue[1], shout) then
			if not ns.owed["Raider20 Stone"] then
				fail(scenario, "a shout that cannot reach another subgroup counted as"
					.. " repaying somebody in it")
			end
		end

		wipe(ns.owed)
		primeAuras(ns)
		local said = favourFrom(ns, "raid30", 25289)
		if not said:find("buffed you", 1, true) then
			fail(scenario, "SKIPPED -- the favour from raid30 was not noticed: " .. said)
		elseif said:find("on the prompt", 1, true) then
			fail(scenario, "a favour from another subgroup was announced as on the prompt: "
				.. said)
		end
	end
	IsSpellKnown, IsPlayerSpell, UnitInSubgroup = realKnown, realPlayer, realSubgroup
end
Mock.reset()

-- The later flavours made the shouts raid-wide, and there the subgroup is not
-- the limit: the same raid, on Mists, offers the shout to everybody in it.
-- Passes against the unfixed code, which offered everybody everywhere; it is
-- here for the fix, which must not carry the vanilla rule onto a set where it is
-- false.
Mock.reset()
Mock.setFlavour("mists")
Mock.class = "WARRIOR"
Mock.raid = { size = 40, player = 1 }
Mock.unitNames = {}
for i = 1, 40 do Mock.unitNames["raid" .. i] = { "Raider" .. i, "Stone" } end
local realKnown209, realPlayer209 = IsSpellKnown, IsPlayerSpell
ns = load("a raid-wide shout reaches the whole raid")
if ns then
	local scenario = "a raid-wide shout reaches the whole raid"
	knowShout(ns)
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.Guard("probe", ns.ProbeCapabilities)
	-- No surnames off Camelot, so the second half of each name is not said.
	local offered = inQueue(ns)
	if not offered["Raider2"] then
		fail(scenario, "SKIPPED -- the warrior's own subgroup was not offered the shout")
	elseif not offered["Raider20"] then
		fail(scenario, "on a flavour whose shout reaches the raid, a raider in another"
			.. " subgroup was not offered it")
	end
end
IsSpellKnown, IsPlayerSpell = realKnown209, realPlayer209
Mock.reset()

-- ------------------------------------------------------------------ 210
-- Battle Shout is offered only to group members close enough to hear it.
--
-- The queue's range test asks IsSpellInRange, and a shout has no range to
-- anybody: it is cast on yourself, and the client answers nil. Nil is "could
-- not tell" and is let through, and nothing else measured a group member at all
-- -- so a party member sixty yards off, or in another zone, was offered the
-- shout, and pressing it counted as repaying them. Where nothing can measure,
-- they are still offered, but a shout is not taken as repaying them.
for _, case in ipairs({
	{ label = "sixty yards", yards = 60, interact = "on", offered = false, repaid = false },
	{ label = "ten yards", yards = 10, interact = "on", offered = true, repaid = true },
	{ label = "nothing measures", yards = 60, interact = "restricted", offered = true,
		repaid = false },
}) do
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.groupSize = 3
	Mock.unitNames = { party1 = { "Near", "Ally" }, party2 = { "Far", "Ally" } }
	Mock.yards = { party1 = 5, party2 = case.yards }
	Mock.setInteract(case.interact)
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "Battle Shout reaches only who can hear it (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		knowShout(ns)
		Mock.rangeless = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do
			Mock.rangeless[id] = true
		end
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.profile.verbose = true

		ns.owed["Far Ally"] = { expires = GetTime() + 100, at = GetTime() }
		local queue = ns.BuildQueue()
		local far
		for _, entry in ipairs(queue) do
			if entry.name == "Far Ally" then far = entry end
		end
		if case.offered and not far then
			fail(scenario, "SKIPPED -- the party member was not offered the shout at all")
		elseif not case.offered and far then
			fail(scenario, "a party member sixty yards away was offered Battle Shout")
		end

		local shout = ns.FindBuff("WARRIOR", "battleshout").ranks[1]
		if queue[1] and pressAndSend(ns, far or queue[1], shout) then
			local said = table.concat(Mock.printed, "\n")
			if case.repaid and ns.owed["Far Ally"] then
				fail(scenario, "a shout that reached them did not clear the debt")
			elseif not case.repaid and not ns.owed["Far Ally"] then
				fail(scenario, "a shout nothing could say reached them counted as repaying"
					.. " them")
			elseif far and not case.repaid and not said:find("Far Ally is still owed", 1, true) then
				fail(scenario, "the debt was kept and the line did not say so: " .. said)
			end
		end
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

-- ------------------------------------------------------------------ 211
-- A favour the prompt can never return is neither recorded nor announced as on
-- it.
--
-- NoteFavour asked only whether this character knew some spell or other, and
-- the queue asks a good deal more. A mage in a party with a warrior, with "Skip
-- players the buff does nothing for" on as it is by default: every Battle Shout
-- was announced as "returning the favour is on the prompt" and written to the
-- saved variables, while the queue turned the warrior down for Arcane Intellect
-- on every scan. The same lie for a priest with every spell switched off, and
-- for one whose pinned spell is not learned.
for _, case in ipairs({
	{ label = "a warrior, skipping the useless", class = "WARRIOR", mana = 0,
		spell = 25289, relevant = true, recorded = false, useless = true },
	{ label = "a warrior, offering everybody", class = "WARRIOR", mana = 0,
		spell = 25289, relevant = false, recorded = true },
	{ label = "a priest", class = "PRIEST", mana = 1000, spell = 10938, relevant = true,
		recorded = true },
}) do
	Mock.reset()
	Mock.groupSize = 3
	Mock.unitClass = case.class
	Mock.unitNames = { party1 = { "Grom", "Hale" } }
	local realPowerMax = UnitPowerMax
	UnitPowerMax = function(unit, ...)
		if unit ~= "player" then return case.mana end
		return realPowerMax(unit, ...)
	end
	local scenario = "a favour the prompt cannot return is not promised (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		wipe(ns.owed)
		ns.addon:SaveDebts()
		ns.db.profile.filters.relevantOnly = case.relevant
		primeAuras(ns)
		local said = favourFrom(ns, "party1", case.spell)
		local saved = ns.db.char.debts and ns.db.char.debts["Grom Hale"]
		if not said:find("Grom Hale", 1, true) then
			fail(scenario, "SKIPPED -- the buff from party1 was not noticed: " .. said)
		elseif case.recorded then
			if not ns.owed["Grom Hale"] then
				fail(scenario, "a favour the prompt can return was not recorded: " .. said)
			else
				local offered = inQueue(ns)["Grom Hale"]
				if not offered then
					fail(scenario, "SKIPPED -- recorded, and not offered by the queue")
				elseif not said:find("on the prompt", 1, true) then
					fail(scenario, "a favour the prompt returns was not said to be on it: "
						.. said)
				end
			end
		else
			if said:find("on the prompt", 1, true) then
				fail(scenario, "a warrior's shout was announced as on the prompt for a"
					.. " mage who can give them nothing: " .. said)
			end
			if ns.owed["Grom Hale"] or saved then
				fail(scenario, "a favour nothing can repay was recorded")
			end
			if case.useless and not said:find("nothing you cast is any use", 1, true) then
				fail(scenario, "the line does not say why nothing will be offered: " .. said)
			end
		end
	end
	UnitPowerMax = realPowerMax
end
Mock.reset()

for _, case in ipairs({
	{ label = "every spell switched off", skip = true, recorded = false },
	{ label = "the pinned spell not learned", choice = "spirit", recorded = false },
	{ label = "nothing in the way", recorded = true },
}) do
	Mock.reset()
	Mock.class = "PRIEST"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "a favour the prompt cannot return is not promised (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		wipe(ns.owed)
		if case.skip then
			ns.db.profile.buff.skip = { fortitude = true, spirit = true, shadow = true }
		end
		if case.choice then ns.db.profile.buff.choice = case.choice end
		primeAuras(ns)
		local said = favourFrom(ns, "nameplate1", 10938)
		if case.recorded then
			if not ns.owed["Petra Stonewell"] or not said:find("on the prompt", 1, true) then
				fail(scenario, "SKIPPED -- the control favour was not recorded: " .. said)
			end
		else
			if ns.owed["Petra Stonewell"] then
				fail(scenario, "a favour was recorded that no prompt will ever offer back")
			end
			if said:find("on the prompt", 1, true) then
				fail(scenario, "announced as on the prompt with nothing to offer: " .. said)
			elseif said:find("buffed you", 1, true) then
				-- Said at all, which is the same silence a rogue gets. The line
				-- for a buff that is no use to somebody blames a setting that
				-- has nothing to do with this.
				fail(scenario, "a favour was announced with nothing to offer anybody: " .. said)
			end
		end
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

-- ------------------------------------------------------------------ 212
-- Lowering "Remember a buff for" applies to the people who already buffed you.
--
-- A debt was stamped with its expiry once, when it was filed, and everything
-- that read it compared that stamp alone. Setting the window from ten minutes
-- to thirty seconds left a minute-old debt owed for nine minutes more, at the
-- top of the queue -- while a /reload clamped it to the new window, which is
-- what the reload's own comment promised the slider did. A profile switch to a
-- shorter window was the same.
for _, case in ipairs({ { how = "the slider" }, { how = "a profile switch" } }) do
	Mock.reset()
	local scenario = "a shorter window applies to live debts (" .. case.how .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		wipe(ns.owed)
		ns.db.profile.timing.reciprocateWindow = 600
		primeAuras(ns)
		favourFrom(ns, "nameplate1", 10938)
		if not ns.owed["Petra Stonewell"] then
			fail(scenario, "SKIPPED -- no favour was filed")
		else
			if case.how == "the slider" then
				ns.db.profile.timing.reciprocateWindow = 30
			else
				local timing = {}
				for k, v in pairs(ns.db.profile.timing) do timing[k] = v end
				timing.reciprocateWindow = 30
				ns.db.profile.timing = timing
				local changed = Mock.dbCallbacks["OnProfileChanged"]
				if changed then changed.target[changed.method](changed.target) end
			end
			Mock.advance(60)

			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.reason == "owed" then
					fail(scenario, "a debt older than the window was still offered as owed")
				end
			end
			Mock.printed = {}
			ns.addon:HandleSlash("debug")
			local said = table.concat(Mock.printed, "\n")
			if said:find("owes returning", 1, true) then
				fail(scenario, "/manners debug still lists a debt older than the window: "
					.. said:match("owes returning[^\n]*"))
			end
			ns.addon:Tick()
			if ns.owed["Petra Stonewell"] then
				fail(scenario, "a minute-old debt outlived a thirty-second window")
			end
		end
	end
end
Mock.reset()

-- And across a reload: the window counts from the favour, not from the login.
-- A debt written under a ten-minute window and read back under a two-minute one
-- it is already older than is not given the whole two minutes again.
Mock.reset()
Mock.sv = {}
local a212 = load("a debt older than the window does not survive a reload")
if a212 then
	local scenario = "a debt older than the window does not survive a reload"
	drive(scenario, a212)
	wipe(a212.owed)
	a212.db.profile.timing.reciprocateWindow = 600
	a212.owed["Mira Tallow"] = { expires = GetTime() + 300, at = GetTime() - 100 }
	a212.addon:SaveDebts()
	a212.db.profile.timing.reciprocateWindow = 120
	Mock.advance(30)
	Mock.now = 5
	local b212 = load(scenario)
	if b212 then
		if not pcall(function() b212.addon:OnInitialize() end) then
			fail(scenario, "SKIPPED -- the second session would not initialise")
		elseif b212.owed["Mira Tallow"] then
			fail(scenario, ("a debt 130 seconds old came back with %d seconds left of a"
				.. " 120-second window"):format(
				math.floor(b212.owed["Mira Tallow"].expires - GetTime())))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 213
-- A pinned spell is offered whatever its own switch under Automatic says.
--
-- The page hides the per-spell switches the moment a spell is pinned, and the
-- note beside the pin says they "are left alone while one spell is pinned" --
-- but CastableBuffs went on dropping a switched-off spell even when it was the
-- pinned one. Only the never-automatic rule had been taught to let a pin
-- through. So a priest who switched everything off, changed their mind and
-- pinned Fortitude was offered nothing, to anybody, while the page promised
-- Fortitude to everybody; and a low-level priest whose one spell had been
-- switched off got the same silence from pinning it. The same pin worked the
-- moment any other spell was still switched on, which is the control.
for _, case in ipairs({
	{ label = "everything off, Fortitude pinned", pin = "fortitude",
		know = { "fortitude", "spirit", "shadow" }, skip = { "fortitude", "spirit", "shadow" } },
	{ label = "everything off, Divine Spirit pinned", pin = "spirit",
		know = { "fortitude", "spirit", "shadow" }, skip = { "fortitude", "spirit", "shadow" } },
	{ label = "the only spell learned, off and pinned", pin = "fortitude",
		know = { "fortitude" }, skip = { "fortitude" } },
	{ label = "one off and pinned, the rest on", pin = "spirit",
		know = { "fortitude", "spirit", "shadow" }, skip = { "spirit" } },
}) do
	Mock.reset()
	Mock.class = "PRIEST"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "a pinned spell is offered with its switch off (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, key in ipairs(case.know) do
			for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
		end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.profile.buff.skip = {}
		for _, key in ipairs(case.skip) do ns.db.profile.buff.skip[key] = true end
		ns.db.profile.buff.choice = case.pin
		local pinned = ns.FindBuff("PRIEST", case.pin)

		local listed = false
		for _, buff in ipairs(ns.CastableBuffs()) do
			if buff.key == case.pin then listed = true end
		end
		if not listed then
			fail(scenario, "the pinned spell is not among the castable ones, so the walk"
				.. " gives up before it ever reads the pin")
		end

		-- A stranger in front of the player, and a favour with no token behind
		-- it: the two paths into the queue.
		ns.owed["Vann Locke"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		local stranger, favour
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Petra Stonewell" then stranger = entry end
			if entry.name == "Vann Locke" then favour = entry end
		end
		if not stranger then
			fail(scenario, "the stranger was offered nothing with a learned spell pinned")
		elseif stranger.buff.key ~= case.pin then
			fail(scenario, "the stranger was offered " .. tostring(stranger.buff.key)
				.. " with " .. case.pin .. " pinned")
		end
		if not favour then
			fail(scenario, "the favour was offered nothing with a learned spell pinned")
		elseif favour.buff.key ~= case.pin then
			fail(scenario, "the favour was offered " .. tostring(favour.buff.key))
		end

		-- And the prompt arms for it.
		ns.addon:Tick()
		local macro = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
		if not macro:find(ns.BuffName(pinned), 1, true) then
			fail(scenario, "the prompt armed nothing for the pinned spell: " .. macro)
		end
		wipe(ns.owed)
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

-- ------------------------------------------------------------------ 214
-- The spell the login line, the preview and the phrase samples name is one the
-- queue would actually offer.
--
-- A paladin's Automatic reaches for Wisdom for anybody with mana, and
-- ResolveBuff returned that choice the moment it was learned without asking
-- whether it had been switched off. The walk skipped it and offered Might; the
-- login line said "Ready to cast Blessing of Wisdom", and so did the preview,
-- Roll a few and {spell}. And a priest with all three spells learned and all
-- three switched off was told "no buff learned" -- and greeted with a promise
-- of a prompt and a preview of one that would never appear.
local function findOption(node, key)
	if type(node) ~= "table" or type(node.args) ~= "table" then return nil end
	if node.args[key] then return node.args[key] end
	for _, child in pairs(node.args) do
		local found = findOption(child, key)
		if found then return found end
	end
end

-- What the addon says it is about to cast everywhere but the queue: {spell} in
-- the test console, and a line from Roll a few.
local function namedSpell(ns)
	ns.lastTopEntry = nil
	local token = ns.ExpandTokens("{spell}")
	ns.db.profile.speech.enabled = true
	ns.db.profile.speech.phrases = "Here is {buff} for the road."
	local roll = findOption(ns.optionsTable, "roll")
	Mock.printed = {}
	if roll and roll.func then pcall(roll.func) end
	return token, table.concat(Mock.printed, "\n")
end

-- A profile written in an earlier session, so the login below reads it back
-- through ClampSettings the way a real one would be.
local function savedProfile(scenario, edit)
	local first = load(scenario)
	if not first then return false end
	if not pcall(function() first.addon:OnInitialize() end) then return false end
	edit(Mock.sv.profile)
	return true
end

for _, case in ipairs({
	{ label = "Wisdom switched off", skip = { "wisdom" }, want = "Blessing of Might" },
	{ label = "Wisdom and Might switched off", skip = { "wisdom", "might" },
		want = "Blessing of Kings" },
}) do
	Mock.reset()
	Mock.sv = {}
	Mock.class = "PALADIN"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "the spell named is one that is switched on (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, key in ipairs({ "wisdom", "might", "kings" }) do
			for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
		end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		local saved = savedProfile(scenario, function(profile)
			for _, key in ipairs(case.skip) do profile.buff.skip[key] = true end
		end)
		ns = saved and load(scenario)
		local said = ns and firstLogin(ns)
		if not said then
			fail(scenario, "SKIPPED -- the session would not start")
		else
			local ready = said:match("Ready to cast[^\n]*") or said
			if not ready:find(case.want, 1, true) then
				fail(scenario, "the login line names a spell that is switched off: " .. ready)
			end
			local resolved = ns.ResolveBuff(true)
			if not resolved or ns.BuffName(resolved) ~= case.want then
				fail(scenario, "the preview is handed "
					.. tostring(resolved and ns.BuffName(resolved)) .. ", not " .. case.want)
			end
			local token, rolled = namedSpell(ns)
			if token ~= case.want then
				fail(scenario, "{spell} names " .. tostring(token) .. ", not " .. case.want)
			end
			if not rolled:find(case.want, 1, true) then
				fail(scenario, "Roll a few samples a spell that is switched off: " .. rolled)
			end
			ns.Prompt:ExitTest()
		end
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

Mock.reset()
Mock.sv = {}
Mock.class = "PRIEST"
do
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "every spell switched off is not 'no buff learned'"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
			for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
		end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		local saved = savedProfile(scenario, function(profile)
			profile.buff.skip = { fortitude = true, spirit = true, shadow = true }
		end)
		ns = saved and load(scenario)
		local said = ns and firstLogin(ns)
		if not said then
			fail(scenario, "SKIPPED -- the session would not start")
		else
			local line = said:match("build[^\n]*") or said
			if line:find("no buff learned", 1, true) then
				fail(scenario, "three learned spells, all switched off, reported as none"
					.. " learned: " .. line)
			elseif not line:find("switched off", 1, true) then
				fail(scenario, "the login line does not say the spells are switched off: "
					.. line)
			end
			if said:find("small prompt", 1, true) then
				fail(scenario, "the greeting promised a prompt nothing will ever fill: " .. said)
			end
			if ns.Prompt:InTest() then
				fail(scenario, "the greeting put up a preview of a prompt that will never"
					.. " appear")
				ns.Prompt:ExitTest()
			end
			local greeting = said:gsub("^[^\n]*\n?", "")
			if not greeting:find("switched off", 1, true) then
				fail(scenario, "the greeting does not say why nothing will be offered: " .. said)
			end
		end
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

-- ------------------------------------------------------------------ 215
-- A pinned spell this character has not learned is named as such, not swapped
-- for the Automatic one.
--
-- On a profile every character shares, a level-60 priest pins Divine Spirit and
-- a low-level alt without it logs in. The queue offers nobody anything, which
-- is deliberate and what the pin's own note says. ResolveBuff fell through to
-- Automatic instead, so the login line said "Ready to cast Power Word:
-- Fortitude", and the greeting's preview, Roll a few and {spell} all named a
-- spell that would never be cast.
for _, case in ipairs({
	{ label = "Divine Spirit pinned, not learned", pin = "spirit" },
	{ label = "Automatic", pin = "auto", want = "Power Word: Fortitude" },
}) do
	Mock.reset()
	Mock.sv = {}
	Mock.class = "PRIEST"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "an unlearned pin is named, not replaced (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		local saved = savedProfile(scenario, function(profile)
			profile.buff.choice = case.pin
		end)
		ns = saved and load(scenario)
		local said = ns and firstLogin(ns)
		if not said then
			fail(scenario, "SKIPPED -- the session would not start")
		elseif ns.db.profile.buff.choice ~= case.pin then
			fail(scenario, "SKIPPED -- the pin did not survive the login")
		else
			local line = said:match("build[^\n]*") or said
			local token, rolled = namedSpell(ns)
			if case.want then
				if not line:find(case.want, 1, true) then
					fail(scenario, "the Automatic control names the wrong spell: " .. line)
				end
				if token ~= case.want then
					fail(scenario, "the Automatic control's {spell} is " .. tostring(token))
				end
			else
				if line:find("Fortitude", 1, true) then
					fail(scenario, "the login line names a spell the pin keeps from ever being"
						.. " cast: " .. line)
				elseif not (line:find("Divine Spirit", 1, true)
					and line:find("not learned", 1, true)) then
					fail(scenario, "the login line does not say the pinned spell is not"
						.. " learned: " .. line)
				end
				if ns.ResolveBuff(true) then
					fail(scenario, "the preview is handed "
						.. ns.BuffName(ns.ResolveBuff(true)) .. " under a pin on an unlearned"
						.. " spell")
				end
				if ns.Prompt:InTest() then
					fail(scenario, "the greeting put up a preview of a prompt that will never"
						.. " appear")
				end
				if token:find("Fortitude", 1, true) then
					fail(scenario, "{spell} names " .. token .. " under an unlearned pin")
				end
				if rolled:find("Fortitude", 1, true) then
					fail(scenario, "Roll a few samples Fortitude under an unlearned pin: "
						.. rolled)
				end
				Mock.advance(60)
				wipe(ns.tried)
				if #ns.BuildQueue() > 0 then
					fail(scenario, "SKIPPED -- the queue offers something under the pin, so"
						.. " none of the above is about a silent pin")
				end
			end
			ns.Prompt:ExitTest()
		end
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end
Mock.reset()

-- ------------------------------------------------------------------ 216
-- Another paladin's blessing is not one of yours.
--
-- Blessings from one paladin overwrite each other, which is why holding any
-- one of yours counts as covered -- but the aura read never asked who had cast
-- what it found. A warrior wearing another paladin's Kings was taken as covered
-- and never offered Might, which stacks with it; and a paladin we owed, wearing
-- a third paladin's Kings, was "repaid" with Kings -- replacing somebody else's
-- blessing with the same one -- rather than handed the Wisdom they lacked.
--
-- An aura nobody is named on stays covered, as before: that is every aura on
-- a client that will not say, and guessing "not mine" there is how a paladin's
-- own blessing gets walked over.
for _, case in ipairs({
	{ label = "a warrior with another paladin's Kings", warrior = true,
		held = 20217, source = "nameplate2", want = "might" },
	{ label = "a warrior with another paladin's Might", warrior = true,
		held = 25291, source = "nameplate2", want = "kings" },
	{ label = "a warrior with another paladin's Greater Kings", warrior = true,
		held = 25898, source = "nameplate2", want = "might" },
	{ label = "a bare warrior", warrior = true, want = "might" },
	{ label = "a warrior with our own Kings", warrior = true,
		held = 20217, source = "player", want = false },
	{ label = "a warrior with Kings from nobody named", warrior = true,
		held = 20217, want = false },
	{ label = "an owed paladin with a third paladin's Kings", owed = true,
		held = 20217, source = "nameplate2", want = "wisdom" },
	{ label = "an owed paladin with our own Kings", owed = true,
		held = 20217, source = "player", want = "kings" },
}) do
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.unitClass = case.warrior and "WARRIOR" or "PALADIN"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local realPowerMax = UnitPowerMax
	if case.warrior then
		UnitPowerMax = function(unit, ...)
			if unit ~= "player" then return 0 end
			return realPowerMax(unit, ...)
		end
	end
	local scenario = "another paladin's blessing is not one of yours (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, key in ipairs({ "wisdom", "might", "kings" }) do
			for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
		end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.profile.filters.relevantOnly = true
		if case.held then
			Mock.held = { [case.held] = true }
			Mock.heldSource = case.source and { [case.held] = case.source } or nil
		end
		if case.owed then
			ns.owed["Petra Stonewell"] = { expires = GetTime() + 100, at = GetTime() }
		end

		-- Twice, the second read from the aura cache, which has to remember
		-- whose the blessing was as well as that it was there.
		for _, pass in ipairs({ "read", "cached" }) do
			local petra = inQueue(ns)["Petra Stonewell"]
			local got = petra and petra.buff.key or false
			if got ~= case.want then
				fail(scenario, ("%s: offered %s, expected %s"):format(pass, tostring(got),
					tostring(case.want)))
			end
			Mock.advance(1)
		end
		wipe(ns.owed)
	end
	Mock.held, Mock.heldSource = nil, nil
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
	UnitPowerMax = realPowerMax
end
Mock.reset()

-- ------------------------------------------------------------------ 217
-- An aura the client would not let us read is "could not tell", not "not
-- carrying it".
--
-- The aura read started from "not carrying it" and stayed there when an id was
-- passed over because the client declared it secret, or when the read itself
-- threw or came back secret. So somebody wearing Arcane Brilliance on a client
-- that hides that one id was read as definitely missing Arcane Intellect:
-- promoted over a person who had buffed you, because "your target, and missing
-- it" rests on exactly that definite no, and shown without the wording that
-- says the reading could not be taken.
for _, case in ipairs({
	{ label = "an id declared secret", secret = true },
	{ label = "a read that throws", refuse = "throw" },
	{ label = "a read that comes back secret", refuse = "secret" },
	{ label = "everything readable", control = true },
}) do
	Mock.reset()
	local scenario = "a refused aura read is not a definite no (" .. case.label .. ")"
	local realName = UnitName
	UnitName = function(u)
		if u == "player" then return "Mort", "Defrette" end
		if u == "target" then return "Petra", "Stonewell" end
		return "Yorick", "Vane"
	end
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		if not case.control then Mock.held = { [23028] = true } end
		if case.secret then Mock.secretAuraIds = { [23028] = true } end
		if case.refuse then Mock.auraReadRefuse = { [23028] = case.refuse } end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }

		local q = ns.BuildQueue()
		local petra
		for _, entry in ipairs(q) do
			if entry.name == "Petra Stonewell" then petra = entry end
		end
		if not petra then
			fail(scenario, "SKIPPED -- the target was not offered at all")
		elseif case.control then
			if petra.known ~= false or petra.reason ~= "target" then
				fail(scenario, "the readable control was not promoted as a definite no: "
					.. tostring(petra.known) .. " / " .. tostring(petra.reason))
			end
		else
			if petra.known ~= nil then
				fail(scenario, "a reading the client refused came back as "
					.. tostring(petra.known))
			end
			if petra.reason == "target" or not (q[1] and q[1].name == "Yorick Vane") then
				fail(scenario, "an unreadable target was promoted over somebody who buffed"
					.. " you: " .. tostring(q[1] and q[1].name))
			end
			local definite = {}
			for k, v in pairs(petra) do definite[k] = v end
			definite.known = false
			if ns.Prompt:ReasonText(petra) == ns.Prompt:ReasonText(definite) then
				fail(scenario, "the prompt does not say the reading could not be taken")
			end
		end
		wipe(ns.owed)
	end
	UnitName = realName
end
Mock.reset()

-- ------------------------------------------------------------------ 218
-- The login line does not say "watching for buffs" on a profile that is
-- switched off.
--
-- The profile is shared, so /manners off on one character is off on every
-- alt. The line printed at every login never asked, and an alt got "watching
-- for buffs. Ready to cast Arcane Intellect" -- with, on a first login, the
-- greeting saying "It is switched off on this profile" directly underneath.
Mock.reset()
Mock.sv = {}
ns = load("the login line on a switched-off profile says so")
if ns then
	local scenario = "the login line on a switched-off profile says so"
	local first = firstLogin(ns)
	ns.Prompt:ExitTest()
	ns.addon:HandleSlash("off")
	if not first or ns.db.profile.enabled ~= false then
		fail(scenario, "SKIPPED -- the first character could not switch the addon off")
	else
		local function count(text, needle)
			local n, from = 0, 1
			while true do
				local at = text:find(needle, from, true)
				if not at then return n end
				n, from = n + 1, at + 1
			end
		end
		Mock.character = "Perrin Stonewell"
		for _, session in ipairs({ "the alt's first login", "a reload" }) do
			local alt = load(scenario)
			local said = alt and firstLogin(alt)
			if not said then
				fail(scenario, session .. ": the session would not start")
			else
				if said:find("watching for buffs", 1, true) then
					fail(scenario, session .. ": said it is watching for buffs while switched"
						.. " off: " .. said)
				end
				if count(said, "switched off on this profile") ~= 1 then
					fail(scenario, session .. ": said it is switched off "
						.. count(said, "switched off on this profile") .. " times: " .. said)
				end
				alt.Prompt:ExitTest()
			end
		end

		-- And switched back on, the ordinary line.
		Mock.sv.profile.enabled = true
		local back = load(scenario)
		local said = back and firstLogin(back) or ""
		if not said:find("watching for buffs", 1, true) then
			fail(scenario, "SKIPPED -- switched back on, the ordinary line is gone too: "
				.. said)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 219
-- A colour repaired at login does not turn the prompt white on the next
-- profile switch.
--
-- ClampSettings put a damaged colour right by storing the defaults' own table
-- in the profile -- the very table AceDB holds as the default. At a profile
-- switch AceDB strips every value equal to its default out of the profile it
-- is leaving, and with the two tables being one, it stripped the default of
-- all four of its numbers. Every profile arrived at after that was filled from
-- an empty colour, which reads as 1,1,1,1: a solid white panel on every
-- profile until the next /reload.
for _, case in ipairs({
	{ label = "a word", value = "black" },
	{ label = "three letters", value = { "a", "b", "c" } },
}) do
	Mock.reset()
	Mock.sv = {}
	local scenario = "a repaired colour survives a profile switch (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		if not ns.db.SetProfile then
			fail(scenario, "SKIPPED -- the mock AceDB cannot switch profiles")
		else
			local want = { 0.04, 0.04, 0.06, 0.88 }
			ns.db.profile.prompt.bgColor = case.value
			ns.ClampSettings()
			ns.db:SetProfile("Alt")
			local function same(c)
				if type(c) ~= "table" then return false end
				for i = 1, 4 do
					if c[i] ~= want[i] then return false end
				end
				return true
			end
			if not same(ns.defaults.profile.prompt.bgColor) then
				fail(scenario, "the switch emptied the default colour itself: "
					.. #ns.defaults.profile.prompt.bgColor .. " numbers left in it")
			end
			if not same(ns.db.profile.prompt.bgColor) then
				fail(scenario, "the profile switched to paints its panel from "
					.. #ns.db.profile.prompt.bgColor .. " numbers, which reads as white")
			end
			ns.db:SetProfile("Default")
			if not same(ns.db.profile.prompt.bgColor) then
				fail(scenario, "switching back found the repaired colour gone")
			end
		end
	end
end
Mock.reset()

-- And a colour that was fine to begin with is the one kept.
Mock.reset()
Mock.sv = {}
ns = load("a chosen colour survives a profile switch")
if ns then
	local scenario = "a chosen colour survives a profile switch"
	drive(scenario, ns)
	if ns.db.SetProfile then
		ns.db.profile.prompt.bgColor = { 0.2, 0.3, 0.4, 0.5 }
		ns.ClampSettings()
		ns.db:SetProfile("Alt")
		ns.db:SetProfile("Default")
		local c = ns.db.profile.prompt.bgColor
		if c[1] ~= 0.2 or c[2] ~= 0.3 or c[3] ~= 0.4 or c[4] ~= 0.5 then
			fail(scenario, "a colour somebody chose did not come back from a switch")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 220
-- An emptied phrase box shows at once what it falls back to, and nothing
-- unrelated changes the phrases afterwards.
--
-- The box stored an empty string as it was typed: it looked empty, nothing
-- was said, and Roll a few printed "(nothing ...)". But the load-time repair
-- refills blank phrases with a set, and it also runs from the Width, Height
-- and Icon size sliders -- so the lines a player had deleted came back after a
-- nudge of a slider that has nothing to do with speech, and at the next login
-- regardless, since AceDB never keeps an empty string that is the default.
for _, case in ipairs({
	{ label = "emptied", typed = "", choice = nil },
	{ label = "only spaces", typed = "  \n  ", choice = nil },
	{ label = "emptied on the Quiet set", typed = "", choice = "quiet" },
}) do
	Mock.reset()
	local scenario = "an emptied phrase box shows its fallback at once (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local phrases = findOption(ns.optionsTable, "phrases")
		local width = findOption(ns.optionsTable, "width")
		if not (phrases and phrases.set and phrases.get and width and width.set) then
			fail(scenario, "SKIPPED -- the phrase box or the width slider is not on the page")
		else
			local speech = ns.db.profile.speech
			speech.presetChoice = case.choice
			local want = ns.PhraseSetText(case.choice or "roleplay")
			phrases.set({ "phrases" }, case.typed)
			local shown = phrases.get({ "phrases" })
			if shown ~= want then
				fail(scenario, "the box went on showing \"" .. (tostring(shown):gsub("\n", "\\n"))
					.. "\" instead of the set it falls back to")
			end
			width.set({ "width" }, ns.db.profile.prompt.width + 10)
			if phrases.get({ "phrases" }) ~= shown then
				fail(scenario, "nudging the width slider changed the phrases the box showed")
			end
		end
	end
end
Mock.reset()

-- Lines somebody typed are theirs: no slider rewrites them.
Mock.reset()
ns = load("typed phrases survive the size sliders")
if ns then
	local scenario = "typed phrases survive the size sliders"
	drive(scenario, ns)
	local phrases = findOption(ns.optionsTable, "phrases")
	if phrases and phrases.set then
		local typed = "Here you go, {name}.\nOne good turn."
		phrases.set({ "phrases" }, typed)
		for _, key in ipairs({ "width", "height", "iconSize" }) do
			local slider = findOption(ns.optionsTable, key)
			if slider and slider.set then
				slider.set({ key }, ns.db.profile.prompt[key])
			end
		end
		if ns.db.profile.speech.phrases ~= typed then
			fail(scenario, "the size sliders rewrote the phrases somebody typed")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 221
-- A prompt moved onto its new anchor by an update says so in chat.
--
-- The carry-over in scenario 190 takes a bottom anchor with a negative offset
-- to be a 0.9.x leftover and moves it onto the middle of the screen. Its
-- reasoning was that no drag produces a negative offset from the bottom edge
-- -- but the Y slider does, anywhere down to -2000, and on beta.1 to beta.3 the
-- default anchor was already the bottom one. Such a prompt, sat on the bottom
-- edge, came back below the middle of the screen with nothing anywhere to say
-- why. The two cannot be told apart from what is on disk, so the move stands;
-- the player is told it happened and how to put it back.
for _, case in ipairs({
	{ label = "carried", y = -40, note = true },
	{ label = "nothing to carry", y = 40, note = false },
}) do
	Mock.reset()
	Mock.sv = {}
	local scenario = "a carried anchor is announced (" .. case.label .. ")"
	local saved = savedProfile(scenario, function(profile)
		profile.prompt.point, profile.prompt.relPoint = "BOTTOM", "BOTTOM"
		profile.prompt.y = case.y
		profile.prompt.anchorCarried = nil
	end)
	ns = saved and load(scenario)
	local said = ns and firstLogin(ns)
	if not said then
		fail(scenario, "SKIPPED -- the session would not start")
	else
		local p = ns.db.profile.prompt
		local moved = p.point == "CENTER"
		if moved ~= case.note then
			fail(scenario, "SKIPPED -- the carry-over " .. (moved and "fired" or "did not fire")
				.. " for a Y of " .. case.y)
		end
		local noted = said:find("Put it", 1, true) ~= nil
		if case.note and not noted then
			fail(scenario, "the prompt was moved onto a new anchor and chat said nothing: " .. said)
		elseif not case.note and noted then
			fail(scenario, "a prompt that was not moved was said to have been: " .. said)
		end
		ns.Prompt:ExitTest()
	end
end
Mock.reset()

-- And a switch onto a profile no version since has loaded, which is carried
-- the same way and has to be told about in the same way.
Mock.reset()
ns = load("a carried anchor is announced (profile switch)")
if ns then
	local scenario = "a carried anchor is announced (profile switch)"
	drive(scenario, ns)
	local p = ns.db.profile.prompt
	p.point, p.relPoint, p.y = "BOTTOM", "BOTTOM", -40
	p.anchorCarried = nil
	Mock.printed = {}
	ns.addon:RefreshConfig()
	local said = table.concat(Mock.printed, "\n")
	if p.point ~= "CENTER" then
		fail(scenario, "SKIPPED -- the carry-over did not fire on the switch")
	elseif not said:find("Put it", 1, true) then
		fail(scenario, "a profile switch moved the prompt onto a new anchor and chat said"
			.. " nothing: " .. said)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 222
-- /manners debug says when nothing is being watched.
--
-- With the addon switched off, or "People who buffed me" unticked, a favour is
-- never filed -- the scan does not even read who cast it. The command never
-- looked at either switch, so straight after somebody buffed you it printed
-- "nobody has buffed you recently", a healthy aura line and a queue count over
-- a prompt that was never going to appear. It is the output the bug-report
-- template asks players to paste, and it pointed at a detection bug that was a
-- switch.
for _, case in ipairs({
	{ label = "switched off", off = true },
	{ label = "favours not watched", owedOff = true },
	{ label = "both on", control = true },
}) do
	Mock.reset()
	local scenario = "debug says when favours are not being watched (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		wipe(ns.owed)
		local db = ns.db.profile
		if case.off then db.enabled = false end
		if case.owedOff then db.sources.owed = false end
		primeAuras(ns)
		favourFrom(ns, "nameplate1", 10938)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if case.control then
			if not said:find("owes returning: |cffffffffPetra Stonewell", 1, true) then
				fail(scenario, "SKIPPED -- the control favour is not listed: " .. said)
			end
		else
			if said:find("nobody has buffed you recently", 1, true) then
				fail(scenario, "debug said nobody has buffed you, straight after somebody"
					.. " did, while nothing was watching")
			end
			if case.off and not said:find("switched OFF", 1, true) then
				fail(scenario, "debug never said the addon is switched off: " .. said)
			end
			if case.off and said:find("queue now:", 1, true) then
				fail(scenario, "debug gave a live queue count for a switched-off prompt")
			end
			if case.owedOff and not said:find("People who buffed me", 1, true) then
				fail(scenario, "debug never said favours are not being watched: " .. said)
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 223
-- /manners try fills {first} and {unit} from the person, or not at all.
--
-- Both tokens fell back to the literal word "target" whenever the candidate
-- lacked them. FirstName has no answer for a name that is one word already --
-- a same-realm player off Camelot, a Camelot character with no surname -- so
-- "/target {first}" became "/target target", which keeps whatever you have
-- targeted. And a person who buffed you is ordinarily reached with no unit
-- token at all, so "[@{unit}]" became "[@target]". Either way the cast went to
-- somebody else while the tooltip named them.
local function tryAgainst(ns, entry, template)
	ns.addon:HandleSlash("try")
	ns.Prompt:ApplyTarget(entry)
	Mock.printed = {}
	ns.addon:HandleSlash("try " .. template)
	local said = table.concat(Mock.printed, "\n")
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	return said, ns.Prompt:GetButton():GetAttribute("macrotext1")
end

for _, case in ipairs({
	{ label = "a one-word name", name = "Petra", unit = "nameplate1",
		template = "/target {first}\\n/cast {spell}", want = "/target Petra\n" },
	{ label = "a name with a surname", name = "Petra Stonewell", unit = "nameplate1",
		template = "/target {first}\\n/cast {spell}", want = "/target Petra\n" },
	{ label = "{first} with no unit token", name = "Mort",
		template = "/target {first}\\n/cast {spell}", want = "/target Mort\n" },
	{ label = "{unit} with no unit token", name = "Mort",
		template = "/target {unit}\\n/cast {spell}", unfilled = true },
}) do
	Mock.reset()
	local scenario = "try tokens come from the person, never from your target (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		Mock.advance(60)
		local template = ns.BuildQueue()[1]
		if not template or not template.buff then
			fail(scenario, "SKIPPED -- nobody to build a candidate from")
		else
			local entry = {}
			for k, v in pairs(template) do entry[k] = v end
			entry.name, entry.short, entry.targetName = case.name, case.name, case.name
			entry.unit, entry.reason = case.unit, "owed"
			local said, armed = tryAgainst(ns, entry, case.template)
			if said:find("/target target", 1, true) or (armed or ""):find("/target target", 1, true) then
				fail(scenario, "a token became your own target: " .. tostring(armed))
			end
			if case.unfilled then
				if armed ~= nil then
					fail(scenario, "a macro was armed with {unit} guessed at: " .. tostring(armed))
				end
				if not said:find("cannot be filled", 1, true) then
					fail(scenario, "the echo did not say {unit} cannot be filled: " .. said)
				end
				if said:find("Click the prompt to run it", 1, true) then
					fail(scenario, "sent you to click a prompt with nothing on it")
				end
				local summary = table.concat(ns.Prompt:ClickSummary(entry), "\n")
				if summary:find("Runs your", 1, true) or not summary:find("cannot be filled", 1, true) then
					fail(scenario, "the tooltip promised a run the button was left empty for: "
						.. summary)
				end
			elseif not (armed or ""):find(case.want, 1, true) then
				fail(scenario, "armed " .. tostring(armed) .. " rather than " .. case.want)
			end
			ns.addon:HandleSlash("try")
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 224
-- /manners look tells a withheld buff check from a readable "not carrying it".
--
-- The aura loop skipped a read that threw or came back secret and then printed
-- hasBuff=false, in the same white as a readable no. That is the one question
-- the command exists to answer on this client, and it answered it wrongly in
-- exactly the case it was written for.
for _, case in ipairs({
	{ label = "a read that throws", refuse = "throw" },
	{ label = "a read that comes back secret", refuse = "secret" },
	{ label = "an id declared secret", secret = true },
	{ label = "readable and not carrying it", control = "absent" },
	{ label = "readable and carrying it", control = "held" },
}) do
	Mock.reset()
	local scenario = "look tells a withheld buff check from a no (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local buff = ns.ResolveBuff(true)
		if not buff then
			fail(scenario, "SKIPPED -- no buff to look for")
		else
			if case.refuse then
				Mock.auraReadRefuse = {}
				for _, id in ipairs(buff.auraIds) do Mock.auraReadRefuse[id] = case.refuse end
			end
			if case.secret then
				Mock.secretAuraIds = {}
				for _, id in ipairs(buff.auraIds) do Mock.secretAuraIds[id] = true end
				ns.Guard("probe", ns.ProbeCapabilities)
			end
			if case.control == "held" then Mock.held = { [buff.auraIds[1]] = true } end
			Mock.printed = {}
			ns.addon:HandleSlash("look target")
			local line = table.concat(Mock.printed, "\n"):match("hasBuff=[^\n]*") or ""
			if line == "" then
				fail(scenario, "SKIPPED -- look printed no hasBuff line")
			elseif case.control == "absent" then
				if not line:find("hasBuff=|cfffffffffalse", 1, true) then
					fail(scenario, "a readable no is no longer printed as false: " .. line)
				end
			elseif case.control == "held" then
				if not line:find(tostring(buff.auraIds[1]), 1, true) then
					fail(scenario, "a buff being carried is not printed by its id: " .. line)
				end
			elseif line:find("false", 1, true) then
				fail(scenario, "a check the client withheld was printed as a readable no: " .. line)
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 225
-- The help calls restore and verbose what they are: switches.
--
-- Both flip a setting that starts on, and the help described each as the
-- thing it does -- "hand your target back after buffing" -- so somebody who
-- typed one on a fresh profile to get that switched it off.
Mock.reset()
ns = load("the help says restore and verbose switch something on or off")
if ns then
	local scenario = "the help says restore and verbose switch something on or off"
	drive(scenario, ns)
	Mock.printed = {}
	ns.addon:HandleSlash("help")
	local said = table.concat(Mock.printed, "\n")
	for _, word in ipairs({ "restore", "verbose" }) do
		local line = said:match("/manners " .. word .. "|r[^\n]*")
		if not line then
			fail(scenario, "SKIPPED -- the help has no line for " .. word)
		elseif not line:find("on or off", 1, true) then
			fail(scenario, "the help describes " .. word .. " as an action, not a switch: " .. line)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 226
-- A change to what a press does, made in a fight, says it waits for the end.
--
-- /manners try, /manners restore and the controls under "When you click" only
-- ask for the macro to be rebuilt, and the rebuild cannot happen while the
-- fight has the button's attributes frozen. Chat said "Click the prompt to run
-- it" or "on" regardless, and a press then ran the macro armed when the fight
-- began -- a /yell somebody had just switched off among them. The rebuild when
-- the fight ends already works; what was missing was saying so.
Mock.reset()
ns = load("a click setting changed in a fight says it waits for the end")
if ns then
	local scenario = "a click setting changed in a fight says it waits for the end"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.advance(60)
	ns.Prompt:Refresh()
	local button = ns.Prompt:GetButton()
	if not button:GetAttribute("macrotext1") then
		fail(scenario, "SKIPPED -- nothing was armed before the fight")
	else
		Mock.inCombat = true
		local click = findOption(ns.optionsTable, "click")
		local notice = click and click.args and click.args.combatNotice
		if not notice or notice.hidden() then
			fail(scenario, "the When you click tab says nothing about the fight")
		end

		for _, command in ipairs({ "restore", "try /cast Frost Nova", "try" }) do
			Mock.printed = {}
			ns.addon:HandleSlash(command)
			local said = table.concat(Mock.printed, "\n")
			if said:find("Click the prompt to run it", 1, true) then
				fail(scenario, "/manners " .. command .. " sent a press to a frozen macro")
			end
			if not said:find("fight ends", 1, true) then
				fail(scenario, "/manners " .. command .. " in a fight never said it waits for"
					.. " the end of it: " .. said)
			end
		end

		-- Armed again, so the end of the fight has something to put on.
		ns.addon:HandleSlash("try /cast Frost Nova")
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if button:GetAttribute("macrotext1") ~= "/cast Frost Nova" then
			fail(scenario, "SKIPPED -- the end of the fight did not put the new macro on: "
				.. tostring(button:GetAttribute("macrotext1")))
		end
		if notice and not notice.hidden() then
			fail(scenario, "the fight notice outlived the fight")
		end
		ns.addon:HandleSlash("try")
		ns.addon:HandleSlash("restore")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 227
-- /manners unlock in a fight does not send you to drag the prompt.
--
-- The client refuses to move a secure frame in combat and OnDragStart gives up
-- there, and the panel says as much. The chat line said "drag the prompt"
-- regardless, sometimes over a prompt that was not on the screen at all.
Mock.reset()
ns = load("unlocking in a fight does not say drag")
if ns then
	local scenario = "unlocking in a fight does not say drag"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local button = ns.Prompt:GetButton()
	local moves = 0
	button.StartMoving = function() moves = moves + 1 end
	ns.db.profile.prompt.locked = true
	Mock.inCombat = true
	Mock.printed = {}
	ns.addon:HandleSlash("unlock")
	local said = table.concat(Mock.printed, "\n")
	if said:find("drag the prompt", 1, true) then
		fail(scenario, "sent you to drag a prompt the client will not move in a fight: " .. said)
	end
	if not said:find("fight ends", 1, true) then
		fail(scenario, "never said when the prompt can be moved: " .. said)
	end
	button.scripts.OnDragStart(button)
	if moves ~= 0 then
		fail(scenario, "SKIPPED -- a drag started in combat")
	end
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	button.scripts.OnDragStart(button)
	if moves ~= 1 then
		fail(scenario, "SKIPPED -- the drag did not start once the fight was over")
	end
	ns.db.profile.prompt.locked = true
end
Mock.reset()

-- ------------------------------------------------------------------ 228
-- A refusal with no cast guid to go on undoes nothing.
--
-- A late refusal was matched by guid only when both sides had one. Otherwise it
-- went to the one settle still in its window whose spell it named -- on the
-- theory that exactly one record could be meant. But a refusal need not be
-- about a record at all. A second press mashed in a fight, which the frozen
-- macro sends whatever the addon decides, or an Arcane Intellect pressed on the
-- action bar inside the global cooldown, is refused with nothing parked; and on
-- a client that leaves the guid empty on either side, that refusal was read as
-- the answer to the press before it, which had landed. The debt came back, the
-- twelve-second block was cut to two, the panel flashed red, chat said the game
-- had refused a cast it had taken, and the person was cast at again two seconds
-- later.
Mock.reset()
ns = load("a refusal with no cast guid undoes nothing")
if ns then
	local scenario = "a refusal with no cast guid undoes nothing"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.verbose = true

	local buff = ns.CastableBuffs()[1]
	if not buff then
		fail(scenario, "SKIPPED -- nothing castable to press with")
	else
		local spell = buff.ranks[1]
		local name = "Anna Aim"
		local key = name .. "\0" .. buff.key
		local flashes = 0
		local realShow = ns.Prompt.ShowOutcome
		ns.Prompt.ShowOutcome = function(self, kind, who, detail)
			if kind == "failed" and who == name then flashes = flashes + 1 end
			return realShow(self, kind, who, detail)
		end

		-- A press that lands, confirmed by the client naming Anna, and half a
		-- second later a refusal of something else with nothing parked.
		local function landThenRefuse(sent, refused)
			Mock.advance(5)
			wipe(ns.owed)
			wipe(ns.tried)
			flashes = 0
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.pendingClick = { name = name, at = GetTime(), buffKey = buff.key,
				selfCast = false, targeted = true }
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, sent, spell)
			if ns.owed[name] or ns.pendingClick then return nil end
			Mock.advance(0.5)
			Mock.printed = {}
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", refused, spell)
			return table.concat(Mock.printed, "\n")
		end

		for _, case in ipairs({
			{ sent = nil, refused = nil, label = "no guid on either side" },
			{ sent = nil, refused = "Cast-mashed", label = "a guid on the refusal only" },
			{ sent = "Cast-landed", refused = nil, label = "a guid on the send only" },
		}) do
			local said = landThenRefuse(case.sent, case.refused)
			if not said then
				fail(scenario, "SKIPPED -- the press did not settle (" .. case.label .. ")")
			else
				if ns.owed[name] then
					fail(scenario, "a refusal nothing tied to the press that landed put the debt"
						.. " back (" .. case.label .. ")")
				end
				local held = ns.tried[key]
				if not (held and held > GetTime() + 5) then
					fail(scenario, ("a buff that landed had its block cut to %.1f seconds by a"
						.. " refusal of something else (%s)"):format(
						(held or GetTime()) - GetTime(), case.label))
				end
				if said:find("refused the cast after sending it", 1, true) then
					fail(scenario, "chat said the game refused a cast it took (" .. case.label
						.. "): " .. said)
				end
				if flashes ~= 0 then
					fail(scenario, "the panel flashed red over a buff that landed ("
						.. case.label .. ")")
				end
			end
		end

		-- And the guid still does what it is there for: both sides naming the
		-- same cast is an answer, and that one is undone.
		local said = landThenRefuse("Cast-landed", "Cast-landed")
		if not said then
			fail(scenario, "SKIPPED -- the press did not settle (the same guid on both)")
		elseif not ns.owed[name] then
			fail(scenario, "a refusal naming the very cast that settled was ignored")
		end
		ns.Prompt.ShowOutcome = realShow
	end
	wipe(ns.owed)
	wipe(ns.tried)
	ns.pendingClick = nil
end
Mock.reset()

-- ------------------------------------------------------------------ 229
-- A buff that lands after an unrelated error is not left standing as a miss.
--
-- An error in the moment after a press takes back what the press wrote and
-- says so at once, in the game's words: "Anna was not buffed -- the game said:
-- Your bags are full." The record stays parked in case the cast goes out after
-- all, and when it did, the settle put the blocks back, cleared the debt and
-- told the panel the buff went out. Chat only ever spoke again for an inferred
-- repayment, though, so for a stranger, and for somebody owed whom the client
-- named, the last thing chat said about them was that they had not been
-- buffed, or were still owed.
Mock.reset()
ns = load("a buff that lands after an unrelated error is not left as a miss")
if ns then
	local scenario = "a buff that lands after an unrelated error is not left as a miss"
	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.verbose = true

	local buff = ns.CastableBuffs()[1]
	if not buff then
		fail(scenario, "SKIPPED -- nothing castable to press with")
	else
		local spell = buff.ranks[1]
		local name = "Anna Aim"
		for _, case in ipairs({
			{ owed = false, named = true, label = "a stranger the client named" },
			{ owed = false, named = false, label = "a stranger the client did not name" },
			{ owed = true, named = true, label = "somebody owed the client named" },
			{ owed = true, named = false, label = "somebody owed the client did not name" },
		}) do
			Mock.advance(5)
			wipe(ns.owed)
			wipe(ns.tried)
			if case.owed then ns.owed[name] = { expires = GetTime() + 100, at = GetTime() } end
			ns.pendingClick = { name = name, at = GetTime(), buffKey = buff.key,
				selfCast = false, targeted = true }
			Mock.printed = {}
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "Your bags are full.")
			Mock.advance(0.1)
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", case.named and name or nil, "Cast-1", spell)
			local last, repaid = nil, 0
			for _, line in ipairs(Mock.printed) do
				if line:find(name, 1, true) then last = line end
				if line:find("counted as repaid", 1, true) then repaid = repaid + 1 end
			end
			if ns.pendingClick or (case.owed and ns.owed[name]) then
				fail(scenario, "SKIPPED -- the cast did not settle (" .. case.label .. ")")
			elseif not last then
				fail(scenario, "SKIPPED -- the error said nothing about Anna (" .. case.label .. ")")
			elseif last:find("was not buffed", 1, true) or last:find("still owed", 1, true) then
				fail(scenario, ("chat was left saying the buff failed after it went out (%s): %s")
					:format(case.label, last))
			elseif repaid > 1 then
				fail(scenario, ("chat said the favour was repaid %d times (%s)"):format(
					repaid, case.label))
			end
		end
	end
	wipe(ns.owed)
	wipe(ns.tried)
	ns.pendingClick = nil
end
Mock.reset()

-- ------------------------------------------------------------------ 230
-- A cast off the global cooldown does not hold the prompt.
--
-- Every cast the player sent armed a second and a half of "not ready", because
-- the global cooldown was tracked rather than read. A healthstone, a potion, a
-- trinket, Counterspell or Presence of Mind report no cooldown of their own or a
-- long one, and both fell back to the guess. Out of combat that disarmed a
-- press made a moment later for nothing. In a fight it was worse: the frozen
-- macro went out anyway and landed, but the press had been set aside as turned
-- away, so nothing was filed, the debt stayed, and the same person was cast at
-- again after the fight. The client names the global cooldown itself -- spell
-- 61304, the same for every class -- so it is read where it will answer.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("a cast off the global cooldown does not hold the prompt")
if ns then
	local scenario = "a cast off the global cooldown does not hold the prompt"
	freshPrompt(ns, scenario)
	local idle = { startTime = 0, duration = 0, isActive = false }

	-- Out of combat, a press a moment after each of them.
	for _, case in ipairs({
		{ id = 6262, cd = 0, label = "a healthstone" },
		{ id = 2139, cd = 24, label = "Counterspell" },
		{ id = 424242, label = "a spell the client says nothing about" },
	}) do
		clearClicks(ns)
		Mock.spellCooldowns = { [61304] = idle }
		if case.cd then Mock.spellCooldowns[case.id] = case.cd end
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", case.id)
		Mock.advance(0.3)
		if not ns.CastReady() then
			fail(scenario, "the client said the global cooldown was idle, and a press after "
				.. case.label .. " was held anyway")
		end
		local ran = pressButton(ns)
		if not (ran and ns.pendingClick) then
			fail(scenario, "a press just after " .. case.label .. " cast nothing and filed nothing")
		end
	end

	-- Where the global cooldown will not be read, a spell that says it is off
	-- it still holds nothing -- and one that says nothing either way keeps the
	-- guess, which is what stops a press being refused.
	clearClicks(ns)
	Mock.spellCooldowns = { [6262] = { duration = 0, isOnGCD = false } }
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 6262)
	Mock.advance(0.3)
	if not ns.CastReady() then
		fail(scenario, "a spell the client says is off the global cooldown still held the prompt")
	end
	clearClicks(ns)
	Mock.spellCooldowns = { [6262] = 0 }
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 6262)
	Mock.advance(0.3)
	if ns.CastReady() then
		fail(scenario, "with nothing readable, the one-and-a-half-second guess was dropped")
	end

	-- A spell on the global cooldown is still held, by the client's own figure.
	clearClicks(ns)
	Mock.spellCooldowns = { [61304] = { startTime = GetTime(), duration = 1.5, isActive = true } }
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-hand", 116)
	Mock.advance(0.3)
	if ns.CastReady() then
		fail(scenario, "a Frostbolt's global cooldown was still running and the press was allowed")
	end
	if pressButton(ns) or ns.pendingClick then
		fail(scenario, "a press inside a running global cooldown reached the server")
	end

	-- And in a fight: the press after a healthstone is filed, so the cast it
	-- sends settles it.
	clearClicks(ns)
	Mock.spellCooldowns = { [61304] = idle, [6262] = 0 }
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local entry = ns.BuildQueue()[1]
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	if not (entry and entry.name == "Anna Aim" and entry.buff) then
		fail(scenario, "SKIPPED -- Anna was not the one offered")
	else
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 6262)
		Mock.advance(0.3)
		pressButton(ns)
		if not ns.pendingClick then
			fail(scenario, "in a fight, a press just after a healthstone was set aside as turned"
				.. " away, so the buff it casts is never counted")
		else
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-press", entry.buff.ranks[1])
			if ns.owed["Anna Aim"] then
				fail(scenario, "in a fight, the buff went out and Anna is still owed")
			end
			local held = ns.tried["Anna Aim\0" .. entry.buff.key]
			if not (held and held > GetTime() + 5) then
				fail(scenario, "in a fight, the buff went out and nothing holds Anna off the prompt")
			end
		end
	end
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 231
-- A press the game has not answered yet is not announced as a miss.
--
-- A second press arriving while the first still waits for the game abandons the
-- first as unknown, and unknown is not the same as failed -- the code says so
-- in as many words. The chat line said "was not buffed" regardless, of anybody
-- not owed. In a fight the first press, queued inside the spell-queue window,
-- then goes out and lands on the same frozen person, and nothing ever took the
-- line back.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
ns = load("an unanswered press is not called a miss")
if ns then
	local scenario = "an unanswered press is not called a miss"
	freshPrompt(ns, scenario)
	ns.addon:Tick()
	local entry = ns.BuildQueue()[1]
	if not (entry and entry.name == "Anna Aim" and entry.buff) then
		fail(scenario, "SKIPPED -- Anna was not the one offered")
	else
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		-- Something cast by hand, so the first press lands in the last stretch
		-- of its cooldown and is queued.
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-hand", 116)
		Mock.advance(1.15)
		pressButton(ns)
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the first press was not filed")
		else
			Mock.advance(0.3)
			Mock.printed = {}
			pressButton(ns)
			local said = table.concat(Mock.printed, "\n")
			if said:find("was not buffed", 1, true) then
				fail(scenario, "a press the game had not answered yet was announced as a miss: "
					.. said)
			end
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-queued", entry.buff.ranks[1])
			if ns.pendingClick then
				fail(scenario, "the queued cast did not settle the press it landed for")
			end
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 232
-- The repaid line for a shout names the shout.
--
-- It read "our spell went out, but a selfCast buff has no target at all", on
-- every repayment a warrior makes, with verbose on by default. selfCast is the
-- name of a field in Buffs.lua, and means nothing to the person reading chat.
Mock.reset()
Mock.class = "WARRIOR"
-- Battle Shout is partyOnly, so this path only exists in a group.
Mock.groupSize = 3
ns = load("the repaid line for a shout names the shout")
if ns then
	local scenario = "the repaid line for a shout names the shout"
	local known = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	Mock.advance(60)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.verbose = true

	local entry = ns.BuildQueue()[1]
	if not (entry and entry.buff and entry.buff.selfCast) then
		fail(scenario, "SKIPPED -- Battle Shout was not what came up")
	else
		local name = entry.name
		local button = ns.Prompt:GetButton()
		ns.pendingClick = nil
		ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		local post = button.scripts.PostClick
		if post then pcall(post, button, "LeftButton", true) end
		if not (ns.pendingClick and ns.pendingClick.withinShout) then
			fail(scenario, "SKIPPED -- no press filed, or nothing measured them in earshot")
		else
			Mock.printed = {}
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Mort Defrette", nil,
				ns.FindBuff("WARRIOR", entry.buff.key).ranks[1])
			local said = table.concat(Mock.printed, "\n")
			if ns.owed[name] then
				fail(scenario, "SKIPPED -- the shout did not settle the debt")
			elseif said:find("selfCast", 1, true) then
				fail(scenario, "chat showed the player a name from the code: " .. said)
			elseif not said:find("Battle Shout", 1, true) then
				fail(scenario, "the repaid line does not say which spell it means: " .. said)
			end
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
	wipe(ns.owed)
	ns.pendingClick = nil
end
Mock.reset()

-- ------------------------------------------------------------------ 233
-- A press made while the red flash is still up goes to whoever it names.
--
-- The flash about a refused press is written over the name line, and it only
-- ever came off at the next repaint -- up to a scan later. The press rule
-- stopped believing it after six tenths of a second all the same, and went back
-- to the entry painted underneath: the next person, whom the refusal had
-- already armed. So a press while the panel still read "could not buff Anna"
-- cast at, and spoke to, Bert, and nothing in chat said so. With the queue
-- emptied by the refusal it was worse: the rule then named nobody at all, and
-- anybody who walked up in that moment was cast at the same way.
Mock.reset()
local seen = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }
restoreUnits = strangers(seen)
ns = load("a press under an old flash goes to whoever it names")
if ns then
	local scenario = "a press under an old flash goes to whoever it names"
	freshPrompt(ns, scenario)
	local nameLine = ns.Prompt:Regions().name
	for _, case in ipairs({ "Bert queued", "Bert walks up", "the flash times out" }) do
		clearClicks(ns)
		-- Only what this case parks. The lifecycle leaves timers of its own
		-- behind -- the first-login preview among them -- and running those
		-- puts a mock-up on the panel.
		wipe(Mock.timers)
		local arrives = case == "Bert walks up"
		if arrives then seen.nameplate2 = nil end
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local first = pressButton(ns)
		ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
		if case == "the flash times out" then
			-- Nothing but the clock: no scan lands before the next press.
			Mock.runTimers(0.7)
			local named = tostring(nameLine:GetText())
			if named:find("could not buff", 1, true) then
				fail(scenario, "the red flash outlived its own six tenths of a second and"
					.. " waited for a scan to take it off: " .. named)
			elseif not named:find("Bert Beside", 1, true) then
				fail(scenario, "SKIPPED -- the flash came off onto something other than Bert: "
					.. named)
			end
		else
			-- A scan under the flash, then the press after it has timed out.
			Mock.advance(0.35)
			ns.addon:Tick()
			Mock.advance(0.3)
			-- Walking up is a nameplate arriving, which is how the queue hears of it.
			if arrives then
				seen.nameplate2 = { "Bert", "Beside" }
				ns.nameplateUnits["nameplate2"] = true
			end
			local named = tostring(nameLine:GetText())
			if not (first and first:find("Anna Aim", 1, true) and named:find("Anna Aim", 1, true)) then
				fail(scenario, "SKIPPED -- no red flash about Anna to press under (" .. case .. "): "
					.. named)
			else
				Mock.printed = {}
				local ran = pressButton(ns)
				if ran and ran:find("Bert Beside", 1, true) then
					fail(scenario, ("a press on a panel reading %q cast at Bert (%s): %s")
						:format(named, case, (ran:gsub("\n", " / "))))
				end
				if ns.pendingClick and ns.pendingClick.name == "Bert Beside" then
					fail(scenario, "a press was filed against Bert under a flash naming Anna ("
						.. case .. ")")
				end
			end
		end
		seen.nameplate2 = { "Bert", "Beside" }
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 234
-- A right-click under the red flash skips the person the flash names.
--
-- The skip acted on whoever was armed underneath -- the next person, whom the
-- refusal had already moved the button on to. So Bert was declined for the full
-- retry cooldown with chat saying "skipping Bert", and Anna, the one on screen,
-- came straight back when her two-second block ran out. With nobody else
-- queued the button underneath was empty, and the right-click did nothing and
-- said nothing at all.
Mock.reset()
local seen = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }
restoreUnits = strangers(seen)
ns = load("a right-click under the flash skips who it names")
if ns then
	local scenario = "a right-click under the flash skips who it names"
	freshPrompt(ns, scenario)
	local button = ns.Prompt:GetButton()
	for _, case in ipairs({ "Anna and Bert", "Anna alone" }) do
		clearClicks(ns)
		if case == "Anna alone" then seen.nameplate2 = nil end
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local first = pressButton(ns)
		ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
		Mock.advance(0.3)
		local named = tostring(ns.Prompt:Regions().name:GetText())
		if not (first and first:find("Anna Aim", 1, true) and named:find("could not buff", 1, true)) then
			fail(scenario, "SKIPPED -- no red flash about Anna to right-click (" .. case .. ")")
		else
			Mock.printed = {}
			pressButton(ns, "RightButton")
			local said = table.concat(Mock.printed, "\n")
			if said:find("skipping |cffffffffBert", 1, true) or ns.IsBlocked("Bert Beside") then
				fail(scenario, "a right-click on a flash naming Anna skipped Bert instead: " .. said)
			end
			if not said:find("Anna", 1, true) then
				fail(scenario, "a right-click on a flash naming Anna said nothing about her ("
					.. case .. "): " .. said)
			end
			Mock.advance(2.2)
			ns.addon:Tick()
			local armed = tostring(button:GetAttribute("macrotext1") or "")
			if armed:find("Anna Aim", 1, true) then
				fail(scenario, "Anna was offered again two seconds after being skipped (" .. case .. ")")
			end
		end
		seen.nameplate2 = { "Bert", "Beside" }
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 235
-- A press on a prompt still naming somebody is never silently empty.
--
-- The fuse that keeps a panel up while the queue is briefly empty is lit by a
-- scan, and the press asked the clock whether it was burning. So a press in the
-- moment between somebody stepping out of range and the next scan noticing --
-- no fuse lit yet -- and a press after the fuse had burnt out but before the
-- scan that takes the panel down, both disarmed a visible prompt that was still
-- naming Petra. The click cast nothing and said nothing, which is the silent
-- failure the fuse was added to avoid.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Petra", "Stonewell" } })
ns = load("a press on a named prompt is never silently empty")
if ns then
	local scenario = "a press on a named prompt is never silently empty"
	freshPrompt(ns, scenario)
	local button = ns.Prompt:GetButton()
	for _, case in ipairs({ "before any scan", "after the fuse", "the fuse runs out" }) do
		clearClicks(ns)
		-- Only what this case parks. The lifecycle leaves timers of its own
		-- behind -- the first-login preview among them -- and running those
		-- puts a mock-up on the panel.
		wipe(Mock.timers)
		Mock.inRange = true
		ns.addon:Tick()
		Mock.inRange = false
		if case ~= "before any scan" then
			-- A scan lights the fuse.
			Mock.advance(0.1)
			ns.addon:Tick()
		end
		if not (button:IsShown() and tostring(button:GetAttribute("macrotext1") or ""):find("Petra", 1, true)) then
			fail(scenario, "SKIPPED -- Petra was not on the panel (" .. case .. ")")
		elseif case == "the fuse runs out" then
			-- Nothing but the clock: the panel comes down when the fuse ends.
			Mock.runTimers(0.85)
			if button:IsShown() then
				fail(scenario, "the fuse burnt out and the panel stayed up naming Petra until a"
					.. " scan got round to it")
			end
		else
			Mock.advance(case == "after the fuse" and 0.8 or 0.1)
			Mock.printed = {}
			local ran = pressButton(ns)
			if button:IsShown() and not (ran and ran:find("Petra", 1, true)) then
				fail(scenario, ("a press on a panel still naming Petra did nothing and said"
					.. " nothing (%s): %s"):format(case, table.concat(Mock.printed, " | ")))
			end
		end
	end
	Mock.inRange = true
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 236
-- A press while switched off says it is switched off.
--
-- /manners off and a right-click on the minimap button take the panel down,
-- and a key bound to the prompt still reaches it. The press found the panel
-- hidden and said "nobody to buff right now." -- often untrue, since the queue
-- is built whatever the switch says, and silent about the one thing that
-- actually explains the empty prompt.
Mock.reset()
ns = load("a press while switched off says so")
if ns then
	local scenario = "a press while switched off says so"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local button = ns.Prompt:GetButton()
	for _, how in ipairs({ "/manners off", "the minimap button" }) do
		ns.addon:HandleSlash("on")
		if how == "/manners off" then
			ns.addon:HandleSlash("off")
		elseif Mock.broker and Mock.broker.OnClick then
			Mock.broker.OnClick(nil, "RightButton")
		end
		if ns.db.profile.enabled or button:IsShown() then
			fail(scenario, "SKIPPED -- " .. how .. " did not switch the prompt off")
		else
			Mock.advance(1)
			Mock.printed = {}
			pressButton(ns)
			local said = table.concat(Mock.printed, "\n")
			if said:find("nobody to buff", 1, true) then
				fail(scenario, "a press after " .. how .. " said nobody wanted a buff: " .. said)
			end
			if not said:find("switched off", 1, true) then
				fail(scenario, "a press after " .. how .. " never said Manners is switched off: " .. said)
			end
		end
	end
	ns.addon:HandleSlash("on")
end
Mock.reset()

-- ------------------------------------------------------------------ 237
-- Buffing the player you already have targeted leaves them targeted.
--
-- The target is walked first, so a stranger you have clicked on is offered
-- through the target token. /target on somebody already targeted changes
-- nothing, so the last-target slot still holds whoever came before them -- a
-- mob, usually -- and the /targetlasttarget on the end of the macro switched to
-- it, while the tooltip promised to hand your own target back.
Mock.reset()
local seen = { target = { "Anna", "Aim" } }
restoreUnits = strangers(seen)
ns = load("buffing your own target leaves them targeted")
if ns then
	local scenario = "buffing your own target leaves them targeted"
	freshPrompt(ns, scenario)
	ns.db.profile.filters.restoreTarget = true
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	local armed = tostring(button:GetAttribute("macrotext1") or "")
	local top = ns.BuildQueue()[1]
	if not (top and top.unit == "target" and armed:find("Anna Aim", 1, true)) then
		fail(scenario, "SKIPPED -- Anna was not offered through the target token: " .. armed)
	else
		if armed:find("/targetlasttarget", 1, true) then
			fail(scenario, "the macro for your own target hands the target to whoever came"
				.. " before: " .. (armed:gsub("\n", " / ")))
		end
		button.scripts.OnEnter(button)
		local tip = table.concat(Mock.tooltip, "\n")
		if tip:find("Hands your own target back", 1, true) then
			fail(scenario, "the tooltip promises to hand back a target the macro keeps")
		end
	end

	-- A stranger off a nameplate is still handed back.
	seen.target = nil
	seen.nameplate1 = { "Bert", "Beside" }
	clearClicks(ns)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	local other = tostring(button:GetAttribute("macrotext1") or "")
	if not (other:find("Bert Beside", 1, true) and other:find("/targetlasttarget", 1, true)) then
		fail(scenario, "a stranger off a nameplate no longer gets your target handed back: "
			.. (other:gsub("\n", " / ")))
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 238
-- A drag that never started does not end.
--
-- OnDragStart refuses a locked prompt and a fight, but the release still
-- arrives: it stopped a move on the secure button -- a call the client refuses
-- during lockdown -- saved the position and said "moved and locked." for a
-- click on a locked prompt that slid a few pixels. And a drag held into a pull
-- was released in combat, where the same call is refused.
Mock.reset()
ns = load("a drag that never started does not end")
if ns then
	local scenario = "a drag that never started does not end"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local button = Mock.protect(ns.Prompt:GetButton())
	local p = ns.db.profile.prompt
	local stops = 0
	local inner = button.StopMovingOrSizing
	button.StopMovingOrSizing = function(self, ...)
		stops = stops + 1
		return inner(self, ...)
	end
	local function stoppedInCombat()
		for _, name in ipairs(Mock.protectedCalls) do
			if name == "StopMovingOrSizing" then return true end
		end
		return false
	end

	-- A locked prompt, out of combat: a click that slid.
	p.locked = true
	Mock.printed = {}
	button.scripts.OnDragStart(button)
	button.scripts.OnDragStop(button)
	if stops > 0 or table.concat(Mock.printed, "\n"):find("moved and locked", 1, true) then
		fail(scenario, "a click on a locked prompt that slid a few pixels ended a move and"
			.. " said the prompt was moved")
	end

	-- A locked prompt in a fight.
	Mock.inCombat = true
	Mock.protectedCalls = {}
	button.scripts.OnDragStart(button)
	button.scripts.OnDragStop(button)
	if stoppedInCombat() then
		fail(scenario, "a release in combat stopped a move on the secure button")
	end
	Mock.inCombat = false

	-- Unlocked, picked up, and still held when the pull starts.
	p.locked = false
	ns.Prompt:Refresh()
	stops = 0
	p.x = 999
	button.scripts.OnDragStart(button)
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.protectedCalls = {}
	button.scripts.OnDragStop(button)
	if stoppedInCombat() then
		fail(scenario, "a drag held into a pull was ended in combat on the secure button")
	end
	if p.x == 999 then
		fail(scenario, "a drag held into a pull never had its position saved")
	end
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()

	-- And an ordinary drag still saves and says so.
	p.locked = false
	ns.Prompt:Refresh()
	p.x = 999
	Mock.printed = {}
	button.scripts.OnDragStart(button)
	button.scripts.OnDragStop(button)
	if p.x == 999 or not p.locked
		or not table.concat(Mock.printed, "\n"):find("moved and locked", 1, true) then
		fail(scenario, "SKIPPED -- an ordinary drag no longer saves, locks and says so")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 239
-- The open tooltip follows what it describes, not only who.
--
-- A tooltip left open is kept honest by a check a few times a second, and the
-- check only asked whether the name had changed. So the same person moving on
-- to a different buff -- a priest's walk from Fortitude to Divine Spirit once
-- the first one settles -- left it naming Fortitude over a button that would
-- cast Spirit, and a passer-by who then buffed you stayed "nearby and missing
-- it" rather than "buffed you". And when the button was disarmed altogether the
-- tooltip stayed up saying "Click to cast" over a press that would do nothing.
--
-- The mock tooltip forgets who owns it, so it is taught to remember here: the
-- whole defect lives in the question "is this tooltip mine?".
Mock.reset()
ns = load("the open tooltip follows the buff and the reason, and goes when disarmed")
if ns then
	local scenario = "the open tooltip follows the buff and the reason, and goes when disarmed"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	local spirit = ns.FindBuff("PRIEST", "spirit")
	if not (template and template.buff and spirit and spirit.key ~= template.buff.key) then
		fail(scenario, "SKIPPED -- no candidate, or no second buff to walk on to")
	else
		local owner
		local realSetOwner, realIsOwned, realHide = GameTooltip.SetOwner, GameTooltip.IsOwned,
			GameTooltip.Hide
		GameTooltip.SetOwner = function(_, frame) owner = frame Mock.tooltip = {} end
		GameTooltip.IsOwned = function(_, frame) return owner ~= nil and owner == frame end
		GameTooltip.Hide = function() owner = nil end

		local function anna(edit)
			local entry = {}
			for k, v in pairs(template) do entry[k] = v end
			entry.name, entry.short, entry.reason, entry.priority = "Anna Aim", "Anna Aim", "nearby", 5
			entry.targetName = ns.TargetName(entry.name)
			entry.unit = "nameplate1"
			entry.known, entry.checked, entry.remaining = false, true, nil
			if edit then edit(entry) end
			return entry
		end
		local queue = { anna() }
		ns.BuildQueue = function() return queue end
		wipe(ns.tried)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()

		local button = ns.Prompt:GetButton()
		local function tip() return table.concat(Mock.tooltip, "\n") end
		local function tick() button.scripts.OnUpdate(button, 0.3) end
		button.scripts.OnEnter(button)
		tick()
		if not tip():find(ns.BuffName(template.buff), 1, true) then
			fail(scenario, "SKIPPED -- the tooltip never described Anna's first buff: "
				.. (tip():gsub("\n", " / ")))
		else
			-- A: the walk moves on to the next buff for the same person.
			queue = { anna(function(e) e.buff = spirit end) }
			ns.Prompt:Refresh()
			tick()
			local line = "Anna Aim\t" .. ns.BuffName(spirit)
			if not tip():find(line, 1, true) then
				fail(scenario, "the walk moved Anna on to " .. ns.BuffName(spirit) .. " and the open"
					.. " tooltip went on describing the buff before it: " .. (tip():gsub("\n", " / ")))
			end

			-- B: the passer-by turns out to have buffed you.
			owe(ns, "Anna Aim")
			queue = { anna(function(e) e.buff = spirit e.reason = "owed" e.priority = 1 end) }
			ns.Prompt:Refresh()
			tick()
			if not tip():find("Buffed you", 1, true) then
				fail(scenario, "Anna became somebody you owe and the open tooltip still gave the"
					.. " passer-by's reason: " .. (tip():gsub("\n", " / ")))
			end

			-- C: nothing armed, and the panel still up.
			ns.Prompt:ApplyTarget(nil)
			button:Show()
			tick()
			if GameTooltip:IsOwned(button) then
				fail(scenario, "the button was disarmed and its tooltip stayed up saying"
					.. " \"Click to cast\"")
			end
		end
		GameTooltip.SetOwner, GameTooltip.IsOwned, GameTooltip.Hide = realSetOwner, realIsOwned,
			realHide
	end
	wipe(ns.owed)
end
Mock.reset()

-- ------------------------------------------------------------------ 240
-- A press the global cooldown turns away does not re-roll the spoken line.
--
-- The press is disarmed while the cooldown runs, and the disarm wiped the roll
-- along with the macro. The same press then put the person back on the button,
-- and putting them back rolled a fresh line out of the pool -- so the tooltip,
-- which had not changed its mind about who, went on quoting the old line, and
-- the next press sent a different one. With a pool of four that was most
-- presses made a moment too early.
--
-- math.random is a counter here, as in scenario 84, so the two lines differ
-- every time rather than three times in four.
Mock.reset()
ns = load("a press turned away by the cooldown keeps the quoted line")
if ns then
	local scenario = "a press turned away by the cooldown keeps the quoted line"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local ana = {}
		for k, v in pairs(template) do ana[k] = v end
		ana.name, ana.short, ana.reason, ana.priority = "Ana Field", "Ana Field", "owed", 1
		ana.targetName = ns.TargetName(ana.name)
		ana.unit = "nameplate1"
		ns.BuildQueue = function() return { ana } end

		local db = ns.db.profile
		db.speech.enabled = true
		db.speech.onlyWhenReturning = false
		db.speech.channel = "SAY"
		db.speech.phrases = "alpha\nbravo\ncharlie\ndelta"

		local realRandom, realReady = math.random, ns.CastReady
		local rolls = 0
		math.random = function(n) rolls = rolls + 1 return ((rolls - 1) % n) + 1 end

		local button = ns.Prompt:GetButton()
		wipe(ns.tried)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		button.scripts.OnEnter(button)
		local quoted
		for _, line in ipairs(Mock.tooltip) do
			quoted = line:match("^Says: |cffffffff(.-)|r$") or quoted
		end

		-- Pressed a moment too early: turned away, and put back.
		Mock.advance(1)
		ns.CastReady = function() return false, 1 end
		pressButton(ns)
		ns.CastReady = realReady

		-- And pressed again once it is ready.
		Mock.advance(1)
		local ran = pressButton(ns)
		local said = tostring(ran or ""):match("/say ([^\n]+)")
		if not (quoted and said) then
			fail(scenario, "SKIPPED -- no spoken line to compare (" .. tostring(quoted)
				.. " / " .. tostring(said) .. ")")
		elseif quoted ~= said then
			fail(scenario, "the tooltip quoted |" .. quoted .. "|, a press inside the cooldown"
				.. " was turned away, and the next press said |" .. said .. "|")
		end
		math.random = realRandom
	end
	wipe(ns.owed)
end
Mock.reset()

-- ------------------------------------------------------------------ 241
-- The spoken line does not change when the same person is seen another way.
--
-- The roll was kept under the same key as the macro, and that key carries the
-- unit token -- which only /manners try can use. So Anna seen through a
-- nameplate on one scan and under the cursor on the next was, as far as the
-- roll knew, somebody new: a fresh line went on the button while the tooltip
-- still quoted the old one, and a key pressed with the cursor on her sent a
-- line nobody had read.
Mock.reset()
ns = load("the spoken line survives a change of unit token")
if ns then
	local scenario = "the spoken line survives a change of unit token"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local function anna(unit)
			local entry = {}
			for k, v in pairs(template) do entry[k] = v end
			entry.name, entry.short, entry.reason, entry.priority = "Anna Aim", "Anna Aim", "owed", 1
			entry.targetName = ns.TargetName(entry.name)
			entry.unit = unit
			return entry
		end
		local seenAs = anna("nameplate1")
		ns.BuildQueue = function() return { seenAs } end

		local db = ns.db.profile
		db.speech.enabled = true
		db.speech.onlyWhenReturning = false
		db.speech.channel = "SAY"
		db.speech.phrases = "alpha\nbravo\ncharlie\ndelta"

		local realRandom = math.random
		local rolls = 0
		math.random = function(n) rolls = rolls + 1 return ((rolls - 1) % n) + 1 end

		local button = ns.Prompt:GetButton()
		wipe(ns.tried)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		button.scripts.OnEnter(button)
		local quoted
		for _, line in ipairs(Mock.tooltip) do
			quoted = line:match("^Says: |cffffffff(.-)|r$") or quoted
		end

		-- The next scan finds her under the cursor instead, and the key is
		-- pressed with it there.
		seenAs = anna("mouseover")
		Mock.advance(0.4)
		ns.Prompt:Refresh()
		Mock.advance(0.4)
		local ran = pressButton(ns)
		local said = tostring(ran or ""):match("/say ([^\n]+)")
		if not (quoted and said) then
			fail(scenario, "SKIPPED -- no spoken line to compare (" .. tostring(quoted)
				.. " / " .. tostring(said) .. ")")
		elseif quoted ~= said then
			fail(scenario, "the tooltip quoted |" .. quoted .. "| for Anna off a nameplate, and a"
				.. " press with the cursor on her said |" .. said .. "|")
		end
		math.random = realRandom
	end
	wipe(ns.owed)
end
Mock.reset()

-- ------------------------------------------------------------------ 242
-- The tooltip does not say "missing it" beside a line saying it did not look.
--
-- The reason line took the "missing it" wording whenever there was no time
-- left to quote, whatever had actually been read. With "Always offer" nothing
-- is read at all, and on a client that hides auras nothing can be -- so the
-- tooltip said "Nearby and missing it." and, one line down, "Not checking
-- whether they have it" or "Buff state unreadable", about somebody who may
-- well have been wearing it.
Mock.reset()
ns = load("the tooltip says missing only when it read missing")
if ns then
	local scenario = "the tooltip says missing only when it read missing"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.advance(60)

	local template = ns.BuildQueue()[1]
	if not template or not template.buff then
		fail(scenario, "SKIPPED -- nobody to build a candidate from")
	else
		local button = ns.Prompt:GetButton()
		local function hover(case, reason, known, checked)
			local entry = {}
			for k, v in pairs(template) do entry[k] = v end
			entry.name, entry.short, entry.reason = case, case, reason
			entry.priority = reason == "owed" and 1 or reason == "group" and 3 or 5
			entry.targetName = ns.TargetName(entry.name)
			entry.unit = "nameplate1"
			entry.known, entry.checked, entry.remaining = known, checked, nil
			-- Straight onto the button rather than through a repaint: four
			-- people of equal standing in a row would otherwise be held behind
			-- the first, which is the hold doing its job and not the subject.
			ns.Prompt:ApplyTarget(nil)
			ns.Prompt:ApplyTarget(entry)
			button:Show()
			button.scripts.OnEnter(button)
			return table.concat(Mock.tooltip, "\n")
		end

		for _, case in ipairs({
			{ "Always Nearby", "nearby", nil, false },
			{ "Always Group", "group", nil, false },
			{ "Unread Nearby", "nearby", nil, true },
		}) do
			local tip = hover(case[1], case[2], case[3], case[4])
			if not tip:find(case[1], 1, true) then
				fail(scenario, "SKIPPED -- the tooltip was not about " .. case[1] .. ": "
					.. (tip:gsub("\n", " / ")))
			elseif tip:find("missing it", 1, true) then
				fail(scenario, ("the tooltip for %s said \"missing it\" about somebody nothing was"
					.. " read for: %s"):format(case[1], (tip:gsub("\n", " / "))))
			end
		end

		-- And the wording is still there for somebody read and found without it.
		local tip = hover("Read Missing", "nearby", false, true)
		if not tip:find("missing it", 1, true) then
			fail(scenario, "somebody read and found without the buff is no longer said to be"
				.. " missing it: " .. (tip:gsub("\n", " / ")))
		end
		tip = hover("Owed Always", "owed", nil, false)
		if not tip:find("Buffed you", 1, true) then
			fail(scenario, "somebody owed is no longer said to have buffed you: "
				.. (tip:gsub("\n", " / ")))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 243
-- /manners test in a fight is refused, not announced.
--
-- Nothing asked about the fight. A panel the fight found hidden cannot be put
-- up, so the preview was painted on a frame nobody could see, while chat said
-- "preview on" and, twenty seconds later, "preview off -- timed out". Worse, a
-- panel armed at a real person kept its macro -- the fight froze it -- and the
-- preview painted "PREVIEW" and a pulse over it, so a press cast at Petra from
-- under a mock-up. The greeting already refuses a fight for the same reason.
Mock.reset()
restoreUnits = strangers({ nameplate1 = { "Petra", "Stonewell" } })
ns = load("the preview is refused in a fight")
if ns then
	local scenario = "the preview is refused in a fight"
	freshPrompt(ns, scenario)
	local button = ns.Prompt:GetButton()

	-- A panel the fight found hidden.
	button:Hide()
	Mock.inCombat = true
	Mock.printed = {}
	ns.addon:HandleSlash("test")
	local said = table.concat(Mock.printed, "\n")
	if ns.Prompt:InTest() or said:find("preview on", 1, true) then
		fail(scenario, "a preview was started in a fight over a panel that cannot be shown: "
			.. said)
	end
	if not said:find("not during a fight", 1, true) then
		fail(scenario, "/manners test in a fight never said why nothing appeared: " .. said)
	end
	Mock.advance(24)
	Mock.printed = {}
	ns.Prompt:Refresh()
	if table.concat(Mock.printed, "\n"):find("timed out", 1, true) then
		fail(scenario, "a preview nobody could see timed out in chat")
	end
	if ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
	Mock.inCombat = false

	-- A panel armed at Petra when the fight starts.
	ns.addon:Tick()
	if not tostring(button:GetAttribute("macrotext1") or ""):find("Petra", 1, true) then
		fail(scenario, "SKIPPED -- Petra was not armed before the fight")
	else
		Mock.inCombat = true
		ns.addon:HandleSlash("test")
		if ns.Prompt:InTest() then
			fail(scenario, "a preview was painted over a macro the fight froze at Petra, which a"
				.. " press still casts")
			ns.Prompt:ToggleTest()
		end
		if not tostring(ns.Prompt:PanelName()):find("Petra", 1, true) then
			fail(scenario, "the panel stopped naming Petra over a macro still armed at her: "
				.. tostring(ns.Prompt:PanelName()))
		end
		-- The options page's button is the same command by another door.
		local test = ns.optionsTable and ns.optionsTable.args.appearance.args.test
		if not (test and type(test.disabled) == "function" and test.disabled()) then
			fail(scenario, "the options page still offers Preview in the middle of a fight")
		end
		Mock.inCombat = false
		if test and type(test.disabled) == "function" and test.disabled() then
			fail(scenario, "the options page's Preview stayed greyed out after the fight")
		end
	end
end
Mock.inCombat = false
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 244
-- /manners test with somebody real on the prompt says so once.
--
-- The refresh inside the command stood the preview aside and said "preview off
-- -- somebody real turned up", and the command then explained the same thing a
-- second time in other words, about a preview that had never been on screen.
Mock.reset()
Mock.unitNames = { nameplate1 = { "Close", "By" } }
ns = load("/manners test with somebody real says so once")
if ns then
	local scenario = "/manners test with somebody real says so once"
	drive(scenario, ns)
	settle(ns)
	ns.Prompt:ExitTest()
	ns.addon:Tick()
	Mock.optionsOpen = false
	if #ns.BuildQueue() == 0 then
		fail(scenario, "SKIPPED -- nobody real on the prompt")
	else
		Mock.printed = {}
		ns.addon:HandleSlash("test")
		local said = table.concat(Mock.printed, "\n")
		if #Mock.printed ~= 1 or said:find("preview off", 1, true)
			or not said:find("nothing to preview", 1, true) then
			fail(scenario, ("/manners test said %d lines about a preview that never started: %s")
				:format(#Mock.printed, (said:gsub("\n", " | "))))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 245
-- /manners test and /manners welcome redraw the Preview button.
--
-- The options page's button reads "Preview" or "Stop preview" from whether one
-- is running, and AceConfig only asks while it is drawing. The slash commands
-- that start and stop one never asked it to draw, so with the window open the
-- button went on offering "Preview" over a running preview -- and pressing it
-- stopped the preview.
Mock.reset()
ns = load("the preview button follows the slash commands")
if ns then
	local scenario = "the preview button follows the slash commands"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.advance(60)
	local test = ns.optionsTable and ns.optionsTable.args.appearance.args.test
	local registry = LibStub("AceConfigRegistry-3.0")
	if not (test and type(test.name) == "function" and registry and registry.NotifyChange) then
		fail(scenario, "SKIPPED -- no Preview button or no repaint to watch")
	else
		-- What the page last drew: the label as it stood at the last repaint.
		local drawn = test.name()
		local realNotify = registry.NotifyChange
		registry.NotifyChange = function(...)
			drawn = test.name()
			return realNotify(...)
		end
		Mock.optionsOpen = true
		local function check(what)
			local want = ns.Prompt:InTest() and "Stop preview" or "Preview"
			if drawn ~= want then
				fail(scenario, ("after %s the open page's button reads %q with the preview %s")
					:format(what, drawn, ns.Prompt:InTest() and "running" or "stopped"))
			end
		end
		withEmptyPrompt(function()
			ns.addon:HandleSlash("test")
			if not ns.Prompt:InTest() then
				fail(scenario, "SKIPPED -- /manners test did not start a preview")
			end
			check("/manners test")
			ns.addon:HandleSlash("test")
			check("/manners test again")
			ns.addon:HandleSlash("welcome")
			if not ns.Prompt:InTest() then
				fail(scenario, "SKIPPED -- /manners welcome did not start a preview")
			end
			check("/manners welcome")
			if ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
			check("stopping the preview")
		end)
		registry.NotifyChange = realNotify
		Mock.optionsOpen = false
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 246
-- The Scale slider does not move the prompt, and a place means one place.
--
-- The client reads SetPoint's offsets in the frame's own scaled units, and the
-- prompt was placed with its scale already set and the stored offsets passed
-- straight through. So every offset was multiplied by the scale: at Scale 2,
-- "Above the action bars" put the prompt's bottom edge 600 up instead of 300,
-- at Scale 3 "Under the minimap" ended up most of the way down the screen, and
-- Reset position did the same -- while the dropdown went on naming the preset,
-- because the numbers were right. A prompt dragged at Scale 2 moved when the
-- scale went back to 1, because the drag saved offsets in those same scaled
-- units.
Mock.reset()
ns = load("the scale does not move the prompt")
if ns then
	local scenario = "the scale does not move the prompt"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.geometry = { width = 1366, height = 768 }
	local button = ns.Prompt:GetButton()
	local p = ns.db.profile.prompt
	local app = ns.optionsTable and ns.optionsTable.args.appearance.args
	local function round(v) return math.floor(v + 0.5) end
	local function bottomEdge()
		local _, bottom = Mock.rectUI(button)
		return round(bottom)
	end

	for _, scale in ipairs({ 1, 1.5, 2, 2.5 }) do
		p.scale = scale
		ns.ApplyPositionPreset("bars")
		if bottomEdge() ~= 300 then
			fail(scenario, ("at Scale %s \"Above the action bars\" put the bottom edge at %d,"
				.. " not 300"):format(scale, bottomEdge()))
		end
	end

	p.scale = 3
	ns.ApplyPositionPreset("minimap")
	local _, _, right, top = Mock.rectUI(button)
	if round(right) ~= 1346 or round(top) ~= 548 then
		fail(scenario, ("at Scale 3 \"Under the minimap\" put the top-right corner at %d,%d,"
			.. " not 1346,548"):format(round(right), round(top)))
	end

	if not (app and app.reset and app.scale) then
		fail(scenario, "SKIPPED -- no Reset position button or Scale slider on the page")
	else
		p.scale = 2
		ns.ApplyPositionPreset("centre")
		app.reset.func()
		if bottomEdge() ~= 300 then
			fail(scenario, ("at Scale 2 Reset position put the bottom edge at %d, not 300")
				:format(bottomEdge()))
		end

		-- Moved with the slider, from where the default puts it.
		app.scale.set({ "scale" }, 1.5)
		if bottomEdge() ~= 300 then
			fail(scenario, ("moving the Scale slider moved the prompt: its bottom edge went"
				.. " from 300 to %d"):format(bottomEdge()))
		end

		-- A drag at Scale 2 to a bottom edge of 300. The client leaves the frame
		-- anchored with offsets in its own scaled units, which is half that.
		app.scale.set({ "scale" }, 2)
		p.locked = false
		ns.Prompt:Refresh()
		button.scripts.OnDragStart(button)
		button.points = { { "BOTTOM", UIParent, "BOTTOM", 0, 150 } }
		button.scripts.OnDragStop(button)
		if bottomEdge() ~= 300 then
			fail(scenario, ("SKIPPED -- the drop itself left the bottom edge at %d")
				:format(bottomEdge()))
		end
		app.scale.set({ "scale" }, 1)
		if bottomEdge() ~= 300 then
			fail(scenario, ("a prompt dragged at Scale 2 moved when the scale went back to 1:"
				.. " its bottom edge went from 300 to %d"):format(bottomEdge()))
		end
	end
end
Mock.reset()

-- And the prompts already on disk. Their offsets were saved in scaled units,
-- so a prompt dragged at any scale but 1 has to have them converted once or
-- it jumps on the first login after the fix. One sitting on a preset is left
-- on it: the dropdown has been naming that preset all along, and the preset
-- is where it now goes. The stamp is what stops a second login converting
-- the converted offsets again.
for _, case in ipairs({
	{ label = "dragged", y = 150, x = 40, want = { 80, 300 } },
	{ label = "on a preset", y = 300, x = 0, want = { 0, 300 } },
	{ label = "already converted", y = 150, x = 40, stamped = true, want = { 40, 150 } },
}) do
	Mock.reset()
	Mock.sv = {}
	local scenario = "a prompt saved at Scale 2 stays put (" .. case.label .. ")"
	local saved = savedProfile(scenario, function(profile)
		profile.prompt.point, profile.prompt.relPoint = "BOTTOM", "BOTTOM"
		profile.prompt.scale = 2
		profile.prompt.x, profile.prompt.y = case.x, case.y
		profile.prompt.offsetsUnscaled = case.stamped or nil
	end)
	ns = saved and load(scenario)
	local said = ns and firstLogin(ns)
	if not said then
		fail(scenario, "SKIPPED -- the session would not start")
	else
		local p = ns.db.profile.prompt
		if p.x ~= case.want[1] or p.y ~= case.want[2] then
			fail(scenario, ("offsets %d,%d saved at Scale 2 came back as %s,%s, not %d,%d")
				:format(case.x, case.y, tostring(p.x), tostring(p.y), case.want[1], case.want[2]))
		end
		-- And a second login leaves them alone.
		ns.ClampSettings()
		if p.x ~= case.want[1] or p.y ~= case.want[2] then
			fail(scenario, ("a second pass converted the offsets again, to %s,%s")
				:format(tostring(p.x), tostring(p.y)))
		end
		ns.Prompt:ExitTest()
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 247
-- The list of who is next hangs on the side with room at any scale.
--
-- The list flips above the panel when the prompt sits in the bottom third of
-- the screen. The test took the prompt's centre, which the client gives in the
-- prompt's own scaled units, and held it against the height of the screen in
-- UIParent's. So the real line was drawn at the scale times a third of the
-- screen: at Scale 2.5 a prompt four fifths of the way up hung its list above
-- itself and off the top edge, at Scale 2 one in the middle did the same, and
-- at Scale 0.5 one low on the screen hung its list off the bottom.
Mock.reset()
ns = load("the queue hangs on the side with room at any scale")
if ns then
	local scenario = "the queue hangs on the side with room at any scale"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.geometry = { width = 1366, height = 768 }
	local button = ns.Prompt:GetButton()
	local regions = ns.Prompt:Regions()
	local p = ns.db.profile.prompt
	p.showQueue = true
	p.queueRows = 3
	p.point, p.relPoint, p.x = "BOTTOM", "BOTTOM", 0
	for _, case in ipairs({
		{ scale = 1, centre = 614 },
		{ scale = 1, centre = 154 },
		{ scale = 2.5, centre = 614 },
		{ scale = 2, centre = 384 },
		{ scale = 0.5, centre = 200 },
	}) do
		p.scale = case.scale
		-- Offsets are UIParent's units, so this is where the centre lands.
		p.y = case.centre - p.height * case.scale / 2
		ns.Prompt:ApplyStyle()
		local _, bottom, _, top = Mock.rectUI(button)
		local centre = (bottom + top) / 2
		local anchor = regions.rows[1].points[1]
		local above = anchor and anchor[1] == "BOTTOMLEFT"
		local want = centre < 768 / 3
		if above and not want then
			fail(scenario, ("at Scale %s a prompt centred %d up a 768 screen hung its list"
				.. " above itself, towards the top edge, from above the bottom third")
				:format(case.scale, math.floor(centre + 0.5)))
		elseif want and not above then
			fail(scenario, ("at Scale %s a prompt centred %d up a 768 screen hung its list"
				.. " below itself, towards the bottom edge, from inside the bottom third")
				:format(case.scale, math.floor(centre + 0.5)))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 248
-- The reason colours are what their comment says they are in greyscale.
--
-- The comment over the four reason colours is the record of why they were
-- picked, and the check it tells the next person to make. It gave their greys
-- as 0.86, 0.78, 0.63 and 0.54, "no two closer than 0.09" -- figures no common
-- desaturation produces. With the weights the addon itself uses, group and
-- nearby are 0.02 apart, so anybody trusting the comment would leave a pair
-- only hue tells apart believing lightness did. Read from the source: the
-- first four figures in the comment, in the table's order, against the
-- colours the prompt actually paints, and any "no two closer than" claim
-- against the real gaps.
Mock.reset()
ns = load("the reason colours match their comment")
if ns then
	local scenario = "the reason colours match their comment"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local file = io.open(dir .. "/Prompt.lua", "r")
	local source = file and file:read("a") or ""
	if file then file:close() end
	-- The unbroken run of comment lines straight above the table.
	local before = source:match("(.-)\nlocal REASON_COLOR = {")
	local lines = {}
	for line in ((before or "") .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
	local first = #lines + 1
	while first > 1 and lines[first - 1]:match("^%-%-") do first = first - 1 end
	local block = first <= #lines and table.concat(lines, "\n", first) or nil
	if not block then
		fail(scenario, "SKIPPED -- no comment found over REASON_COLOR")
	else
		ns.db.profile.prompt.accentByReason = true
		local greys = {}
		for i, reason in ipairs({ "target", "owed", "group", "nearby" }) do
			local r, g, b = ns.Prompt:AccentColor(reason)
			greys[i] = 0.299 * r + 0.587 * g + 0.114 * b
		end
		local stated = {}
		for figure in block:gmatch("%f[%d]0%.%d%d%f[%D]") do
			stated[#stated + 1] = tonumber(figure)
		end
		for i, grey in ipairs(greys) do
			if not stated[i] or math.abs(stated[i] - grey) > 0.006 then
				fail(scenario, ("the comment gives grey %d as %s; the colour desaturates to %.3f")
					:format(i, tostring(stated[i]), grey))
			end
		end
		local claim = tonumber(block:match("closer than (0%.%d+)"))
		if claim then
			for i = 1, #greys do
				for j = i + 1, #greys do
					if math.abs(greys[i] - greys[j]) < claim then
						fail(scenario, ("the comment says no two greys are closer than %s, and"
							.. " two are %.3f apart"):format(claim, math.abs(greys[i] - greys[j])))
					end
				end
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 249
-- A preview started from the game's Settings window ends once it is shut.
--
-- Whether the page was open was asked of the canvas AddToBlizOptions made, with
-- IsShown -- the canvas's own flag. Shutting the Settings window hides the
-- window and leaves that flag set, because the client only clears it when
-- another page takes the canvas's place. So after one visit the page read as
-- open until the next: the preview's clock was pushed forward on every pass,
-- "somebody real turned up" never fired, and the prompt went on showing a
-- mock-up and casting nothing over the people who had buffed you.
Mock.reset()
ns = load("a preview from the Settings window ends when it is shut")
if ns then
	local scenario = "a preview from the Settings window ends when it is shut"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.advance(60)
	withEmptyPrompt(function()
		Mock.openSettings()
		if not ns.OptionsOpen() then
			fail(scenario, "SKIPPED -- the Settings page does not read as open while it is")
		end
		ns.Prompt:ToggleTest()
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the page's Preview button did not start a preview")
		else
			Mock.closeSettings()
			if ns.OptionsOpen() then
				fail(scenario, "with the Settings window shut, the page still reads as open")
			end
			Mock.advance(30)
			ns.Prompt:Refresh()
			if ns.Prompt:InTest() then
				fail(scenario, "the preview outlived the Settings window it was started from")
				ns.Prompt:ExitTest()
			end
		end

		-- And a later /manners test, with the window long shut, times out as
		-- any other does.
		ns.addon:HandleSlash("test")
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- /manners test did not start a preview")
		else
			Mock.advance(30)
			ns.Prompt:Refresh()
			if ns.Prompt:InTest() then
				fail(scenario, "a /manners test after a visit to the Settings page never timed out")
				ns.Prompt:ExitTest()
			end
		end
	end)

	-- Somebody real waiting ends it the moment the window is shut.
	local template = ns.BuildQueue()[1]
	if not template then
		fail(scenario, "SKIPPED -- nobody to stand in for somebody real")
	else
		local realBuild = ns.BuildQueue
		ns.BuildQueue = function() return {} end
		Mock.openSettings()
		ns.Prompt:ToggleTest()
		ns.BuildQueue = function() return { template } end
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the second preview did not start")
		else
			Mock.closeSettings()
			Mock.printed = {}
			ns.Prompt:Refresh()
			if ns.Prompt:InTest()
				or not table.concat(Mock.printed, "\n"):find("somebody real turned up", 1, true) then
				fail(scenario, "somebody real was waiting and the preview stood in front of them"
					.. " after the Settings window was shut")
			end
		end
		ns.BuildQueue = realBuild
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 250
-- The Settings fallback opens on Manners' page.
--
-- If the standalone dialog cannot open, OpenOptions falls back to the game's
-- Settings window and asks for the category by ID. It asked the canvas frame
-- for that ID, and a plain frame's ID is 0, which is no category at all -- so
-- the window came up on whatever page it was last on. AddToBlizOptions hands
-- the real ID back as its second value, in the number form this client uses or
-- the name form older ones do.
for _, id in ipairs({ 17, "Manners" }) do
	Mock.reset()
	Mock.blizCategoryID = id
	local scenario = "the Settings fallback opens on Manners (" .. type(id) .. " ID)"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local dialog = LibStub("AceConfigDialog-3.0")
		local realOpen, realSettings = dialog.Open, Settings
		local asked = {}
		Settings = { OpenToCategory = function(which) asked[#asked + 1] = which end }
		dialog.Open = function()
			error("AceConfigRegistry:ValidateOptionsTable(): Manners.args: expected a table", 0)
		end
		ns.addon:HandleSlash("options")
		if Mock.broker and Mock.broker.OnClick then
			Mock.broker.OnClick(nil, "LeftButton")
		end
		dialog.Open, Settings = realOpen, realSettings
		if #asked == 0 then
			fail(scenario, "with the dialog broken, nothing opened the Settings window at all")
		end
		for _, which in ipairs(asked) do
			if which ~= id then
				fail(scenario, ("the Settings window was asked for category %s, not Manners' %s")
					:format(tostring(which), tostring(id)))
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 251
-- The bug-report box starts shut each time the window opens.
--
-- Whether it was open was a file local that only its own button ever changed,
-- so shutting the window and opening it again found the fourteen-line box still
-- open and the button reading "Hide the report" -- the state its own comment
-- says has no business surviving the window being shut. Both routes in.
Mock.reset()
ns = load("the bug-report box starts shut")
if ns then
	local scenario = "the bug-report box starts shut"
	drive(scenario, ns)
	local diag = ns.optionsTable and ns.optionsTable.args.diagnostics
	local report = diag and diag.args.report
	local button = diag and diag.args.copyReport
	if not (report and button and button.func and type(button.name) == "function") then
		fail(scenario, "SKIPPED -- no bug-report box on the page")
	else
		local function check(route)
			if not report.hidden() or button.name() ~= "Copy for a bug report" then
				fail(scenario, ("%s the report box is %s and the button reads %q")
					:format(route, report.hidden() and "shut" or "still open", button.name()))
			end
		end

		-- The standalone window, shut and opened again with /manners.
		ns.addon:HandleSlash("")
		Mock.optionsOpen = true
		button.func()
		if report.hidden() then
			fail(scenario, "SKIPPED -- the button did not open the box")
		end
		Mock.optionsOpen = false
		ns.addon:HandleSlash("")
		Mock.optionsOpen = true
		check("reopening the window with /manners,")
		Mock.optionsOpen = false

		-- The game's Settings window, shut and opened again on the page.
		-- From shut, whatever the first half left behind.
		Mock.openSettings()
		if not report.hidden() then button.func() end
		button.func()
		if report.hidden() then
			fail(scenario, "SKIPPED -- the button did not open the box on the Settings page")
		end
		Mock.closeSettings()
		Mock.openSettings()
		check("reopening the Settings window on the page,")
		Mock.closeSettings()
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 252
-- Wheeling Width or Height repaints the Icon size slider it shrank.
--
-- Both setters clamp the icon to fit, and neither asked the page to redraw. The
-- dialog redraws a slider when a drag is let go, and a mouse wheel lets go of
-- nothing, so wheeling Height from 44 down to 30 left the icon at 22 while its
-- slider showed 30 and the notice that says why stayed hidden. The repaint is
-- held back until the ticks stop, because a redraw rebuilds the slider under
-- a dragging pointer.
Mock.reset()
ns = load("wheeling the width or height repaints the icon slider")
if ns then
	local scenario = "wheeling the width or height repaints the icon slider"
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.runTimers(10)
	local app = ns.optionsTable and ns.optionsTable.args.appearance.args
	local registry = LibStub("AceConfigRegistry-3.0")
	if not (app and app.width and app.height and app.iconSize and app.iconSizeCapped
		and registry and registry.NotifyChange) then
		fail(scenario, "SKIPPED -- no Width, Height or Icon size slider, or no repaint to watch")
	else
		local p = ns.db.profile.prompt
		-- What the page last drew.
		local painted = { icon = p.iconSize, notice = not app.iconSizeCapped.hidden(), count = 0 }
		local realNotify = registry.NotifyChange
		registry.NotifyChange = function(...)
			painted.icon = app.iconSize.get({ "iconSize" })
			painted.notice = not app.iconSizeCapped.hidden()
			painted.count = painted.count + 1
			return realNotify(...)
		end
		local function wheel(key, from, to)
			for value = from, to, from > to and -1 or 1 do
				app[key].set({ key }, value)
				Mock.runTimers(0.05)
			end
			Mock.runTimers(1)
		end

		p.width, p.height, p.iconSize = 220, 44, 30
		wheel("height", 44, 30)
		if p.iconSize ~= 22 then
			fail(scenario, "SKIPPED -- a height of 30 did not clamp the icon to 22")
		elseif painted.icon ~= 22 or not painted.notice then
			fail(scenario, ("wheeling Height to 30 held the icon at 22 and the page still shows"
				.. " %s, with the notice %s"):format(tostring(painted.icon),
				painted.notice and "up" or "hidden"))
		end

		p.width, p.height, p.iconSize = 220, 44, 30
		wheel("width", 220, 80)
		if p.iconSize ~= 20 then
			fail(scenario, "SKIPPED -- a width of 80 did not clamp the icon to 20")
		elseif painted.icon ~= 20 then
			fail(scenario, ("wheeling Width to 80 held the icon at 20 and the page still shows %s")
				:format(tostring(painted.icon)))
		end

		-- A drag is the same run of ticks, and it asks for one redraw at the end
		-- rather than one per tick under the pointer.
		p.width, p.height, p.iconSize = 220, 44, 30
		painted.count = 0
		wheel("height", 44, 30)
		if painted.count > 1 then
			fail(scenario, ("a drag from 44 to 30 redrew the page %d times under the pointer")
				:format(painted.count))
		end
		registry.NotifyChange = realNotify
	end
end
Mock.reset()

-- An option's text, whether AceConfig was handed a string or a function.
local function optionText(value)
	if type(value) == "function" then return tostring(value({}) or "") end
	return tostring(value or "")
end

-- ------------------------------------------------------------------ 253
-- The targeting note follows "Hand my target back afterwards".
--
-- The note on the When you click tab always said the prompt runs the target
-- line, then the cast, then /targetlasttarget. It hid itself only for a class
-- that never targets anybody and never read the switch directly above it, so
-- with that switch off it described a line the macro no longer carried -- in
-- the one place its own comment says must not be a second opinion about the
-- macro.
Mock.reset()
ns = load("the targeting note follows the hand-back switch")
if ns then
	local scenario = "the targeting note follows the hand-back switch"
	drive(scenario, ns)
	Mock.advance(60)
	local click = ns.optionsTable and ns.optionsTable.args.click
	local toggle = click and click.args.restoreTarget
	local note = click and click.args.targetingNote
	-- Somebody reached through a nameplate: your own target is never handed
	-- back, whatever the switch says, so they would prove nothing. Every mock
	-- unit is the same person and the target token is walked first, so the
	-- first entry is moved onto a nameplate.
	local first = ns.BuildQueue()[1]
	local entry
	if first and first.buff then
		entry = {}
		for k, v in pairs(first) do entry[k] = v end
		entry.unit = "nameplate1"
	end
	if not (toggle and toggle.set and note and entry) then
		fail(scenario, "SKIPPED -- no targeting switch, no note, or nobody to build a macro for")
	else
		for _, on in ipairs({ true, false }) do
			toggle.set({ "restoreTarget" }, on)
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			local restores = tostring(ns.lastMacro or ""):find("/targetlasttarget", 1, true) ~= nil
			local says = optionText(note.name):find("/targetlasttarget", 1, true) ~= nil
			if restores ~= on then
				fail(scenario, ("SKIPPED -- with the switch %s the macro %s /targetlasttarget")
					:format(on and "on" or "off", restores and "carries" or "lacks"))
			elseif says ~= restores then
				fail(scenario, ("with the switch %s the note %s /targetlasttarget and the macro %s")
					:format(on and "on" or "off", says and "promises" or "leaves out",
						restores and "carries it" or "has none"))
			end
		end
		toggle.set({ "restoreTarget" }, true)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 254
-- "Always offer" is said to stop your target coming first.
--
-- BuildQueue promotes a target only once their auras have been read and found
-- missing the buff, and "Always offer, whatever they have" means nothing is
-- read -- so with it chosen, "Whoever I have targeted comes first" stayed ticked
-- and did nothing. The ranking is deliberate; the page just never said so. The
-- switch named only the game as its condition, the pale-blue colour named only
-- the switch, and the red note under Always offer named neither.
Mock.reset()
ns = load("always offer says it stops the target coming first")
if ns then
	local scenario = "always offer says it stops the target coming first"
	drive(scenario, ns)
	local target = ns.optionsTable and ns.optionsTable.args.who.args.target
	local always = ns.optionsTable and ns.optionsTable.args.when.args.alwaysNote
	local accent = ns.optionsTable and ns.optionsTable.args.appearance.args.accentByReason
	if not (target and always and accent) then
		fail(scenario, "SKIPPED -- the target switch, the Always note or the colour switch is missing")
	else
		ns.db.profile.filters.whenBuffed = "always"
		local texts = {
			{ "the target switch's description", optionText(target.desc), "Always offer" },
			{ "the colour switch's description", optionText(accent.desc), "Always offer" },
			{ "the note under Always offer", optionText(always.name), "target" },
		}
		for _, t in ipairs(texts) do
			if not t[2]:find(t[3], 1, true) then
				fail(scenario, ("%s does not say that Always offer stops your target coming"
					.. " first: %s"):format(t[1], t[2]))
			end
		end
		ns.db.profile.filters.whenBuffed = "skip"
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 255
-- "Remember a buff for" points at the setting that lets people go sooner.
--
-- It said this was how long somebody who buffed you stays on the prompt. With
-- "Drop people who are probably gone" on, which is the default, somebody the
-- game has no unit for is let go after the grace on the Who to buff tab --
-- forty-five seconds against this setting's hundred and twenty -- and that is
-- the ordinary case for a passer-by. Nothing on this tab said so.
Mock.reset()
ns = load("remember a buff for names the grace that ends it sooner")
if ns then
	local scenario = "remember a buff for names the grace that ends it sooner"
	drive(scenario, ns)
	local window = ns.optionsTable and ns.optionsTable.args.when.args.reciprocateWindow
	if not window then
		fail(scenario, "SKIPPED -- no Remember a buff for slider")
	elseif not optionText(window.desc):find("Drop people who are probably gone", 1, true) then
		fail(scenario, "the slider says people stay on the prompt this long and never mentions"
			.. " the setting that lets them go sooner: " .. optionText(window.desc))
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 256
-- "People who buffed me" does not promise a warrior strangers.
--
-- Its description was one fixed string ending "Works on strangers who are not
-- in your group." A warrior's Battle Shout reaches the group and nobody else,
-- so everybody outside it is turned down before the favour is looked at --
-- while the same page hides the passer-by switch and says in grey that there is
-- nothing to give a passer-by. The mage keeps the sentence, because for the
-- mage it is true.
for _, case in ipairs({
	{ class = "WARRIOR", key = "battleshout", strangers = false },
	{ class = "MAGE", key = "intellect", strangers = true },
}) do
	Mock.reset()
	Mock.class = case.class
	local scenario = "people who buffed me promises strangers only where they are reached ("
		.. case.class .. ")"
	ns = load(scenario)
	if ns then
		local known = {}
		for _, id in ipairs(ns.FindBuff(case.class, case.key).ranks) do known[id] = true end
		local realKnown = IsSpellKnown
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = function(id) return known[id] == true end

		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)

		local owed = ns.optionsTable and ns.optionsTable.args.who.args.owed
		if not owed then
			fail(scenario, "SKIPPED -- no People who buffed me switch")
		elseif ns.OnlyReachesGroup() == case.strangers then
			fail(scenario, "SKIPPED -- this class was expected to reach "
				.. (case.strangers and "strangers" or "its group only") .. " and does not")
		else
			local promises = optionText(owed.desc):find("Works on strangers", 1, true) ~= nil
			if promises and not case.strangers then
				fail(scenario, "a class whose spells reach its group only is told the favour"
					.. " switch works on strangers: " .. optionText(owed.desc))
			elseif not promises and case.strangers then
				fail(scenario, "a class that can buff anybody lost the sentence saying the favour"
					.. " switch works on strangers")
			end
		end

		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 257
-- "(mana users only)" follows the switch that makes it true.
--
-- The label was added whenever a spell was marked mana-only. The spell is only
-- held back from a warrior while "Skip players the buff does nothing for" is
-- on; switched off, the warrior is offered Divine Spirit while the Automatic
-- note and the per-spell switches go on saying it is for mana users only.
Mock.reset()
Mock.class = "PRIEST"
ns = load("mana users only follows its switch")
if ns then
	local scenario = "mana users only follows its switch"
	local known = {}
	for _, key in ipairs({ "fortitude", "spirit" }) do
		for _, id in ipairs(ns.FindBuff("PRIEST", key).ranks) do known[id] = true end
	end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)

	local who = ns.optionsTable and ns.optionsTable.args.who
	local note = who and who.args.autoNote
	local toggle = who and who.args.offer_spirit
	local skip = who and who.args.relevantOnly
	if not (note and toggle and skip and skip.set) then
		fail(scenario, "SKIPPED -- no Automatic note, Divine Spirit switch or relevance switch")
	elseif not ns.FindBuff("PRIEST", "spirit").manaOnly then
		fail(scenario, "SKIPPED -- Divine Spirit is not marked mana-only on this client")
	else
		local QUALIFIER = "(mana users only)"
		skip.set({ "relevantOnly" }, false)
		for what, text in pairs({ ["the Automatic note"] = optionText(note.name),
			["the Divine Spirit switch"] = optionText(toggle.name) }) do
			if text:find(QUALIFIER, 1, true) then
				fail(scenario, what .. " says mana users only with the switch that makes it"
					.. " true turned off: " .. text)
			end
		end
		skip.set({ "relevantOnly" }, true)
		if not optionText(toggle.name):find(QUALIFIER, 1, true) then
			fail(scenario, "with the relevance switch on, the Divine Spirit switch no longer says"
				.. " it is for mana users only")
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end
Mock.reset()

-- ------------------------------------------------------------------ 258
-- "Every spell below is switched off" is said only when every one is.
--
-- The note said so as soon as every spell the character had learned was
-- switched off. The ones not learned yet stay ticked below it, greyed and
-- marked "(not learned)", and learning one brings the prompt back without
-- touching anything -- so both "every spell" and "never" were false for a
-- low-level priest who switched Fortitude off.
Mock.reset()
Mock.class = "PRIEST"
ns = load("every spell switched off means every one")
if ns then
	local scenario = "every spell switched off means every one"
	local known = {}
	for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
	local realKnown = IsSpellKnown
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = function(id) return known[id] == true end

	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)

	local note = ns.optionsTable and ns.optionsTable.args.who.args.autoNote
	local skip = ns.db.profile.buff.skip
	local ALL_OFF = "Every spell below is switched off"
	if not note then
		fail(scenario, "SKIPPED -- no Automatic note")
	else
		skip.fortitude = true
		local text = optionText(note.name)
		if #ns.CastableBuffs() > 0 then
			fail(scenario, "SKIPPED -- switching Fortitude off left something to offer")
		elseif text:find(ALL_OFF, 1, true) then
			fail(scenario, "with Divine Spirit and Shadow Protection still ticked below, the note"
				.. " says every spell is switched off: " .. text)
		elseif not text:find("learned", 1, true) then
			fail(scenario, "the note does not say it is the learned spells that are off: " .. text)
		end

		skip.spirit, skip.shadow = true, true
		text = optionText(note.name)
		if not text:find(ALL_OFF, 1, true) then
			fail(scenario, "with every spell unticked the note no longer says so: " .. text)
		end
		skip.fortitude, skip.spirit, skip.shadow = nil, nil, nil
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
end
Mock.reset()

-- ------------------------------------------------------------------ 259
-- "Leave them alone" says who it does not leave alone.
--
-- Somebody who buffed you is offered the favour back even when they already
-- hold the buff -- a refresh, which takes nothing away, and a deliberate
-- policy. The dropdown offered "Leave them alone" with nothing qualifying it,
-- and the top-up slider said somebody whose timer cannot be read "is left
-- alone", so the one person the prompt did offer looked like a bug.
Mock.reset()
ns = load("leave them alone names the favour exception")
if ns then
	local scenario = "leave them alone names the favour exception"
	drive(scenario, ns)
	local when = ns.optionsTable and ns.optionsTable.args.when
	local choice = when and when.args.whenBuffed
	local refresh = when and when.args.refreshUnder
	if not (choice and refresh) then
		fail(scenario, "SKIPPED -- no If they already have the buff dropdown or top-up slider")
	else
		for what, text in pairs({ ["the dropdown's description"] = optionText(choice.desc),
			["the top-up slider's description"] = optionText(refresh.desc) }) do
			if not text:find("buffed you", 1, true) then
				fail(scenario, what .. " never says somebody who buffed you is offered the buff"
					.. " anyway: " .. text)
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 260
-- The paladin note says when a blessing of yours can be replaced.
--
-- It said that anybody already carrying one of your blessings is left alone
-- rather than handed a different one. That rests on reading their blessings,
-- and two things stop the reading: "Always offer, whatever they have", which
-- chooses not to look, and a client that will not show those auras. Either way
-- the first blessing that suits them is offered -- Wisdom, to a mana user
-- wearing your Might, which replaces it -- under a note promising it could not
-- happen. Where the blessings are read, the promise holds and stays as it was.
for _, case in ipairs({
	{ label = "reading them", whenBuffed = "skip" },
	{ label = "always offer", whenBuffed = "always", exception = true },
	{ label = "blessings the game hides", whenBuffed = "skip", secret = true, exception = true },
	{ label = "blessings the game hides, topping up", whenBuffed = "refresh", secret = true,
		exception = true },
}) do
	Mock.reset()
	Mock.class = "PALADIN"
	local scenario = "the paladin note says when a blessing can be replaced (" .. case.label .. ")"
	local realName = UnitName
	UnitName = function(u)
		if u == "player" then return "Mort", "Defrette" end
		if u == "target" then return "Petra", "Stonewell" end
		return "Yorick", "Vane"
	end
	ns = load(scenario)
	if ns then
		local known = {}
		for _, key in ipairs({ "wisdom", "might", "kings" }) do
			for _, id in ipairs(ns.FindBuff("PALADIN", key).ranks) do known[id] = true end
		end
		local realKnown = IsSpellKnown
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = function(id) return known[id] == true end

		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		local might = ns.FindBuff("PALADIN", "might")
		Mock.held = {}
		for _, id in ipairs(might.auraIds) do Mock.held[id] = true end
		if case.secret then
			Mock.secretAuraIds = {}
			for _, key in ipairs({ "wisdom", "might", "kings" }) do
				for _, id in ipairs(ns.FindBuff("PALADIN", key).auraIds) do
					Mock.secretAuraIds[id] = true
				end
			end
		end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.profile.filters.whenBuffed = case.whenBuffed

		-- What the scan really does with somebody wearing your Might, so the
		-- note is judged against the walk rather than against itself.
		local handed
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Petra Stonewell" then handed = entry.buff end
		end
		local replaced = handed ~= nil and handed.key ~= "might"

		local note = ns.optionsTable and ns.optionsTable.args.who.args.autoNote
		local text = note and optionText(note.name) or ""
		local EXCEPTION = "replace one of yours"
		if not note then
			fail(scenario, "SKIPPED -- no Automatic note")
		elseif replaced ~= (case.exception == true) then
			fail(scenario, "SKIPPED -- somebody wearing your Might was "
				.. (handed and ("handed " .. handed.key) or "left alone")
				.. ", which is not what this case was built to show")
		elseif case.exception and not text:find(EXCEPTION, 1, true) then
			fail(scenario, ("somebody wearing your Might is handed %s, which replaces it, and"
				.. " the note still promises they are left alone: %s"):format(handed.key, text))
		elseif not case.exception and (text:find(EXCEPTION, 1, true)
			or not text:find("left alone", 1, true)) then
			fail(scenario, "where the blessings are read the note no longer says plainly that"
				.. " somebody carrying one of yours is left alone: " .. text)
		end

		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown
	end
	UnitName = realName
end
Mock.reset()

-- ------------------------------------------------------------------ 261
-- The chat switch lists what it prints.
--
-- Its description promised "a line for what each click turned into -- cast,
-- refused, skipped, or still owed", and /manners verbose said the same. A cast
-- the game confirmed prints nothing at all, and neither does any cast on
-- somebody who was not owed: the only line for a click that worked is "counted
-- as repaid", for a favour. So somebody switching it on to watch their casts
-- saw nothing and took the switch for broken.
Mock.reset()
ns = load("the chat switch lists what it prints")
if ns then
	local scenario = "the chat switch lists what it prints"
	drive(scenario, ns)
	local verbose = ns.optionsTable and ns.optionsTable.args.general.args.verbose
	if not verbose then
		fail(scenario, "SKIPPED -- the chat switch is not on the page")
	else
		ns.db.profile.verbose = false
		Mock.printed = {}
		ns.addon:HandleSlash("verbose")
		local said = table.concat(Mock.printed, " | ")
		for what, text in pairs({ ["the switch's description"] = optionText(verbose.desc),
			["/manners verbose"] = said }) do
			if text:find("each click", 1, true) then
				fail(scenario, what .. " promises a line for every click, and a cast that"
					.. " worked prints nothing: " .. text)
			end
			if not text:find("repaid", 1, true) then
				fail(scenario, what .. " does not name the one line a cast that worked"
					.. " prints: " .. text)
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 262
-- Diagnostics says "never offer" only about a spell that is never offered.
--
-- Every id of a buff is checked against the client, the ranks and the group
-- version alike, and any one of them missing printed "this client has never
-- heard of spell N, so Manners will never offer this one". A missing group id
-- -- Arcane Brilliance, say -- costs only the check of whether somebody is
-- already wearing it: Arcane Intellect is still learned, offered and cast, and
-- the page said "learned: yes" directly above "never offer". A rank the client
-- does not have, on a spell nobody has learned, is still the "never" case.
for _, case in ipairs({
	{ label = "a group id", class = "MAGE", key = "intellect", missing = 23028, offered = true },
	{ label = "the only rank", class = "SHAMAN", key = "skyfury", missing = 462854,
		interface = 120100 },
}) do
	Mock.reset()
	if case.interface then Mock.interface = case.interface end
	Mock.class = case.class
	Mock.unknownSpells = { [case.missing] = true }
	local scenario = "diagnostics says never offer only when it is true (" .. case.label .. ")"
	local realName = UnitName
	UnitName = function(u)
		if u == "player" then return "Mort", "Defrette" end
		if u == "target" then return "Petra", "Stonewell" end
		return "Yorick", "Vane"
	end
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.Guard("probe", ns.ProbeCapabilities)

		local offered = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.buff and entry.buff.key == case.key then offered = true end
		end
		local diag = ns.optionsTable and ns.optionsTable.args.diagnostics
			and ns.optionsTable.args.diagnostics.args.diag
		local text = diag and optionText(diag.name) or ""
		if not ns.FindBuff(case.class, case.key) then
			fail(scenario, "SKIPPED -- this client has no " .. case.key .. " to get wrong")
		elseif not diag then
			fail(scenario, "SKIPPED -- there is no diagnostics text to read")
		elseif offered ~= (case.offered == true) then
			fail(scenario, "SKIPPED -- " .. case.key .. " was " .. (offered and "" or "not ")
				.. "offered, which is not what this case was built to show")
		elseif not text:find(tostring(case.missing), 1, true) then
			fail(scenario, "the page no longer names the id this client does not have: " .. text)
		elseif case.offered and text:find("never offer", 1, true) then
			fail(scenario, "the page says Manners will never offer a spell the queue is offering"
				.. " right now: " .. text)
		elseif not case.offered and not text:find("never offer", 1, true) then
			fail(scenario, "a spell no rank of which exists here is no longer said to be never"
				.. " offered: " .. text)
		end
	end
	UnitName = realName
end
Mock.reset()

-- ------------------------------------------------------------------ 263
-- The minimap tooltip does not say it is watching for a character with nothing
-- to cast.
--
-- It asked only whether the addon was switched on, and said "Watching for
-- people to buff." whenever it was -- to a rogue, and to a mage who has not
-- learned Arcane Intellect yet, neither of whom will ever see a prompt. The
-- tooltip exists to say why no prompt has appeared, and it said the one thing
-- that makes a missing prompt look like a bug.
for _, case in ipairs({
	{ label = "a rogue", class = "ROGUE", says = "no buffs" },
	{ label = "a mage who has learned nothing", class = "MAGE", learned = false,
		says = "learned" },
	{ label = "a mage with every spell switched off", class = "MAGE", off = true,
		says = "switched off under" },
	{ label = "a mage who can cast", class = "MAGE", watching = true },
}) do
	Mock.reset()
	Mock.class = case.class
	local scenario = "the minimap tooltip says why nothing is offered (" .. case.label .. ")"
	ns = load(scenario)
	if ns then
		local realKnown = IsSpellKnown
		if case.learned == false then
			IsSpellKnown = function() return false end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.Guard("probe", ns.ProbeCapabilities)
		if case.off then
			for _, buff in ipairs(ns.GetClassBuffs(case.class) or {}) do
				ns.db.profile.buff.skip[buff.key] = true
			end
		end

		local broker = Mock.broker
		if not (broker and broker.OnTooltipShow) then
			fail(scenario, "SKIPPED -- no launcher to read")
		else
			local lines = {}
			local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
			local ok, err = pcall(broker.OnTooltipShow, tt)
			local said = table.concat(lines, "\n")
			if not ok then
				fail(scenario, "the launcher tooltip threw -> " .. tostring(err))
			elseif case.watching then
				if not said:find("Watching for people to buff", 1, true) then
					fail(scenario, "a character with a spell to cast is no longer told the addon"
						.. " is watching: " .. said)
				end
			elseif said:find("Watching", 1, true) then
				fail(scenario, case.label .. " will never see a prompt and the tooltip says it is"
					.. " watching for people to buff: " .. said)
			elseif not said:find(case.says, 1, true) then
				fail(scenario, "the tooltip does not say why " .. case.label .. " sees no prompt: "
					.. said)
			end
		end

		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 264
-- "Stay quiet in combat" gives the true reason the prompt stays up.
--
-- It told players the prompt "cannot be hidden" because Blizzard freezes secure
-- frames, and the comments behind it said a secure visibility driver was out
-- because this client does not resolve macro conditionals. Only the ones that
-- name a unit, [@Name], are restricted here; [combat] resolves, and other
-- addons on this client drive visibility with it. The prompt stays on screen
-- because a hidden secure button still fires from its key binding and /click,
-- casting the frozen macro out of sight -- and that is what the page now says.
Mock.reset()
ns = load("stay quiet in combat gives the true reason")
if ns then
	local scenario = "stay quiet in combat gives the true reason"
	drive(scenario, ns)
	local toggle = ns.optionsTable and ns.optionsTable.args.appearance.args.hideInCombat
	if not toggle then
		fail(scenario, "SKIPPED -- the combat switch is not on the page")
	else
		local desc = optionText(toggle.desc)
		if desc:find("cannot be hidden", 1, true) or desc:find("Blizzard freezes", 1, true) then
			fail(scenario, "the switch still says the prompt cannot be hidden, when it is kept up"
				.. " on purpose: " .. desc)
		elseif not desc:find("binding", 1, true) then
			fail(scenario, "the switch does not say why the prompt stays on screen: " .. desc)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 265
-- "Stay quiet in combat" does not promise a green flash.
--
-- It said the prompt "still flashes green or red" to say what happened. The
-- wash is the reason's own colour -- amber, cyan, blue, grey or the accent you
-- picked -- and only a failure overrides it, with red. Nothing ever washes the
-- panel green, so somebody watching for green after a cast that worked took
-- the cast for lost.
Mock.reset()
ns = load("stay quiet in combat promises no green")
if ns then
	local scenario = "stay quiet in combat promises no green"
	drive(scenario, ns)
	local toggle = ns.optionsTable and ns.optionsTable.args.appearance.args.hideInCombat
	if not toggle then
		fail(scenario, "SKIPPED -- the combat switch is not on the page")
	else
		local desc = optionText(toggle.desc)
		if desc:lower():find("green", 1, true) then
			fail(scenario, "the switch promises a green flash the prompt never paints: " .. desc)
		elseif not desc:find("%f[%a]red%f[%A]") then
			fail(scenario, "the switch no longer says a failure flashes red: " .. desc)
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 266
-- The key binding is where the greeting says it is.
--
-- The first-run greeting and the General tab both sent the player to "Game
-- Menu > Key Bindings > Manners". This client's game menu has no Key Bindings
-- entry: bindings are the Keybindings page of Options. And Bindings.xml filed
-- the binding under the shared ADDONS category, so there was no section called
-- Manners to find either -- the one line sat among everybody else's addons,
-- labelled "Buff the prompted player". The path is read against the category
-- Bindings.xml really declares, so the two cannot drift apart again.
Mock.reset()
Mock.sv = {}
ns = load("the key binding is where the greeting says")
if ns then
	local scenario = "the key binding is where the greeting says"
	local file = io.open(dir .. "/Bindings.xml", "r")
	local xml = file and file:read("a") or ""
	if file then file:close() end
	local category = xml:match('category="([^"]*)"')
	local said = firstLogin(ns)
	local how = ns.optionsTable and ns.optionsTable.args.general.args.howItWorks
	if not said then
		fail(scenario, "the first session would not start at all")
	elseif not how then
		fail(scenario, "SKIPPED -- the How this works text is not on the page")
	elseif category ~= "Manners" then
		fail(scenario, "Bindings.xml files the binding under " .. tostring(category)
			.. ", so the Keybindings page has no section called Manners")
	else
		local texts = { greeting = said, ["How this works"] = optionText(how.name) }
		for where, text in pairs(texts) do
			if text:find("Game Menu", 1, true) then
				fail(scenario, "the " .. where .. " sends the player to a Game Menu entry"
					.. " this client does not have: " .. text)
			elseif not text:find("Keybindings > " .. category, 1, true) then
				fail(scenario, "the " .. where .. " does not name the Keybindings section"
					.. " the binding is in: " .. text)
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 267
-- The addon wears its own icon.
--
-- tools/make-icon.py writes Textures/Manners64.tga and ships it in every zip,
-- saying it is the icon for the minimap button and the addon list. Nothing
-- pointed at it: both tocs and the launcher named a Blizzard spell icon, so the
-- logo only ever existed on the download page. Every place that names an icon
-- has to name a file the package really carries.
Mock.reset()
ns = load("the addon wears its own icon")
if ns then
	local scenario = "the addon wears its own icon"
	drive(scenario, ns)
	local function onDisk(path)
		local rel = type(path) == "string" and path:match("^Interface\\AddOns\\Manners\\(.+)$")
		if not rel then return false end
		local f = io.open(dir .. "/" .. rel:gsub("\\", "/") .. ".tga", "rb")
		if f then f:close() return true end
		return false
	end
	for _, toc in ipairs({ "Manners.toc", "Manners_Camelot.toc" }) do
		local file = io.open(dir .. "/" .. toc, "r")
		local text = file and file:read("a") or ""
		if file then file:close() end
		local icon = text:match("\n## IconTexture:%s*([^\r\n]+)")
		if not onDisk(icon) then
			fail(scenario, toc .. " shows " .. tostring(icon) .. " in the addon list,"
				.. " not the logo the package ships")
		end
	end
	local icon = Mock.broker and Mock.broker.icon
	if not onDisk(icon) then
		fail(scenario, "the minimap button shows " .. tostring(icon)
			.. ", not the logo the package ships")
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 268
-- A macro armed for a fight hands your target back.
--
-- Scenario 237 took /targetlasttarget off the macro for somebody reached
-- through the target token, on the grounds that the macro is rebuilt the moment
-- the target changes. In a fight it is not: the attributes are frozen at the
-- pull. So a player with a friendly stranger targeted when a mob pulled, who
-- then tabbed to the mob and pressed the prompt, ran /target on the stranger,
-- the cast, and nothing else -- and was left targeting the stranger mid-fight,
-- the mob lost, with "hand my target back" on.
Mock.reset()
local seen268 = { target = { "Anna", "Aim" } }
restoreUnits = strangers(seen268)
ns = load("a macro armed for a fight hands your target back")
if ns then
	local scenario = "a macro armed for a fight hands your target back"
	freshPrompt(ns, scenario)
	ns.db.profile.filters.restoreTarget = true
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	local before = tostring(button:GetAttribute("macrotext1") or "")
	if not before:find("Anna Aim", 1, true) or before:find("/targetlasttarget", 1, true) then
		fail(scenario, "SKIPPED -- Anna was not armed through the target token without a"
			.. " hand-back: " .. (before:gsub("\n", " / ")))
	else
		-- The pull, as the client delivers it: the event just before lockdown,
		-- then lockdown itself.
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.runTimers(0.1)
		local frozen = tostring(button:GetAttribute("macrotext1") or "")
		if not frozen:find("/targetlasttarget", 1, true) then
			fail(scenario, "the macro frozen for the fight cannot hand back a target changed"
				.. " during it: " .. (frozen:gsub("\n", " / ")))
		end
		-- The Targeting note promised your own target stays targeted, with no
		-- word about the fight where it does not.
		local note = ns.optionsTable and ns.optionsTable.args.click.args.targetingNote
		local says = note and tostring(type(note.name) == "function" and note.name() or note.name)
		if not says then
			fail(scenario, "SKIPPED -- the Targeting note is not on the page")
		elseif says:find("stays targeted", 1, true) and not says:find("fight", 1, true) then
			fail(scenario, "the Targeting note says your own target stays targeted, and in a"
				.. " fight the macro hands it back: " .. says)
		end

		-- And out of the fight the target keeps its own macro again.
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		local after = tostring(button:GetAttribute("macrotext1") or "")
		if after:find("/targetlasttarget", 1, true) then
			fail(scenario, "after the fight the macro for your own target still hands it to"
				.. " whoever came before: " .. (after:gsub("\n", " / ")))
		end
	end
	Mock.inCombat = false
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 269
-- A spoken line rolled for your target still fits once they are not.
--
-- The line is rolled once per person, buff and reason, and kept when the same
-- person is reached another way -- somebody who buffed you is "owed" through
-- every token. The room it was rolled for is not kept with
-- it: your own target's macro has no hand-back, so it leaves eighteen more
-- characters for the line. A line that used them, kept when the same person
-- turned up off a nameplate and the hand-back came back, took the macro past
-- the client's limit -- and what the client cuts off is the last line, the
-- /targetlasttarget that hands your target back.
Mock.reset()
local seen269 = { target = { "Anna", "Aim" } }
restoreUnits = strangers(seen269)
ns = load("a line rolled for your target still fits once they are not")
if ns then
	local scenario = "a line rolled for your target still fits once they are not"
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.filters.restoreTarget = true
	db.speech.enabled = true
	db.speech.channel = "SAY"
	db.speech.onlyWhenReturning = false
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local top = ns.BuildQueue()[1]
	if not (top and top.unit == "target" and top.reason == "owed") then
		fail(scenario, "SKIPPED -- Anna was not offered as owed through the target token")
	else
		-- A line that uses every character your own target's macro leaves.
		db.speech.phrases = string.rep("x", ns.PhraseBudget(top) - #"/say ")
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local asTarget = tostring(button:GetAttribute("macrotext1") or "")
		if not asTarget:find("\n/say x", 1, true) then
			fail(scenario, "SKIPPED -- the line was not armed for the target: "
				.. (asTarget:gsub("\n", " / ")))
		else
			seen269.target = nil
			seen269.nameplate1 = { "Anna", "Aim" }
			ns.nameplateUnits["nameplate1"] = true
			ns.addon:Tick()
			local armed = tostring(button:GetAttribute("macrotext1") or "")
			if not armed:find("Anna Aim", 1, true) then
				fail(scenario, "SKIPPED -- Anna was not armed off the nameplate: "
					.. (armed:gsub("\n", " / ")))
			elseif #armed > ns.MACRO_LIMIT then
				fail(scenario, ("the macro off the nameplate is %d characters, and the client"
					.. " cuts the hand-back off the end of it"):format(#armed))
			elseif not armed:find("/targetlasttarget", 1, true) then
				fail(scenario, "the hand-back is missing off the nameplate: "
					.. (armed:gsub("\n", " / ")))
			end
		end
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 270
-- A warrior's queue built in a fight does not ask the follow prompt.
--
-- Whether a shout reaches somebody is asked of CheckInteractDistance, and that
-- call is restricted for a friendly unit during lockdown: the game blocks it
-- and blames the addon. The scan does not build the queue in a fight, but
-- /manners debug does, so a warrior typing it mid-pull had the addon ask about
-- every party member in the one state where asking is refused. The distance
-- filter already stands down in a fight for this very reason.
Mock.reset()
Mock.class = "WARRIOR"
Mock.groupSize = 3
Mock.unitNames = { party1 = { "Near", "Ally" }, party2 = { "Far", "Ally" } }
local realKnown270, realPlayer270 = IsSpellKnown, IsPlayerSpell
ns = load("a warrior's queue built in a fight does not ask the follow prompt")
if ns then
	local scenario = "a warrior's queue built in a fight does not ask the follow prompt"
	knowShout(ns)
	Mock.rangeless = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do
		Mock.rangeless[id] = true
	end
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.Guard("probe", ns.ProbeCapabilities)
	local realInteract = CheckInteractDistance
	local asked, inFight = 0, {}
	CheckInteractDistance = function(unit, index)
		asked = asked + 1
		if Mock.inCombat then inFight[#inFight + 1] = tostring(unit) .. ":" .. tostring(index) end
		return realInteract(unit, index)
	end
	ns.BuildQueue()
	if asked == 0 then
		fail(scenario, "SKIPPED -- the follow prompt was not asked even out of a fight")
	else
		Mock.inCombat = true
		ns.addon:HandleSlash("debug")
		Mock.inCombat = false
		if #inFight > 0 then
			fail(scenario, "asked CheckInteractDistance about a friendly unit in a fight,"
				.. " which the game blocks: " .. table.concat(inFight, ", "))
		end
	end
	CheckInteractDistance = realInteract
end
IsSpellKnown, IsPlayerSpell = realKnown270, realPlayer270
Mock.reset()

-- ------------------------------------------------------------------ 271
-- The README says what happens when /target finds the wrong Mort.
--
-- It said the addon notices the cast landed on somebody else and says so. That
-- takes the client naming who received the spell, and this one usually does
-- not: the settle then rests on the /target line alone and counts the favour
-- as repaid, saying nothing about anybody else. Judged against the settle
-- itself, so the sentence is held to what a press with no recipient does.
Mock.reset()
local seen271 = { nameplate1 = { "Mort", "Tall" } }
restoreUnits = strangers(seen271)
ns = load("the README says what a press with no named recipient does")
if ns then
	local scenario = "the README says what a press with no named recipient does"
	freshPrompt(ns, scenario)
	owe(ns, "Mort Tall")
	local entry
	for _, row in ipairs(ns.BuildQueue()) do
		if row.name == "Mort Tall" then entry = row end
	end
	local spell = entry and entry.buff and ns.FindBuff(ns.caps.class, entry.buff.key)
	if not (entry and spell) or not pressAndSend(ns, entry, spell.ranks[1]) then
		fail(scenario, "SKIPPED -- no press on Mort could be made")
	else
		local said = table.concat(Mock.printed, "\n")
		local file = io.open(dir .. "/README.md", "r")
		local text = file and file:read("a") or ""
		if file then file:close() end
		local para = ""
		for block in (text .. "\n\n"):gmatch("(.-)\n\n") do
			if block:find("Mortimer", 1, true) then para = block:gsub("%s+", " ") end
		end
		if ns.owed["Mort Tall"] or not said:find("counted as repaid", 1, true) then
			fail(scenario, "SKIPPED -- a press with no named recipient was not counted as"
				.. " repaid: " .. said)
		elseif para == "" then
			fail(scenario, "SKIPPED -- the README no longer mentions Mortimer")
		elseif not para:find("counted as repaid", 1, true) then
			fail(scenario, "the README promises the wrong Mort is noticed, and a press the"
				.. " client names nobody for is counted as repaid: " .. para)
		end
	end
end
restoreUnits()
Mock.reset()

-- ------------------------------------------------------------------ 272
-- A warrior in a raid is told the shout reaches his subgroup, not his group.
--
-- A raider from another subgroup who buffed a warrior was announced with "what
-- you cast reaches your group only, so they are offered if they join it". They
-- are in his group already -- the raid -- and joining it is not what would get
-- them offered; being in his subgroup is. The warrior's description of "People
-- who buffed me" said the same.
Mock.reset()
Mock.class = "WARRIOR"
Mock.raid = { size = 40, player = 1 }
Mock.unitNames = {}
for i = 1, 40 do Mock.unitNames["raid" .. i] = { "Raider" .. i, "Stone" } end
local realKnown272, realPlayer272 = IsSpellKnown, IsPlayerSpell
ns = load("a warrior in a raid is told the shout reaches his subgroup")
if ns then
	local scenario = "a warrior in a raid is told the shout reaches his subgroup"
	knowShout(ns)
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.db.profile.verbose = true
	primeAuras(ns)
	local said = favourFrom(ns, "raid30", 25289)
	if not said:find("buffed you", 1, true) or said:find("on the prompt", 1, true) then
		fail(scenario, "SKIPPED -- the favour from another subgroup was not noticed as out"
			.. " of reach: " .. said)
	elseif not said:find("subgroup", 1, true) then
		fail(scenario, "a raider already in the group was told to join it: " .. said)
	end
	local owed = ns.optionsTable and ns.optionsTable.args.who.args.owed
	local desc = owed and tostring(type(owed.desc) == "function" and owed.desc() or owed.desc)
	if not desc then
		fail(scenario, "SKIPPED -- the owed toggle has no description to read")
	elseif not desc:find("subgroup", 1, true) then
		fail(scenario, "the warrior's owed toggle says the shout reaches the group, and in a"
			.. " raid it reaches the subgroup: " .. desc)
	end
end
IsSpellKnown, IsPlayerSpell = realKnown272, realPlayer272
Mock.reset()

-- ------------------------------------------------------------------ 273
-- A shout at somebody measured too far away says they were too far away.
--
-- With "Hide players known to be out of range" off, a party member the follow
-- prompt reported as out of earshot is still offered the shout. Pressing it
-- kept the debt, rightly, and said "nothing could tell whether they were close
-- enough to hear it" -- when something had told, and the answer was no.
Mock.reset()
Mock.class = "WARRIOR"
Mock.groupSize = 3
Mock.unitNames = { party1 = { "Near", "Ally" }, party2 = { "Far", "Ally" } }
Mock.yards = { party1 = 5, party2 = 60 }
local realKnown273, realPlayer273 = IsSpellKnown, IsPlayerSpell
ns = load("a shout at somebody measured too far away says so")
if ns then
	local scenario = "a shout at somebody measured too far away says so"
	knowShout(ns)
	Mock.rangeless = {}
	for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do
		Mock.rangeless[id] = true
	end
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.db.profile.verbose = true
	ns.db.profile.filters.requireInRange = false

	ns.owed["Far Ally"] = { expires = GetTime() + 100, at = GetTime() }
	local far
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == "Far Ally" then far = entry end
	end
	local shout = ns.FindBuff("WARRIOR", "battleshout").ranks[1]
	if not (far and far.ranged == false) then
		fail(scenario, "SKIPPED -- the far party member was not offered as measured out of"
			.. " earshot")
	elseif not pressAndSend(ns, far, shout) then
		fail(scenario, "SKIPPED -- the press on them was not recorded")
	else
		local said = table.concat(Mock.printed, "\n")
		if not ns.owed["Far Ally"] then
			fail(scenario, "SKIPPED -- a shout at somebody out of earshot cleared the debt")
		elseif said:find("nothing could tell", 1, true) then
			fail(scenario, "the follow prompt said they were too far away, and the line says"
				.. " nothing could tell: " .. said)
		elseif not said:find("too far away", 1, true) then
			fail(scenario, "the kept debt does not say they were too far away: " .. said)
		end
	end
end
IsSpellKnown, IsPlayerSpell = realKnown273, realPlayer273
Mock.reset()

-- ------------------------------------------------------------------ 274
-- Somebody who buffed a paladin is offered the favour back even when every
-- blessing the paladin knows is already on them from another paladin.
--
-- Scenario 216 walks an owed person past another paladin's blessing to a kind
-- they lack. With no kind left -- a young paladin who knows only Might, owing
-- somebody who wears another paladin's Might -- the walk ended with nothing,
-- and nobody was offered anything. Chat had said "returning the favour is on the
-- prompt", and the options promise that somebody who buffed you is offered the
-- favour back even if they already have it.
Mock.reset()
Mock.class = "PALADIN"
Mock.unitClass = "PALADIN"
local realKnown274, realPlayer274 = IsSpellKnown, IsPlayerSpell
ns = load("an owed person wearing every blessing you know is still offered one")
if ns then
	local scenario = "an owed person wearing every blessing you know is still offered one"
	local known = {}
	for _, id in ipairs(ns.FindBuff("PALADIN", "might").ranks) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
	drive(scenario, ns)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.Guard("probe", ns.ProbeCapabilities)
	local might = ns.FindBuff("PALADIN", "might").ranks[1]
	Mock.held = { [might] = true }
	Mock.heldSource = { [might] = "nameplate2" }
	local before = inQueue(ns)["Petra Stonewell"]
	ns.owed["Petra Stonewell"] = { expires = GetTime() + 100, at = GetTime() }
	Mock.advance(1)
	local petra = inQueue(ns)["Petra Stonewell"]
	if before then
		fail(scenario, "SKIPPED -- somebody wearing another paladin's Might was offered"
			.. " it before they were owed anything")
	elseif not petra then
		fail(scenario, "somebody who buffed you, wearing another paladin's Might, was"
			.. " offered nothing at all by a paladin who knows only Might")
	elseif petra.buff.key ~= "might" then
		fail(scenario, "offered " .. tostring(petra.buff.key) .. ", which is not learned")
	end
	wipe(ns.owed)
	Mock.held, Mock.heldSource = nil, nil
end
IsSpellKnown, IsPlayerSpell = realKnown274, realPlayer274
Mock.reset()

-- ------------------------------------------------------------------ 275
-- The carried-anchor line does not tell a rescued player to undo the rescue.
--
-- The carry-over exists for 0.9.x prompts that beta.1 to beta.3 pinned onto
-- the bottom edge over the action bars by accident, and it cannot tell them
-- from a prompt put there on purpose with the Y slider. The line said "If it
-- used to sit on the bottom edge, drag it back" -- which both of them did, so
-- the player it rescued was told to put the prompt back over their bars. What
-- tells the two apart is only what the player meant, so that is what it asks.
Mock.reset()
ns = load("the carried-anchor line asks what the player meant")
if ns then
	local scenario = "the carried-anchor line asks what the player meant"
	drive(scenario, ns)
	local p = ns.db.profile.prompt
	p.point, p.relPoint, p.y = "BOTTOM", "BOTTOM", -40
	p.anchorCarried = nil
	Mock.printed = {}
	ns.addon:RefreshConfig()
	local said = table.concat(Mock.printed, "\n")
	if p.point ~= "CENTER" or not said:find("Put it", 1, true) then
		fail(scenario, "SKIPPED -- the carry-over did not fire or was not announced: " .. said)
	elseif not said:find("on purpose", 1, true) then
		fail(scenario, "the line tells everybody whose prompt sat on the bottom edge to put"
			.. " it back, the players it rescued included: " .. said)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ extras
-- Scenarios kept in tests/scenarios/*.lua. Each file is called with the
-- addon directory and this table of the helpers above, and reads them as
--   local dir, H = ...
--   local fail, load, drive = H.fail, H.load, H.drive
-- A file that will not load, or throws, is a failure of its own rather than
-- a silent skip: a scenario file nobody runs proves nothing.
local H = {
	fail = fail, load = load, drive = drive,
	optionKeys = optionKeys, walkOptions = walkOptions,
	inQueue = inQueue, settle = settle, withEmptyPrompt = withEmptyPrompt,
	firstLogin = firstLogin, strangers = strangers, clearClicks = clearClicks,
	freshPrompt = freshPrompt, pressButton = pressButton, owe = owe,
	knowShout = knowShout, primeAuras = primeAuras, favourFrom = favourFrom,
	pressAndSend = pressAndSend, findOption = findOption, namedSpell = namedSpell,
	savedProfile = savedProfile, tryAgainst = tryAgainst, optionText = optionText,
}
if extras then
	for i = 1, #extras do
		local path = extras[i]
		local name = tostring(path):match("[^/\\]+$") or tostring(path)
		local chunk, err = loadfile(path)
		if not chunk then
			fail(name, "will not load: " .. tostring(err))
		else
			local ok, runErr = pcall(chunk, dir, H)
			if not ok then fail(name, "threw: " .. tostring(runErr)) end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ report
print("=== scenarios ===")
if #failures == 0 then
	print("all scenarios clean")
else
	for _, f in ipairs(failures) do print("  " .. f) end
end
print("failures: " .. #failures)
