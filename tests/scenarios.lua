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
		local ok, err = pcall(function()
			local queue = ns.BuildQueue()
			if #queue == 0 then error("no candidates for this name", 0) end
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
-- Only the left button casts. AnyDown registration sends every button through
-- the click handlers, and a right-press to turn the camera used to burn the
-- candidate without casting anything.
Mock.reset()
ns = load("only the left button casts")
if ns then
	drive("only the left button casts", ns)
	Mock.advance(60)
	local button = ns.Prompt:GetButton()
	local queue = ns.BuildQueue()
	if #queue == 0 then
		fail("only the left button casts", "SKIPPED -- nobody to offer")
	else
		ns.Prompt:ApplyTarget(queue[1])
		local name = queue[1].name

		-- drive() already clicked once, which left this name in `tried`.
		-- Clear it so the check below measures the right-press and nothing else.
		ns.tried[name] = nil
		ns.owed[name] = { expires = GetTime() + 100, at = GetTime() }

		local post = button.scripts.PostClick
		if post then pcall(post, button, "RightButton", true) end
		if ns.tried[name] then
			fail("only the left button casts", "a right-press burned the candidate")
		end
		if not ns.owed[name] then
			fail("only the left button casts", "a right-press cleared the favour")
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

-- ------------------------------------------------------------------ report
print("=== scenarios ===")
if #failures == 0 then
	print("all scenarios clean")
else
	for _, f in ipairs(failures) do print("  " .. f) end
end
print("failures: " .. #failures)
