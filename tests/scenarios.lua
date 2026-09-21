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
	for _, file in ipairs({ "Buffs.lua", "Core.lua", "Prompt.lua", "Options.lua" }) do
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

		-- Exactly one /target line, whatever shape the name is, and the full
		-- name is what goes in it. Offering the bare first name underneath it
		-- as well reads as belt and braces, but /targetlasttarget hands you
		-- back the target the line before last set -- so a second /target line
		-- makes "restore my target" mean "whoever the first name found", and
		-- two people with the same first name is all that takes. Where the full
		-- name will not resolve, scenario 55 covers what replaces it.
		if macro and entry and entry.buff and not entry.buff.selfCast then
			local targets = {}
			for line in macro:gmatch("[^\r\n]+") do
				if line:find("^/target ") then targets[#targets + 1] = line end
			end
			local label = tostring(pair[1]) .. "/" .. tostring(pair[2])
			local full = pair[1] .. ((pair[2] and pair[2] ~= "") and (" " .. pair[2]) or "")
			if #targets ~= 1 then
				fail("odd names", label .. ": " .. #targets .. " /target lines, not 1")
			elseif targets[1] ~= "/target " .. full then
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
		"{name}{unit}{first}{spell}{id}",
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
						local lineCount, castLine, targetLine = 0, false, false
						for line in macro:gmatch("[^\r\n]+") do
							lineCount = lineCount + 1
							if not line:find("^/%a") then
								fail(label, "not a command: '" .. line .. "'")
							end
							if line:find("^/cast ") then castLine = true end
							if line:find("^/target ") then targetLine = true end
						end
						if not castLine then fail(label, "macro never casts") end
						if #macro > cns.MACRO_LIMIT then
							fail(label, "macro is " .. #macro .. " characters, over the limit")
						end

						-- Battle Shout reaches the party from you; targeting
						-- somebody would be wrong, not merely unnecessary.
						if target.selfCast then
							if targetLine then fail(label, "selfCast buff still built a /target line") end
							if lineCount ~= 1 then
								fail(label, "selfCast macro should be one line, got " .. lineCount)
							end
						else
							if not targetLine then fail(label, "no /target line for a targeted buff") end
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
	local general = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.general
	local file = general and general.args and general.args.file
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
		Mock.sounds = {}
		file.set({ "file" }, ns.SOUND_KEY)
		if ns.db.profile.sound.file ~= ns.SOUND_KEY then
			fail("ticking play a sound makes a sound", "picking a sound did not store it")
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
				- #("/target Somebody\n/cast " .. ns.BuffName(entry.buff))
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

	-- Nothing on you, and every slot said so plainly.
	Mock.noAuras = true
	ns.addon:PLAYER_ENTERING_WORLD()
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

-- ------------------------------------------------------------------ 55
-- One /target line means the full name has to carry it, and a full name this
-- client will not resolve is a no-op: the cast goes to whoever you already had
-- -- or, far more often, because most of the time you are holding nobody, it
-- goes nowhere at all and the game simply refuses. Neither shape announces
-- itself as a name problem, and the error strings that would tell them apart
-- are localised and unread here, so the fallback is inferred from a run of
-- failures rather than from one event, only ever for a macro that carried a
-- /target of ours, and it is withdrawn the moment it is caught doing harm.
--
-- The earlier design set it on one event, on the one branch that requires you
-- to have had a target already -- so the commonest case, no target at all,
-- could never reach it, and those people stayed unbuffable for the session.
Mock.reset()
ns = load("a full name that will not resolve is learned")
if ns then
	local scenario = "a full name that will not resolve is learned"
	drive(scenario, ns)
	Mock.advance(60)
	local queue = ns.BuildQueue()
	local entry = queue[1]
	local first = entry and ns.FirstName(entry.name)
	if not entry or not entry.buff or not first then
		fail(scenario, "SKIPPED -- nobody with a two-word name to aim at")
	else
		local name, buffKey = entry.name, entry.buff.key
		local ours = ns.FindBuff(ns.caps.class, buffKey).ranks[1]
		local button = ns.Prompt:GetButton()

		local function targets()
			local lines = {}
			for line in (ns.lastMacro or ""):gmatch("[^\r\n]+") do
				if line:find("^/target ") then lines[#lines + 1] = line end
			end
			return lines, table.concat(lines, " | ")
		end

		-- A real press every time. What the macro carried is now recorded by the
		-- press itself rather than reconstructed at settle time, so a pending
		-- click assembled by hand here would prove nothing about the path that
		-- actually runs -- it would simply skip the recording under test.
		local function press()
			Mock.advance(1)
			ns.pendingClick = nil
			ns.tried[name .. "\0*"] = nil
			ns.tried[name .. "\0" .. buffKey] = nil
			ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }
			ns.Prompt:ApplyTarget(entry)
			local post = button.scripts.PostClick
			if post then pcall(post, button, "LeftButton", true) end
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- the press left nothing to settle")
				return false
			end
			return true
		end

		local function refused()
			if press() then ns.addon:UI_ERROR_MESSAGE(nil, nil, "Out of range.") end
		end

		-- Back to knowing nothing about this name. The run of failures is zeroed
		-- the only way the addon itself zeroes it -- a settle that did reach them
		-- -- because that counter is working-out rather than state anything
		-- outside the settle path has any business reaching into. It is asserted
		-- on its own further down, so a broken one cannot quietly hold this
		-- together.
		local function forget()
			ns.firstNameOnly[name] = nil
			if press() then ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours) end
			ns.Prompt:InvalidateMacro()
		end

		forget()
		ns.Prompt:ApplyTarget(entry)
		local lines, shown = targets()
		if #lines ~= 1 or lines[1] ~= "/target " .. name then
			fail(scenario, "the first offer did not aim the full name: " .. shown)
		end

		-- One refusal is not evidence about a name: /target only reaches who you
		-- can see, so it is far more often somebody stepping behind a pillar.
		refused()
		if ns.firstNameOnly[name] then
			fail(scenario, "a single refusal put somebody on a bare first name, which is how"
				.. " two people who share one get each other's buffs")
		end

		-- Two in a row is. This is the arrival that was unreachable before: no
		-- target, so the /target is a no-op and the /cast has nothing to aim at,
		-- and the game refuses outright -- the branch that deliberately learned
		-- nothing.
		refused()
		if not ns.firstNameOnly[name] then
			fail(scenario, "a run of casts that went nowhere taught it nothing about the name,"
				.. " so this person can never be buffed")
		end

		-- No InvalidateMacro on purpose: the memo has to carry the fallback, or
		-- the button keeps a spelling we have just watched fail twice.
		ns.Prompt:ApplyTarget(entry)
		lines, shown = targets()
		if #lines ~= 1 or lines[1] ~= "/target " .. first then
			fail(scenario, "the next offer still aimed a name that does not resolve: " .. shown)
		end

		-- Caught doing harm. The bare first name is on the macro now, and the
		-- spell went to somebody who is not the person offered: the neighbour who
		-- shares that first name, standing right there. Confirming the flag on
		-- exactly the event that disproves it is what aimed one person at another
		-- for the rest of a session.
		if press() then
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Someone Else", nil, ours)
			if ns.firstNameOnly[name] then
				fail(scenario, "a first-name cast landing on the wrong player re-confirmed the"
					.. " fallback instead of withdrawing it")
			end
		end
		ns.Prompt:ApplyTarget(entry)
		lines, shown = targets()
		if #lines ~= 1 or lines[1] ~= "/target " .. name then
			fail(scenario, "the full name never came back: " .. shown)
		end

		-- And it gets no second turn: the neighbour does not stop sharing the
		-- name, so a fresh run of refusals must not re-arm what has been watched
		-- handing this person's buff to somebody else.
		refused()
		refused()
		refused()
		if ns.firstNameOnly[name] then
			fail(scenario, "the fallback re-armed itself after being caught aiming at the"
				.. " wrong player")
		end

		-- A settle that did reach them puts the run back to nothing, so a long
		-- afternoon of one refusal in three never quietly adds up to a flag.
		forget()
		refused()
		if press() then ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, nil, ours) end
		refused()
		if ns.firstNameOnly[name] then
			fail(scenario, "refusals either side of a cast that worked were counted as a run")
		end

		-- Only our own spell says anything about our own /target line. Anything
		-- else going out inside the two-second window is the player casting by
		-- hand, and it used to be filed as evidence about this person's name.
		forget()
		if press() then ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Someone Else", nil, 999999) end
		if press() then ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Someone Else", nil, 999999) end
		if ns.firstNameOnly[name] then
			fail(scenario, "spells this addon never cast were read as evidence about a name")
		end

		-- A macro with no /target of ours in it is evidence about nobody.
		-- /manners try arms whatever was typed, and the shape you reach for while
		-- working out what this client resolves is one that casts nothing at all:
		-- it parks a click that never settles, and the next thing pressed on the
		-- bar was blamed on the person being offered.
		forget()
		ns.addon:HandleSlash("try /target {name}")
		refused()
		refused()
		refused()
		ns.addon:HandleSlash("try")
		if ns.firstNameOnly[name] then
			fail(scenario, "a macro this addon did not write was blamed on somebody's name")
		end
		forget()
	end
	wipe(ns.owed)
end

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
		-- It runs out. Nothing is owed for a buff ending.
		wipe(ns.owed)
		Mock.extraAura = false
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
			ns.firstNameOnly[name] = nil
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
			if ns.firstNameOnly[name] then
				fail(scenario, "a macro with no /target in it was blamed on the person's name")
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

		-- And while it was not being believed, the buff ran out for real.
		Mock.auraHidden = nil
		Mock.extraAura = false
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
		local function offeredNow()
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == name then return e.buff.key end
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

		-- The mirror. A client that says outright they are carrying none of
		-- ours is evidence the cast did not land, and then reaching for the next
		-- blessing is right. Without this, "a paladin is offered one blessing
		-- and never another" would pass everything above.
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
			local readableKey = readable.buff.key
			ns.Prompt:ApplyTarget(readable)
			if post then pcall(post, button, "LeftButton", true) end
			Mock.advance(1)
			local after = offeredNow()
			if after == nil then
				fail(scenario, "a paladin whose cast provably never landed was dropped from the prompt")
			elseif after == readableKey then
				fail(scenario, "a blessing the client says is not there was offered again unchanged")
			end
		end
	end

	IsSpellKnown = realKnown
	IsPlayerSpell = realKnown
	wipe(ns.owed)
end

-- ------------------------------------------------------------------ report
print("=== scenarios ===")
if #failures == 0 then
	print("all scenarios clean")
else
	for _, f in ipairs(failures) do print("  " .. f) end
end
print("failures: " .. #failures)
