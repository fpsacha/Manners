-- Scenario tests. The plain harness drives the happy path; this drives the
-- states the addon actually has to survive: a class with nothing to give, a
-- dead player, combat lockdown, a client that makes everything secret, a
-- profile full of nonsense, and the modes that disable casting.
--
-- Anything that throws here would, in game, be a silent failure: a timer that
-- stops running, or a prompt that sits there doing nothing.

local dir = ...
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
-- A pinned buff belonging to a different class must not survive.
Mock.reset()
Mock.class = "PRIEST"
ns = load("pinned buff from another class")
if ns then
	drive("pinned buff from another class", ns)
	ns.db.profile.buff.choice = "intellect" -- a mage buff, on a priest
	ns.ClampSettings()
	if ns.db.profile.buff.choice ~= "auto" then
		fail("pinned buff from another class", "kept a buff this class cannot cast")
	end
	local ok, err = pcall(function() return ns.BuildQueue() end)
	if not ok then fail("pinned buff from another class", "BuildQueue threw: " .. tostring(err)) end
end

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

	-- Off is the cheapest way to empty the prompt. PreClick's own disabled
	-- branch sits below the one under test, so it cannot be what answers.
	ns.db.profile.enabled = false
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

	-- A sound from an addon that has since been uninstalled. Fetch falls back
	-- to "None" for a key it does not know, which is the same silence again.
	ns.db.profile.sound.file = "Gone With The Addon"
	ns.ClampSettings()
	if ns.db.profile.sound.file ~= ns.SOUND_KEY then
		fail("ticking play a sound makes a sound",
			"a dead sound key survived the clamp: " .. tostring(ns.db.profile.sound.file))
	end

	-- And the other half of the same trap: Fetch without noDefault answers an
	-- unknown key with "None" -- the number 1 -- so the addon would "play" a
	-- sound nobody can hear instead of saying nothing.
	Mock.sounds = {}
	ns.PlayPromptSound("Gone With The Addon")
	if #Mock.sounds > 0 then
		fail("ticking play a sound makes a sound",
			"played " .. tostring(Mock.sounds[1]) .. " for a sound that is not installed")
	end

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
-- restarts near zero on every login, so a debt stored in those units comes back
-- either already expired or an hour long.
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
	a.owed["Mira Tallow"] = { expires = GetTime() + 300, at = GetTime() - 100 }

	-- Fired the way AceDB fires it, so the wiring is under test and not just
	-- the two functions behind it.
	local shutdown = Mock.dbCallbacks["OnDatabaseShutdown"]
	if not shutdown then
		fail("debts survive a reload", "nothing is listening for the logout flush")
	else
		local ok = pcall(function() shutdown.target[shutdown.method](shutdown.target) end)
		if not ok then fail("debts survive a reload", "the logout flush threw") end
	end

	-- Thirty seconds pass on both clocks, then the client restarts: the wall
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
			-- longer one cannot be used to out-wait the current setting.
			local left = old.expires - GetTime()
			if left < 115 or left > 125 then
				fail("debts survive a reload",
					("an over-long debt came back with %s seconds left, not the 120 the window allows")
						:format(tostring(math.floor(left))))
			end
			local age = GetTime() - old.at
			if age < 125 or age > 135 then
				fail("debts survive a reload",
					("a debt that was already 100 seconds old came back %s seconds old, not about 130")
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
		local entry = queue[1]
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
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()

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
		-- that is no longer consulted.
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
		local function settleAfter(gap)
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
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours)
			if ns.owed[name] then
				fail(scenario, "SKIPPED -- the send never settled, so there is no"
					.. " confirmation to undo")
				return false
			end
			return true
		end

		local function sendAndConfirm() return settleAfter(3) end

		-- The server's answer, one frame later, on the one event that names the
		-- spell it is refusing.
		if sendAndConfirm() then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, ours)

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
		-- confirmation down with it.
		if sendAndConfirm() then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, 999999)
			if ns.owed[name] then
				fail(scenario, "an unrelated spell failing undid a confirmed cast")
			end
		end

		-- Nor a failure the client would not name. Everywhere else in this addon
		-- an unreadable value has to settle, because one withheld number must not
		-- make a favour permanent -- but here the same leniency reopens a repaid
		-- debt on no evidence whatever, so it is refused in this direction only.
		if sendAndConfirm() then
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
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, ours)
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
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, ours)
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
		if not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the preview would not start")
		else
			ns.Prompt:Refresh()
			if regions.art:GetAlpha() >= 1 then
				fail(scenario, "the preview took the dim off in the middle of a fight, so the"
					.. " prompt looks live while its macro cannot be pointed anywhere")
			end

			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
			if not ns.Prompt:InTest() then
				fail(scenario, "SKIPPED -- the preview ended with the fight")
			elseif regions.art:GetAlpha() < 1 then
				fail(scenario, ("the fight ended and the preview stayed dimmed at %s: the"
					.. " release is at the bottom of Refresh and preview returns above it")
					:format(tostring(regions.art:GetAlpha())))
			end
		end
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
			-- half, because a mock-up has nothing true to say about a fight.
			--
			-- The panel is put down first, by the scenario rather than by the
			-- addon. A Show is only reached at all when the fight found the
			-- prompt hidden, so a preview started over a panel that is already up
			-- never touches the protected half and proves nothing about it.
			button:Hide()
			Mock.protectedCalls = {}
			if not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
			if not ns.Prompt:InTest() then
				fail(scenario, "SKIPPED -- the preview would not start")
			else
				ns.Prompt:Refresh()
				if #Mock.protectedCalls > 0 then
					fail(scenario, "a preview started over a panel the fight found hidden called "
						.. table.concat(Mock.protectedCalls, ", ") .. " on the secure button,"
						.. " which is the one call that would have made it appear and the one"
						.. " the client refuses")
				end
				ns.Prompt:ToggleTest()
			end
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
	-- them rather than counted out of a table by hand.
	local seen, distinct = {}, 0
	for _, reason in ipairs({ "target", "owed", "group", "nearby" }) do
		local r, g, b = ns.Prompt:AccentColor(reason)
		local key = ("%.3f/%.3f/%.3f"):format(r, g, b)
		if not seen[key] then
			seen[key] = true
			distinct = distinct + 1
		end
	end

	local toggle = ns.optionsTable and ns.optionsTable.args.appearance.args.accentByReason
	local desc = toggle and (type(toggle.desc) == "function" and toggle.desc() or toggle.desc)
	if type(desc) ~= "string" then
		fail(scenario, "SKIPPED -- the reason-colour toggle has no description to read")
	else
		local named = 0
		for _, word in ipairs({ "green", "amber", "blue", "grey" }) do
			if desc:lower():find(word, 1, true) then named = named + 1 end
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
-- is now gone. There is no version of it that works: a secure visibility driver
-- wants macro conditionals, which this client does not resolve.
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
		-- anything printed is by definition not the favour line.
		ns.pendingClick = { name = "Ana Field", at = GetTime() - 30, buffKey = "intellect" }
		ns.Guard("expire", ns.ExpirePendingClick)
		local said = table.concat(Mock.printed, " | ")
		local text = ((type(verbose.name) == "function" and verbose.name() or verbose.name)
			.. " " .. (type(verbose.desc) == "function" and verbose.desc() or verbose.desc)):lower()

		if said == "" then
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
		--     next press. This is the one that needed no guid to go wrong.
		wipe(ns.owed)
		if press("Elara Brightmoor", nil) then
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, spell)
			if not ns.owed["Elara Brightmoor"] then
				fail(scenario, "SKIPPED -- the first refusal did not land")
			else
				wipe(ns.owed)
				Mock.advance(0.4)
				if press("Corvin Ashgrove", nil) then
					ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", nil, spell)
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
		--     damage plus a false sentence about somebody who was buffed.
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

-- ------------------------------------------------------------------ report
print("=== scenarios ===")
if #failures == 0 then
	print("all scenarios clean")
else
	for _, f in ipairs(failures) do print("  " .. f) end
end
print("failures: " .. #failures)
