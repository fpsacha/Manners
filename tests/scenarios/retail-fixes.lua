-- Round 30, retail: what the bug hunt found on retail Midnight 12.1.
--
-- UNIT_AURA's unit token compared while it is secret. Retail 12.1's
-- UnitAuraDocumentation.lua (live branch, build 12.1.0.69933) tags the event
-- SecretWhenAurasRestricted with no NeverSecret on either payload field, and
-- the 12.1.0 API changes (warcraft.wiki.gg, Patch_12.1.0/API_changes, PTR 3
-- and PTR 4) say the event "now delivers a fully secret payload while auras
-- are secret": a fight, an encounter, a keystone, a PvP match
-- (SecretPredicatesDocumentation, SecretWhenAurasRestricted). Comparing a
-- secret from addon code is an immediate Lua error (warcraft.wiki.gg,
-- Secret_Values), and UnitGUID's arguments are AllowedWhenUntainted
-- (UnitDocumentation.lua), so handing it the token is one too. Favours.lua's
-- handler opened with `if unit == "player" then` and then asked UnitGUID: a
-- Lua error on every UNIT_AURA in every fight, inside AceEvent's dispatch and
-- outside ns.Guard, and the walk a fight's changes leave due never marked. The
-- token now goes through plain() first; a secret one marks the walk due, as a
-- fight does, and nothing else.
--
-- Every scenario name starts with "retail-fix:" so the mutations in
-- tests/mutations/retail-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- ------------------------------------------------------------------ a secret the way the client keeps it
-- Lua 5.1 cannot make `table == "string"` throw, so the client's rule is
-- emulated: a line hook looks at each line of the addon's own files as it is
-- about to run, and records any line that compares (== ~= < > <= >=) a local
-- holding the secret. The secret is a table issecretvalue answers true for,
-- and whose every other forbidden use (index, length, concatenation, call)
-- throws outright.
local function refuse() error("a secret value was used", 2) end
local hostile = setmetatable({}, { __index = refuse, __newindex = refuse, __len = refuse,
	__concat = refuse, __eq = refuse, __lt = refuse, __le = refuse, __call = refuse,
	__tostring = function() return "<secret unit token>" end })

