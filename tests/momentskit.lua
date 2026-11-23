-- A helper for the scenarios of the buttons for the moment (Prompt/Moments.lua),
-- loaded with dofile(dir .. "/tests/momentskit.lua"); not a scenario itself.
--
-- It installs the stand-ins for the client calls the mock does not model (health
-- and power in the shapes of Forever, a target's cast with the client's return
-- positions, curves, a spell's cooldown with isOnGCD filled only inside the
-- cooldown event, the per-spell loss-of-control flag, ...), each reading a Mock
-- field, and hands back the helpers a scenario drives a fight with. Everything
-- goes through Mock.deliver, so an event nobody registered for does nothing.
--
-- Mock fields it reads:
--   Mock.health, Mock.healthMax, Mock.healthSecret, Mock.percentScale
--   Mock.mana, Mock.manaMax, Mock.manaSecret
--   Mock.targetCast = { channel, notInterruptible, secret, notIntNil, name }
--   Mock.noTarget, Mock.targetFriendly, Mock.targetDead, Mock.targetOutOfRange
--   Mock.cooldown[id] = { isActive, isOnGCD, startTime, duration, secretNumbers }
--   Mock.usable[id] = { usable, noMana }
--   Mock.lockFlag[id] = true | false
--   Mock.playerAuras[id] = true
--   Mock.noAlphaFromBoolean, Mock.noCurves, Mock.noHealthPercent

local K = {}
local saved = {}
local installed = false

local function put(name, value)
	if saved[name] == nil then saved[name] = { rawget(_G, name) } end
	rawset(_G, name, value)
end

local MAGE_SPELLS = { 2139, 11958, 1953, 12051, 130, 12472, 45438, 235219, 30449 }
K.MAGE_SPELLS = MAGE_SPELLS

local function names()
	local later = Mock.flavour == "tbc" or Mock.flavour == "mists" or Mock.flavour == "mainline"
	return {
		[2139] = "Counterspell", [1953] = "Blink", [12051] = "Evocation", [130] = "Slow Fall",
		[11958] = later and "Cold Snap" or "Ice Block", [12472] = "Cold Snap", [45438] = "Ice Block",
		[235219] = "Cold Snap", [30449] = "Spellsteal",
	}
end

