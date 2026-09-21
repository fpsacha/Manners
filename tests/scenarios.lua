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

		-- Whether the game wants "Petra" or "Petra Stonewell" is not something
		-- an addon can find out, so the macro offers both: first name first,
		-- full name last, because a /target that resolves nothing is a no-op
		-- and the more specific form has to be the one that wins.
		if macro and entry and entry.buff and not entry.buff.selfCast then
			local targets = {}
			for line in macro:gmatch("[^\r\n]+") do
				if line:find("^/target ") then targets[#targets + 1] = line end
			end
			local label = tostring(pair[1]) .. "/" .. tostring(pair[2])
			if pair[2] and pair[2] ~= "" then
				if #targets ~= 2 then
					fail("odd names", label .. ": " .. #targets .. " /target lines, not 2")
				else
					if targets[1] ~= "/target " .. pair[1] then
						fail("odd names", label .. ": first target line is '" .. targets[1] .. "'")
					end
					if targets[2] ~= "/target " .. pair[1] .. " " .. pair[2] then
						fail("odd names", label .. ": second target line is '" .. targets[2] .. "'")
					end
				end
			elseif #targets ~= 1 then
				-- One word, nothing to fall back to: a duplicate line here is
				-- wasted macro budget and a second chance to target somebody else.
				fail("odd names", label .. ": " .. #targets .. " /target lines for a one-word name")
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

-- ------------------------------------------------------------------ report
print("=== scenarios ===")
if #failures == 0 then
	print("all scenarios clean")
else
	for _, f in ipairs(failures) do print("  " .. f) end
end
print("failures: " .. #failures)
