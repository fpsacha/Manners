-- A helper for the scenarios of the buttons for the moment (Prompt/Moments.lua),
-- loaded with dofile(dir .. "/tests/momentskit.lua"); not a scenario itself.
--
-- It installs the stand-ins for the client calls the mock does not model (health
-- and power, a target's cast with the client's return
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
--   Mock.hiddenValues (set by withMage on Forever unless plain: health, mana and the target's cast flag come
--   back hidden, as the owner's check-up says his client gives them, in and out of a fight)
--   Mock.bags[itemId] = count, Mock.itemCooldown[itemId] = { isActive, startTime, duration, secretNumbers }
--   Mock.targetBuffs = { { steal = true | false | "nil" }, ... }; Mock.buffsWithheld (the records'
--   flags come back as hidden values and the index read as a hidden record), Mock.buffsHidden (whole)
--   Mock.indexHidden (only the index read is hidden: the id list and the records stay plain)
--   Mock.falling, Mock.flying, Mock.onTaxi, Mock.aimedAtMe (true, false, Mock.secret(...), nil)
--   The drink (Prompt/MomentsSense.lua): Mock.bags[itemId] = count again (C_Container walks it, the
--   ids in order), Mock.playerLevel (UnitLevel, else the mock's 12), Mock.itemMinLevel[itemId],
--   Mock.itemUnusable[itemId] = true, Mock.mounted, Mock.swimming, Mock.shapeshift (a form number),
--   Mock.drinkAura = true | "secret" | "throw" (the Drink aura on you; else the mock's own answer)

local K = {}
local saved = {}
local installed = false

local function put(name, value)
	if saved[name] == nil then saved[name] = { rawget(_G, name) } end
	rawset(_G, name, value)
end

local MAGE_SPELLS = { 2139, 11958, 1953, 12051, 130, 12472, 45438, 235219, 30449 }
-- The spells that conjure a mana gem, best first on Forever's set.
K.GEM_SPELLS = { 10054, 10053, 3552, 759 }
K.WARD_SPELLS = { 543, 6143 }
K.MAGE_SPELLS = MAGE_SPELLS

local function names()
	local later = Mock.flavour == "tbc" or Mock.flavour == "mists" or Mock.flavour == "mainline"
	return {
		[2139] = "Counterspell", [1953] = "Blink", [12051] = "Evocation", [130] = "Slow Fall",
		[11958] = later and "Cold Snap" or "Ice Block", [12472] = "Cold Snap", [45438] = "Ice Block",
		[235219] = "Cold Snap", [30449] = "Spellsteal",
		[543] = "Fire Ward", [8457] = "Fire Ward", [8458] = "Fire Ward", [10223] = "Fire Ward", [10225] = "Fire Ward",
		[27128] = "Fire Ward", [6143] = "Frost Ward", [8461] = "Frost Ward", [8462] = "Frost Ward",
		[10177] = "Frost Ward", [28609] = "Frost Ward", [32796] = "Frost Ward",
		[759] = "Conjure Mana Agate", [3552] = "Conjure Mana Jade", [10053] = "Conjure Mana Citrine",
		[10054] = "Conjure Mana Ruby", [27101] = "Conjure Mana Emerald",
		[430] = "Drink", [1137] = "Drink", [433] = "Food",
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
		local hidden = c.secret
		if hidden == nil then hidden = Mock.hiddenValues == true end
		if c.notIntNil then ni = Mock.secret(nil)
		elseif hidden then ni = Mock.secret(c.notInterruptible == true)
		else ni = c.notInterruptible == true end
		if hidden then name = Mock.secret(name) end
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
	put("IsFalling", function()
		if Mock.fallingSecret then return Mock.secret(Mock.falling == true) end
		return Mock.falling == true
	end)
	put("IsFlying", function() return Mock.flying == true end)
	put("IsMounted", function() return Mock.mounted == true end)
	put("IsSwimming", function() return Mock.swimming == true end)
	put("GetShapeshiftForm", function() return Mock.shapeshift or 0 end)
	local level = rawget(_G, "UnitLevel")
	put("UnitLevel", function(unit)
		if unit == "player" and Mock.playerLevel then return Mock.playerLevel end
		return level(unit)
	end)
	put("UnitOnTaxi", function() return Mock.onTaxi == true end)
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
			-- The client's spellIdentifier is never nil: a call with none throws.
			if id == nil then error("bad argument #1 to 'GetSpellCooldown' (a spell is needed)", 2) end
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
	-- The target's buffs, as Mock.targetBuffs lists them: plain records; with
	-- Mock.buffsWithheld the index read comes back as a hidden record and each
	-- record's flag as a hidden value; with Mock.buffsHidden the records are hidden whole.
	local function buffRecord(i, entry)
		local flag = entry.steal
		local rec = { auraInstanceID = 100 + i, isHelpful = true }
		if Mock.buffsWithheld then
			if flag == "nil" then rec.isStealable = Mock.secret(nil) else rec.isStealable = Mock.secret(flag == true) end
		elseif flag ~= "nil" then
			rec.isStealable = flag == true
		end
		return rec
	end
	local aurasOut = setmetatable({
		GetAuraDataBySpellName = function(unit, name, filter)
			if unit == "player" and name == "Drink" then
				local mode = Mock.drinkAura
				if mode == "throw" then error("restricted", 0) end
				if mode == "secret" then return Mock.secret({ name = "Drink" }) end
				if mode == true then return { name = "Drink", spellId = 430 } end
			end
			local pass = auras.GetAuraDataBySpellName
			return pass and pass(unit, name, filter) or nil
		end,
		GetPlayerAuraBySpellID = function(id)
			if Mock.playerAuras and Mock.playerAuras[id] then return { spellId = id } end
			return nil
		end,
		GetAuraDataByIndex = function(unit, i, filter)
			if unit ~= "target" then return auras.GetAuraDataByIndex(unit, i, filter) end
			local entry = Mock.targetBuffs and Mock.targetBuffs[i]
			if not entry then return nil end
			if Mock.buffsHidden or Mock.buffsWithheld or Mock.indexHidden then return Mock.secret({}) end
			return buffRecord(i, entry)
		end,
		GetUnitAuraInstanceIDs = function(unit, filter)
			if unit ~= "target" then return {} end
			local list = {}
			for i = 1, #(Mock.targetBuffs or {}) do list[i] = 100 + i end
			return list
		end,
		GetAuraDataByAuraInstanceID = function(unit, id)
			local i = id - 100
			local entry = unit == "target" and Mock.targetBuffs and Mock.targetBuffs[i]
			if not entry then return nil end
			if Mock.buffsHidden then return Mock.secret({}) end
			return buffRecord(i, entry)
		end,
	}, { __index = auras })
	put("C_UnitAuras", aurasOut)
	-- Items: the bags (Mock.bags), their names, and a cooldown by C_Container.
	local itemNames = { [8008] = "Mana Ruby", [8007] = "Mana Citrine", [5513] = "Mana Jade", [5514] = "Mana Agate",
		[22044] = "Mana Emerald", [36799] = "Mana Gem", [17056] = "Light Feather",
		[2288] = "Conjured Fresh Water", [2136] = "Conjured Purified Water", [3772] = "Conjured Spring Water",
		[8077] = "Conjured Mineral Water", [1179] = "Ice Cold Milk", [1645] = "Moonberry Juice",
		[1113] = "Conjured Bread" }
	-- What an item's use casts: the waters and the milk "Drink", the bread "Food".
	local itemSpells = { [2288] = 430, [2136] = 430, [3772] = 430, [8077] = 430, [1179] = 430, [1645] = 430,
		[1113] = 433 }
	local function count(id)
		local n = Mock.bags and Mock.bags[id] or 0
		if Mock.bagsSecret then return Mock.secret(n) end
		return n
	end
	local itemBase = rawget(_G, "C_Item") or _G.C_Item
	put("C_Item", setmetatable({
		GetItemCount = count,
		GetItemNameByID = function(id) return itemNames[id] end,
		GetItemIconByID = function() return 134000 end,
		GetItemSpell = function(id)
			local spell = itemSpells[id]
			if not spell then return nil end
			return names()[spell], spell
		end,
		IsUsableItem = function(id)
			if Mock.itemUnusable and Mock.itemUnusable[id] then return false, false end
			return true, false
		end,
		GetItemInfo = function(id)
			local name = itemNames[id]
			if not name then return nil end
			return name, "|Hitem:" .. id .. "|h[" .. name .. "]|h", 1, 1, Mock.itemMinLevel and Mock.itemMinLevel[id] or 0
		end,
	}, { __index = itemBase }))
	put("GetItemCount", count)
	put("C_Container", {
		GetContainerNumSlots = function() return 20 end,
		GetContainerItemID = function(bag, i)
			if bag ~= 0 then return nil end
			local ids = {}
			for id, n in pairs(Mock.bags or {}) do
				if n > 0 then ids[#ids + 1] = id end
			end
			table.sort(ids)
			return ids[i]
		end,
		GetItemCooldown = function(id)
			local entry = Mock.itemCooldown and Mock.itemCooldown[id]
			if not entry then return 0, 0, 1 end
			local start, duration = entry.startTime or 0, entry.duration or 0
			if entry.secretNumbers then return Mock.secret(start), Mock.secret(duration), 1 end
			return start, duration, 1
		end,
	})
end

-- Mock.reset() leaves a field it does not know alone, so a scenario's own
-- would reach the next one.
local FIELDS = { "health", "healthMax", "healthSecret", "percentScale", "mana", "manaMax", "manaSecret",
	"targetCast", "noTarget", "targetFriendly", "targetDead", "targetOutOfRange", "cooldown", "usable",
	"lockFlag", "playerAuras", "noCurves", "noHealthPercent", "inCooldownEvent", "falling", "aimedAtMe",
	"coverLeaks", "refuseAlphaFromBoolean", "lossOfControl", "lossOfControlShape", "asked", "bags", "bagsSecret",
	"itemCooldown", "targetBuffs", "buffsWithheld", "buffsHidden", "flying", "onTaxi", "dead", "fallingSecret", "indexHidden",
	"playerLevel", "itemMinLevel", "itemUnusable", "mounted", "swimming", "shapeshift", "drinkAura", "hiddenValues" }
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

-- What the client gives of your health, mana and the target's cast flag. On Forever
-- the owner's check-up says all three are hidden, in a fight and out of one, so a
-- scenario there gets hidden values unless it asks for plain ones (opts.plain =
-- true), or its file says K.plain = true at the top (an older file whose scenarios
-- were written for plain values; opts.plain = false takes the hidden ones back).
-- Every other client gives plain values.
K.plain = nil

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
	local plain = opts.plain
	if plain == nil then plain = K.plain == true end
	if Mock.flavour == "camelot" and not plain then
		Mock.hiddenValues = true
		Mock.healthSecret, Mock.manaSecret = true, true
	end
	local ok, err = true, nil
	local ns = H.load(scenario)
	if ns then
		ok, err = pcall(function()
			-- opts.preload(ns): the addon is loaded but has not started, so the
			-- profile's defaults can be changed before any button is made.
			if opts.preload then opts.preload(ns) end
			H.freshPrompt(ns, scenario)
			-- The flush the first refresh scheduled runs before the timers are dropped, or
			-- its "due" flag would stay set for the whole scenario.
			Mock.runTimers(0.2)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.db.profile.verbose = true
			if opts.edit then opts.edit(ns.db.profile, ns) end
			ns.Prompt:ApplyStyle()
			local button = ns.Prompt:GetButton()
			button._left, button._bottom = 600, 400
			if not opts.noBuild then
				-- Placed where the prompt now stands: a scan that finds nothing new learned
				-- does not place the buttons again.
				ns.Moments:Refresh()
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
	for n = 1, 11 do
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

-- Bags, spells or switches changed after the addon started: learned again and
-- the scan run, the way a probe and the next tick do it.
function K.relearn(ns)
	ns.Moments.Learn()
	ns.addon:Tick()
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

-- Time passes with the fall watch running: its OnUpdate by hand, each 0.2 s, for
-- as long as it is shown (hidden, it asks the client nothing).
function K.fallTick(ns, seconds)
	local watch = ns.Moments:Watch()
	local steps = math.max(1, math.floor((seconds or 0.2) / 0.2 + 0.5))
	for _ = 1, steps do
		Mock.runTimers(0.2)
		if watch and watch:IsShown() then watch.scripts.OnUpdate(watch, 0.2) end
	end
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