-- A curve as the game's C_CurveUtil makes one: points, a type, an evaluator.
local function makeCurve()
	local curve = { points = {} }
	function curve:SetType(kind) self.kind = kind end
	function curve:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
	function curve:Evaluate(x)
		local pts = self.points
		if #pts == 0 then return 0 end
		if x <= pts[1][1] then return pts[1][2] end
		for i = 2, #pts do
			if x <= pts[i][1] then
				local a, b = pts[i - 1], pts[i]
				if b[1] == a[1] then return b[2] end
				return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
			end
		end
		return pts[#pts][2]
	end
	return curve
end

local function share(cur, max, secret, curve, scale)
	local fraction = max > 0 and cur / max or 0
	local value
	if curve then value = curve:Evaluate(fraction * scale) else value = fraction * scale end
	if secret then return Mock.secret(value) end
	return value
end

function K.install()
	if installed then return end
	installed = true
	local casting, channel = rawget(_G, "UnitCastingInfo"), rawget(_G, "UnitChannelInfo")
	local exists, dead = rawget(_G, "UnitExists"), rawget(_G, "UnitIsDeadOrGhost")
	local function hp() return Mock.health or 100, Mock.healthMax or 100 end
	local function mp() return Mock.mana or 100, Mock.manaMax or 100 end
	put("UnitHealth", function()
		local h = hp()
		if Mock.healthSecret then return Mock.secret(h) end
		return h
	end)
	put("UnitHealthMax", function()
		local _, m = hp()
		if Mock.healthSecret then return Mock.secret(m) end
		return m
	end)
	if not Mock.noHealthPercent then
		put("UnitHealthPercent", function(_, _, curve)
			local h, m = hp()
			return share(h, m, Mock.healthSecret, curve, Mock.percentScale or 1)
		end)
		put("UnitPowerPercent", function(_, _, _, curve)
			local c, m = mp()
			return share(c, m, Mock.manaSecret, curve, Mock.percentScale or 1)
		end)
	end
	put("UnitPower", function()
		local c = mp()
		if Mock.manaSecret then return Mock.secret(c) end
		return c
	end)
	put("UnitPowerMax", function()
		local _, m = mp()
		if Mock.manaSecret then return Mock.secret(m) end
		return m
	end)
	put("UnitExists", function(unit)
		if unit == "target" and Mock.noTarget then return false end
		return exists(unit)
	end)
	put("UnitIsDeadOrGhost", function(unit)
		if unit == "target" then return Mock.targetDead == true end
		return dead(unit)
	end)
	put("UnitCanAttack", function(_, unit)
		if unit == "target" then return not Mock.noTarget and not Mock.targetFriendly end
		return false
	end)
	local function targetCast(want)
		local c = Mock.targetCast
		if not c or (c.channel == true) ~= want then return nil end
		local name = c.name or "Frostbolt"
		local ni
		if c.notIntNil then ni = Mock.secret(nil)
		elseif c.secret then ni = Mock.secret(c.notInterruptible == true)
		else ni = c.notInterruptible == true end
		if c.secret then name = Mock.secret(name) end
		return name, ni
	end
	put("UnitCastingInfo", function(unit)
		if unit ~= "target" then return casting(unit) end
		local name, ni = targetCast(false)
		if name == nil then return nil end
		-- name, displayName, textureID, startMs, endMs, isTradeskill, castID, notInterruptible, spellID
		return name, "", 135812, 0, 3000, false, "Cast-mock", ni, 116
	end)
	put("UnitChannelInfo", function(unit)
		if unit ~= "target" then return channel and channel(unit) end
		local name, ni = targetCast(true)
		if name == nil then return nil end
		-- name, displayName, textureID, startMs, endMs, isTradeskill, notInterruptible, spellID
		return name, "", 135812, 0, 3000, false, ni, 5143
	end)
	put("IsFalling", function() return Mock.falling == true end)
	put("IsFlying", function() return false end)
	put("PlayerIsSpellTarget", function() return Mock.aimedAtMe end)
	put("Enum", rawget(_G, "Enum") or {})
	Enum = rawget(_G, "Enum")
	Enum.LuaCurveType = Enum.LuaCurveType or { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 }
	Enum.PowerType = Enum.PowerType or { Mana = 0 }
	if not Mock.noCurves then
		put("C_CurveUtil", {
			CreateCurve = makeCurve,
			EvaluateColorValueFromBoolean = function(value, ifTrue, ifFalse)
				local shown = Mock.reveal(value)
				if type(shown) ~= "boolean" then error("not a boolean", 2) end
				local out = shown and Mock.reveal(ifTrue) or Mock.reveal(ifFalse)
				if Mock.isSecret(value) or Mock.isSecret(ifTrue) or Mock.isSecret(ifFalse) then return Mock.secret(out) end
				return out
			end,
		})
	end
	-- C_Spell: the mock's own with the calls these buttons ask of the client.
	local base = rawget(_G, "C_Spell")
	if base == nil then base = _G.C_Spell end
	local spells = setmetatable({
		GetSpellName = function(id) return names()[id] or "Arcane Intellect" end,
		GetSpellTexture = function() return 135932 end,
		GetSpellCooldown = function(id)
			local entry = Mock.cooldown and Mock.cooldown[id]
			if not entry then return nil end
			local rec = { isActive = entry.isActive, startTime = entry.startTime or 0, duration = entry.duration or 0 }
			if Mock.inCooldownEvent then rec.isOnGCD = entry.isOnGCD end
			if entry.secretNumbers then
				rec.startTime, rec.duration = Mock.secret(rec.startTime), Mock.secret(rec.duration)
			end
			if entry.secretActive then rec.isActive = Mock.secret(entry.isActive) end
			return rec
		end,
		IsSpellUsable = function(id)
			local entry = Mock.usable and Mock.usable[id]
			if not entry then return true, false end
			return entry.usable, entry.noMana == true
		end,
		IsSpellInRange = function(_, unit)
			if unit == "target" and Mock.targetOutOfRange then return false end
			return true
		end,
		GetSpellLossOfControlCooldownInfo = function(id)
			local flag = Mock.lockFlag and Mock.lockFlag[id]
			if flag == nil then return nil end
			return { isActive = flag }
		end,
	}, { __index = base })
	put("C_Spell", spells)
	local auras = rawget(_G, "C_UnitAuras") or _G.C_UnitAuras
	local aurasOut = setmetatable({
		GetPlayerAuraBySpellID = function(id)
			if Mock.playerAuras and Mock.playerAuras[id] then return { spellId = id } end
			return nil
		end,
	}, { __index = auras })
	put("C_UnitAuras", aurasOut)
end

-- Mock.reset() leaves a field it does not know alone, so a scenario's own
-- would reach the next one.
local FIELDS = { "health", "healthMax", "healthSecret", "percentScale", "mana", "manaMax", "manaSecret",
	"targetCast", "noTarget", "targetFriendly", "targetDead", "targetOutOfRange", "cooldown", "usable",
	"lockFlag", "playerAuras", "noCurves", "noHealthPercent", "inCooldownEvent", "falling", "aimedAtMe",
	"coverLeaks", "refuseAlphaFromBoolean", "lossOfControl", "lossOfControlShape", "asked" }
function K.clear()
	for _, field in ipairs(FIELDS) do Mock[field] = nil end
end

function K.restore()
	if not installed then return end
	installed = false
	for name, old in pairs(saved) do rawset(_G, name, old[1]) end
	saved = {}
	K.clear()
end

-- Forever unless opts.flavour: a mage who knows the spells (opts.known: a set,
-- or false for none), the profile edited by opts.edit(profile, ns), a binding
-- table in opts.bindings (key -> command), opts.preload(ns) before it starts,
-- opts.count (names of calls to count in Mock.asked), and the prompt placed with room on
-- its left. opts.noBuild leaves the tick undone.
function K.withMage(H, scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	K.clear()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.class then Mock.class = opts.class end
	K.install()
	-- opts.count: globals (or "Table.field" calls) wrapped before the addon loads, so
	-- the locals it keeps count too; Mock.asked[name] is how often each was called.
	Mock.asked = {}
	for _, call in ipairs(opts.count or {}) do
		local owner, field = call:match("^(.-)%.(.+)$")
		Mock.asked[call] = 0
		if owner then
			local t = rawget(_G, owner)
			local real = t[field]
			t[field] = function(...) Mock.asked[call] = Mock.asked[call] + 1 return real(...) end
		else
			local real = rawget(_G, call)
			put(call, function(...) Mock.asked[call] = Mock.asked[call] + 1 return real(...) end)
		end
	end
	if opts.known ~= false then
		Mock.knownSpells = {}
		for _, id in ipairs(opts.known or MAGE_SPELLS) do Mock.knownSpells[id] = true end
	end
	Mock.bindings = opts.bindings
	Mock.health, Mock.healthMax, Mock.mana, Mock.manaMax = 100, 100, 100, 100
	local ok, err = true, nil
	local ns = H.load(scenario)
	if ns then
		ok, err = pcall(function()
			-- opts.preload(ns): the addon is loaded but has not started, so the
			-- profile's defaults can be changed before any button is made.
			if opts.preload then opts.preload(ns) end
			H.freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.db.profile.verbose = true
			if opts.edit then opts.edit(ns.db.profile, ns) end
			ns.Prompt:ApplyStyle()
			local button = ns.Prompt:GetButton()
			button._left, button._bottom = 600, 400
			if not opts.noBuild then
				ns.addon:Tick()
				Mock.runTimers(0)
				K.protect(ns)
			end
			body(ns, scenario, ns.db.profile)
			for _, e in ipairs(ns.errors or {}) do
				H.fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	Mock.inCombat = false
	K.restore()
	Mock.reset()
	if not ok then H.fail(scenario, "threw: " .. tostring(err)) end
end

-- The moment buttons are the secure ones: the mock watches what is called on
-- them under the lockdown.
function K.protect(ns)
	for n = 1, 10 do
		local b = ns.Moments:Button(n)
		if b then Mock.protect(b) end
	end
end

function K.pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

function K.release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
	K.protect(ns)
end

-- An event to the moments frame only, as the client delivers it.
function K.event(ns, name, unit, ...)
	local frame = ns.Moments:Frame()
	if not frame then return false end
	return Mock.deliver(frame, name, unit, ...)
end

-- A cast begins on the target (opts: channel, notInterruptible, secret,
-- notIntNil), and the start event arrives.
function K.cast(ns, opts)
	Mock.targetCast = opts or {}
	local event = (opts and opts.channel) and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START"
	return K.event(ns, event, "target")
end

-- It ends: the info is gone (unless `stale`, for a read the same frame may still
-- see) and the stop event arrives.
function K.endCast(ns, event, stale)
	if not stale then Mock.targetCast = nil end
	return K.event(ns, event or "UNIT_SPELLCAST_STOP", "target")
end

function K.cooldownEvent(ns)
	Mock.inCooldownEvent = true
	local heard = K.event(ns, "SPELL_UPDATE_COOLDOWN")
	Mock.inCooldownEvent = false
	return heard
end

-- Time passes: timers run (the flush, the recheck) and the fader walks.
function K.tick(ns, seconds)
	-- A hair over: the fader's 0.2 s is reached by the clock, not almost.
	seconds = (seconds or 0.3) + 0.01
	local steps = math.max(1, math.floor(seconds / 0.1 + 0.5))
	for _ = 1, steps do
		Mock.runTimers(seconds / steps)
		local fader = ns.Moments:Fader()
		local run = fader and fader.scripts and fader.scripts.OnUpdate
		if run and fader:IsShown() then run(fader, seconds / steps) end
	end
end

-- What the player sees of a button's art: face x inner, 0 when anything above is hidden.
function K.shown(ns, n)
	local slot = ns.Moments:Slot(n)
	if not slot then return 0 end
	return Mock.shownAlpha(slot.inner)
end

function K.click(ns, n)
	return Mock.clickAt(ns.Moments:Button(n))
end

-- The macro a button has armed, or nil.
function K.macro(ns, n)
	local b = ns.Moments:Button(n)
	return b and b:GetAttribute("macrotext1") or nil
end

return K