-- The source of each addon file, by its chunk name, for the hook.
local fileLines = {}
local function lineOf(source, line)
	local lines = fileLines[source]
	if lines == nil then
		lines = false
		local path = source:sub(2)
		if source:sub(1, 1) == "@" and not path:find("[/\\]tests[/\\]") then
			local handle = io.open(path, "r")
			if handle then
				lines = {}
				for text in handle:lines() do lines[#lines + 1] = text end
				handle:close()
			end
		end
		fileLines[source] = lines
	end
	return lines and lines[line] or nil
end

local function escape(name) return (name:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- Runs fn with the hook on; returns the comparisons of the secret it saw, and
-- pcall's answer.
local function strictly(fn, ...)
	local seen = {}
	local getinfo, getlocal = debug.getinfo, debug.getlocal
	debug.sethook(function(_, line)
		local info = getinfo(2, "S")
		local text = info and lineOf(info.source, line)
		if not text then return end
		local i = 1
		while true do
			local name, value = getlocal(2, i)
			if not name then break end
			if rawequal(value, hostile) and name:find("^[%a_][%w_]*$") then
				local n = escape(name)
				if text:find("%f[%w_]" .. n .. "%f[^%w_]%s*[=~<>]=")
					or text:find("[=~<>]=%s*" .. n .. "%f[^%w_]")
					or text:find("%f[%w_]" .. n .. "%f[^%w_]%s*[<>]")
					or text:find("[<>]%s*" .. n .. "%f[^%w_]") then
					seen[#seen + 1] = ("%s:%d compares the secret %s: %s"):format(
						info.short_src or info.source, line, name, (text:gsub("^%s+", "")))
				end
			end
			i = i + 1
		end
	end, "l")
	local ok, err = pcall(fn, ...)
	debug.sethook()
	return seen, ok, err
end

-- Globals a scenario replaces, put back after each one whatever happens:
-- Mock.reset owns none of them.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitGUID", "issecretvalue", "UnitExists",
	"C_UnitAuras" }

-- One retail mage's session, Arcane Intellect learned, driven and out of its
-- test mode, with `people` on the nameplates; body(ns) runs inside it.
local function retail(scenario, people, body)
	Mock.reset()
	Mock.setFlavour("mainline")
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local realSecret = issecretvalue
	local undo
	local ok, err = pcall(function()
		-- Read at load (Core.lua's plain), so in place before the addon is.
		issecretvalue = function(v) return rawequal(v, hostile) or realSecret(v) end
		IsSpellKnown = function(id) return id == 1459 end
		IsPlayerSpell = IsSpellKnown
		if people then undo = H.strangers(people) end
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if people then H.clearClicks(ns) end
		wipe(ns.errors)
		Mock.printed = {}
		body(ns)
		guarded(scenario, ns)
	end)
	if undo then undo() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ fix 1
-- UNIT_AURA in a retail fight, its whole payload secret: the token is never
-- compared and never handed to UnitGUID, the handler does not throw, and the
-- walk of your own buffs it may be asking for is marked due, with what
-- Automatic remembers read again on the tick, as a fight's own event does.
do
	local scenario = "retail-fix: UNIT_AURA with a secret unit token (a fight on retail 12.1) is never compared"
	retail(scenario, nil, function(ns)
		Mock.inCombat = true
		Mock.secretAuraIds = { [1459] = true }
		ns.ownScanDue, ns.ownAurasChanged = false, false
		local realGUID = UnitGUID
		local guidGotSecret = false
		UnitGUID = function(unit, ...)
			if rawequal(unit, hostile) then guidGotSecret = true end
			return realGUID(unit, ...)
		end
		local seen, ran, thrown = strictly(ns.addon.UNIT_AURA, ns.addon, "UNIT_AURA", hostile, hostile)
		UnitGUID = realGUID
		if #seen > 0 then
			fail(scenario, "on retail this is a Lua error on every UNIT_AURA in a fight -- " .. seen[1])
		end
		if guidGotSecret then
			fail(scenario, "the secret unit token was handed to UnitGUID, whose arguments are AllowedWhenUntainted"
				.. " (an error from addon code)")
		end
		if not ran then
			fail(scenario, "UNIT_AURA threw on a secret payload: " .. tostring(thrown))
		elseif not ns.ownScanDue then
			fail(scenario, "a secret UNIT_AURA in a fight left no walk of your own buffs due, so a favour"
				.. " landing in a retail fight waits for an aura change after it")
		elseif not ns.ownAurasChanged then
			fail(scenario, "a secret UNIT_AURA in a fight did not ask for your own buffs to be read again,"
				.. " so Automatic keeps the aura you had before the fight")
		end
		Mock.inCombat = false
	end)
end

-- ------------------------------------------------------------------ fix 1, the favour
-- What the walk is for: Anna buffs you in a retail fight, where every
-- UNIT_AURA is secret. Five of them mark one walk, which the tick makes and
-- nothing before it does, and her favour is filed. /manners debug never shows
-- more walks than changes.
do
	local scenario = "retail-fix: a favour landing in a retail fight, every UNIT_AURA secret, is walked on the tick and filed"
	retail(scenario, { nameplate1 = { "Anna" } }, function(ns)
		H.primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline of your own buffs never settled")
			return
		end
		local anna = ns.UnitFullName("nameplate1")
		-- The mock builds C_UnitAuras afresh on every read, so the count goes
		-- in as a global of its own.
		local base = C_UnitAuras
		local reads = 0
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, ...)
				if unit == "player" then reads = reads + 1 end
				return base.GetAuraDataByIndex(unit, ...)
			end,
		}, { __index = base }))
		local events, walks = ns.auraScan.events, ns.auraScan.walks
		Mock.inCombat = true
		-- Power Word: Fortitude as retail has it (Buffs.lua, the mainline set).
		Mock.extraAura, Mock.extraAuraSpell, Mock.extraAuraSource = 6201, 21562, "nameplate1"
		for _ = 1, 5 do
			Mock.advance(0.05)
			ns.addon:UNIT_AURA("UNIT_AURA", hostile, hostile)
		end
		if reads ~= 0 then
			fail(scenario, ("the secret aura events walked your buffs themselves: %d slots read before the tick")
				:format(reads))
		end
		ns.addon:Tick()
		if reads ~= 40 then
			fail(scenario, ("five secret aura events and a tick read %d slots of your aura list, not one walk's 40")
				:format(reads))
		end
		if not ns.owed[anna] then
			fail(scenario, "Anna's Fortitude, landing in a retail fight, was never filed as a favour")
		end
		local madeEvents, madeWalks = ns.auraScan.events - events, ns.auraScan.walks - walks
		if madeWalks ~= 1 or madeEvents < madeWalks then
			fail(scenario, ("/manners debug counts %d aura changes read in %d walks, for one walk")
				:format(madeEvents, madeWalks))
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
	end)
end
