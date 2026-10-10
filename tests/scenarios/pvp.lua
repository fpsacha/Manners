-- Skip players flagged for PvP: a buff on somebody flagged for PvP flags you
-- too. While "Skip players flagged for PvP" is on and you are not flagged
-- yourself, nobody who reads as flagged is offered anything, whatever the
-- reason, and no group spell or shout that would land on them either
-- (Queue.lua, "flagged for PvP"; GroupBuffs.lua). The prompt lets go of them,
-- a press does not cast at them, /manners debug and Diagnostics say why, and
-- neither the favour's line nor the ledger promises their favour back.
--
-- Every scenario name starts with "pvp:" so the mutations in
-- tests/mutations/pvp.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton, owe, findOption =
	H.strangers, H.freshPrompt, H.pressButton, H.owe, H.findOption

local ANNA, BERT = "Anna Aim", "Bert Beside"

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "IsInInstance", "UnitClass", "UnitPowerMax",
	"GetItemCount", "GetItemInfo", "C_UnitAuras", "UnitIsPVP", "UnitIsPVPFreeForAll",
	"IsPVPTimerRunning", "IsResting" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function said() return table.concat(Mock.printed, "\n") end

-- One scenario: nobody about but the people `opts.people` names by token, the
-- lifecycle driven and the slate cleared, then body(ns). `opts.before(ns)`
-- runs between the load and the lifecycle, where a spellbook has to be in
-- place for the probe to read it. Everything is put back and the mock reset,
-- whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.class then Mock.class = opts.class end
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	if opts.raid then Mock.raid = opts.raid end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if opts.before then opts.before(ns) end
		freshPrompt(ns, scenario)
		-- What the first login left on a timer, run now: the welcome puts the
		-- preview up over an empty queue.
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- One scan: this person's entry (or nil) and whether the scan wrote a verdict
-- on them, which is what the prompt's hold reads (see hovering,
-- Prompt/Prompt.lua).
local function look(ns, name)
	local queue, rejected = ns.BuildQueue()
	local found
	for _, entry in ipairs(queue) do
		if entry.name == name then found = entry end
	end
	local verdict = rejected == true or (type(rejected) == "table" and rejected[name] == true)
	return found, verdict
end

local function offered(ns, name)
	return (look(ns, name)) ~= nil
end

local function macro(ns)
	return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1") or "")
end

local function shown(ns)
	return ns.Prompt:GetButton():IsShown()
end

-- The scanner running for `seconds`, with every timer due on the way.
local function scan(ns, seconds)
	for _ = 1, math.floor(seconds / 0.4 + 0.5) do
		Mock.runTimers(0.4)
		ns.addon:Tick()
	end
end

-- A token turning up again after the lifecycle, the way the client says so.
local function plate(ns, names, token, first, last)
	names[token] = { first, last }
	ns.addon:NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED", token)
end

local function pvpLines(ns)
	return table.concat(ns.PvPLines(true), "\n")
end

-- ------------------------------------------------------------------ pvp 1
-- The owner's report: a passer-by flagged for PvP is not offered while you
-- are not flagged, the free-for-all flag counting the same, and holding them
-- back is a verdict the prompt can read. The setting is on out of the box.
do
	local scenario = "pvp: a flagged passer-by is not offered while you are not flagged"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } } },
		function(ns)
			if ns.db.profile.filters.skipPvP ~= true then
				fail(scenario, "Skip players flagged for PvP is not on by default")
			end
			if not (offered(ns, ANNA) and offered(ns, BERT)) then
				fail(scenario, "SKIPPED -- the two passers-by were not both offered unflagged")
				return
			end
			-- Both were offered through a nameplate, so both are remembered:
			-- a scan that held Anna back without a verdict would let the
			-- memory offer her all the same.
			Mock.pvp = { nameplate1 = true }
			local anna, verdict = look(ns, ANNA)
			if anna then
				fail(scenario, "a flagged passer-by was offered while you are not flagged")
			end
			if not verdict then
				fail(scenario, "holding a flagged passer-by back is not a verdict the prompt can read")
			end
			if not offered(ns, BERT) then
				fail(scenario, "the passer-by who is not flagged was held back with her")
			end
			Mock.pvp, Mock.pvpFFA = nil, { nameplate1 = true }
			if offered(ns, ANNA) then
				fail(scenario, "a passer-by flagged for free-for-all PvP was offered")
			end
		end)
end

-- ------------------------------------------------------------------ pvp 2
-- While you are flagged yourself buffing them costs nothing more, so they are
-- offered: flagged, flagged for free-for-all, or with your own flag withheld
-- inside a battleground or an arena, where everybody is. Your flag withheld
-- anywhere else counts as not flagged, deliberately (Queue.lua, YouAreFlagged).
-- So does your flag running out, outside a battleground: buffing somebody
-- flagged would start the countdown again -- and /manners debug says why the
-- rule stands while you are flagged. A countdown the game will not show is
-- no countdown.
for _, case in ipairs({
	{ label = "flagged", pvp = { player = true } },
	{ label = "flagged for free-for-all", ffa = { player = true } },
	{ label = "your flag withheld in a battleground", pvp = { player = "secret" }, instance = "pvp" },
	{ label = "your flag withheld in an arena", pvp = { player = "secret" }, instance = "arena" },
	{ label = "your flag withheld out in the world", pvp = { player = "secret" }, held = true },
	{ label = "your flag running out", pvp = { player = true }, timer = true, held = true },
	{ label = "your flag running out in a battleground", pvp = { player = true }, timer = true, instance = "pvp" },
	{ label = "your countdown withheld", pvp = { player = true }, timer = "secret" },
}) do
	local scenario = "pvp: whether you are flagged yourself (" .. case.label .. ")"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		if not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- the passer-by was not offered unflagged")
			return
		end
		local pvp = { nameplate1 = true }
		for unit, value in pairs(case.pvp or {}) do
			pvp[unit] = value == "secret" and Mock.SECRET or value
		end
		Mock.pvp, Mock.pvpFFA = pvp, case.ffa
		if case.instance then
			rawset(_G, "IsInInstance", function() return true, case.instance end)
		end
		if case.timer then
			local answer = case.timer == "secret" and Mock.SECRET or true
			rawset(_G, "IsPVPTimerRunning", function() return answer end)
		end
		local anna = offered(ns, ANNA)
		-- Each message written here, in the body, where selftest.py's trace
		-- finds the scenario it belongs to (not in the table above, which
		-- runs before any of them).
		if case.held and anna then
			if case.timer then
				fail(scenario, "your own flag running out stood the rule aside")
			else
				fail(scenario, "your own flag withheld out in the world stood the rule aside")
			end
		elseif not case.held and not anna then
			fail(scenario, "a flagged passer-by was not offered while you are flagged too")
		end
		if case.held and case.timer then
			local lines = pvpLines(ns)
			if not (lines:find("your PvP flag is running out", 1, true) and lines:find(ANNA, 1, true)) then
				fail(scenario, "/manners debug does not say your flag running out keeps the rule standing: "
					.. flat(lines))
			end
		end
	end)
end

-- ------------------------------------------------------------------ pvp 3
-- With the setting off, flags are nobody's business.
do
	local scenario = "pvp: with the setting off a flagged passer-by is offered"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		ns.db.profile.filters.skipPvP = false
		Mock.pvp = { nameplate1 = true }
		if not offered(ns, ANNA) then
			fail(scenario, "a flagged passer-by was held back with Skip players flagged for PvP off")
		end
		if #ns.PvPLines(true) > 0 then
			fail(scenario, "/manners debug speaks of PvP with the setting off: " .. pvpLines(ns))
		end
	end)
end

-- /manners debug and Diagnostics name only people the rule itself holds back.
-- Somebody no source would offer anyway -- a passer-by with Passers-by off,
-- or out in the world while passers-by are left for cities -- named as held
-- back for PvP reads as the rule being why they are missing.
for _, case in ipairs({
	{ label = "Passers-by off", set = function(ns) ns.db.profile.sources.strangers = false end },
	{ label = "out in the world with passers-by left for cities", set = function(ns)
		ns.db.profile.filters.restingOnly = true
		rawset(_G, "IsResting", function() return false end)
	end },
}) do
	local scenario = "pvp: /manners debug names only people a source would offer (" .. case.label .. ")"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		Mock.pvp = { nameplate1 = true }
		if not pvpLines(ns):find(ANNA, 1, true) then
			fail(scenario, "SKIPPED -- the flagged passer-by was not named with every source on")
			return
		end
		case.set(ns)
		Mock.pvp = nil
		if offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- the passer-by was offered unflagged with " .. case.label)
			return
		end
		Mock.pvp = { nameplate1 = true }
		local lines = pvpLines(ns)
		if lines:find(ANNA, 1, true) then
			fail(scenario, "somebody no source would offer is named as held back for PvP: " .. flat(lines))
		end
	end)
end

-- ------------------------------------------------------------------ pvp 4
-- A flag the game will not show is "cannot tell", and cannot tell offers, as
-- everywhere else in the addon: a secret or a call that is missing, and one
-- flag read with the other withheld.
for _, case in ipairs({
	{ label = "a secret", pvp = "secret" },
	{ label = "the free-for-all flag withheld", ffa = "secret" },
	{ label = "no such call", missing = true },
}) do
	local scenario = "pvp: a flag that cannot be read offers them (" .. case.label .. ")"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		local function value(v) return v == "secret" and Mock.SECRET or v end
		if case.pvp then Mock.pvp = { nameplate1 = value(case.pvp) } end
		if case.ffa then Mock.pvpFFA = { nameplate1 = value(case.ffa) } end
		if case.missing then
			rawset(_G, "UnitIsPVP", nil)
			rawset(_G, "UnitIsPVPFreeForAll", nil)
		end
		if not offered(ns, ANNA) then
			fail(scenario, "a passer-by whose flag cannot be read was held back")
		end
	end)
end

-- A flag read that throws is a fault, not "cannot tell": the flags are asked
-- directly on every scan (Core.lua, the protection policy), since the client
-- answers them or withholds a secret. So a throw reaches the scan's Guard,
-- which names it in /manners errors and keeps the scanner going: once the call
-- stops throwing, the next scan offers her again.
do
	local scenario = "pvp: a flag read that throws is named, and the scanner lives on"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		if not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- the passer-by was not offered unflagged")
			return
		end
		Mock.pvp = { nameplate1 = "throw" }
		local before = #ns.errors
		scan(ns, 0.4)
		if #ns.errors <= before then
			fail(scenario, "a flag read that throws was not named in /manners errors")
		end
		Mock.pvp = nil
		scan(ns, 0.4)
		if ns.Prompt:PanelName() ~= ANNA or not macro(ns):find(ANNA, 1, true) then
			fail(scenario, "the scanner did not offer her again once the flag read stopped throwing: "
				.. flat(macro(ns)))
		end
		-- Named, and over: nothing left for `with` to call unexplained.
		wipe(ns.errors)
	end)
end

-- ------------------------------------------------------------------ pvp 5
-- A favour from somebody flagged: the line says returning it waits, they are
-- not offered -- by a token or, with none, by the owed fallback on the flag
-- read with the favour -- and the debt stays. Once a token reads the flag
-- gone they are offered, and the fallback after it goes by the new reading.
do
	local scenario = "pvp: a favour from somebody flagged stays owed and is returned once they are not"
	local names = { nameplate1 = { "Anna", "Aim" } }
	with(scenario, { people = names }, function(ns)
		H.primeAuras(ns)
		Mock.pvp = { nameplate1 = true }
		local line = H.favourFrom(ns, "nameplate1", 1459, 4101)
		if not ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- no favour from Anna was filed: " .. flat(line))
			return
		end
		if not line:find("they are flagged for PvP", 1, true) then
			fail(scenario, "the favour's line does not say returning it waits on the flag: " .. flat(line))
		elseif not line:find("only if their flag drops before the favour runs out", 1, true) then
			-- A flag lasts five minutes after the last fight, a favour two.
			fail(scenario, "the favour's line promises a return the favour's time may not allow: " .. flat(line))
		end
		-- No token: the fallback, on the flag the favour was read with.
		names.nameplate1 = nil
		local anna, verdict = look(ns, ANNA)
		if anna then
			fail(scenario, "the owed fallback offered the favour back to somebody last read as flagged")
		elseif not verdict then
			fail(scenario, "the owed fallback held a flagged favour back without a verdict")
		end
		if not pvpLines(ns):find(ANNA, 1, true) then
			fail(scenario, "/manners debug does not say the favour is held back: " .. flat(pvpLines(ns)))
		end
		scan(ns, 2)
		if not ns.owed[ANNA] then
			fail(scenario, "the favour owed to somebody flagged was let go")
		end
		-- A token finds her, still flagged: a favour is no exception.
		plate(ns, names, "nameplate1", "Anna", "Aim")
		if offered(ns, ANNA) then
			fail(scenario, "somebody flagged was offered their favour back while a token found them flagged")
		end
		-- The flag gone: offered by the token, then by the fallback.
		Mock.pvp = nil
		anna = look(ns, ANNA)
		if not (anna and anna.reason == "owed") then
			fail(scenario, "once the flag dropped, the favour was not offered back")
		end
		names.nameplate1 = nil
		anna = look(ns, ANNA)
		if not (anna and anna.reason == "owed") then
			fail(scenario, "once a token read the flag gone, the owed fallback still held the favour back")
		end
		if not ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- the favour ran out during the scenario")
		end
	end)
end

-- The favour's line speaks of the flag only while the rule stands: not with
-- the setting off, nor while you are flagged yourself -- but while your own
-- flag is running out it does, since the rule stands then.
for _, case in ipairs({
	{ label = "the setting off", off = true },
	{ label = "you flagged yourself", you = true },
	{ label = "your own flag running out", you = true, timer = true, says = true },
}) do
	local scenario = "pvp: the favour's line speaks of the flag only while the rule stands (" .. case.label .. ")"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		H.primeAuras(ns)
		if case.off then ns.db.profile.filters.skipPvP = false end
		if case.timer then rawset(_G, "IsPVPTimerRunning", function() return true end) end
		Mock.pvp = { nameplate1 = true, player = case.you }
		local line = H.favourFrom(ns, "nameplate1", 1459, 4101)
		if not ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- no favour from Anna was filed: " .. flat(line))
			return
		end
		local speaks = line:find("they are flagged for PvP", 1, true) ~= nil
		if case.says and not speaks then
			fail(scenario, "with your own flag running out, the favour's line does not say the flag holds it back: "
				.. flat(line))
		elseif not case.says and speaks then
			fail(scenario, "the favour's line says the flag holds it back with " .. case.label .. ": " .. flat(line))
		end
	end)
end

-- The ledger's owed row says the same: while the rule holds the favour back
-- it does not promise the prompt offers them, and with the setting off it
-- does not speak of the flag. The window never promises what cannot come.
for _, case in ipairs({ { label = "while the rule stands", holds = true }, { label = "with the setting off" } }) do
	local scenario = "pvp: the ledger's owed row says the flag holds the favour back (" .. case.label .. ")"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		H.primeAuras(ns)
		Mock.pvp = { nameplate1 = true }
		local line = H.favourFrom(ns, "nameplate1", 1459, 4101)
		if not ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- no favour from Anna was filed: " .. flat(line))
			return
		end
		if not case.holds then ns.db.profile.filters.skipPvP = false end
		ns.addon:HandleSlash("ledger")
		local window = ns.Ledger.Window()
		local row = window and window.rows and window.rows[1]
		if not (row and row.entry and row.entry.name == ANNA and row.entry.state == "owed") then
			fail(scenario, "SKIPPED -- the ledger's first row is not Anna's favour owed")
			return
		end
		Mock.tooltip = {}
		row.scripts.OnEnter(row)
		local tip = table.concat(Mock.tooltip, "\n")
		local T = ns.Ledger.TEXT
		local speaks = T.TIP_OWED_PVP ~= nil and tip:find(T.TIP_OWED_PVP, 1, true) ~= nil
		if case.holds and not speaks then
			fail(scenario, "the ledger promises a favour the PvP rule holds back: " .. flat(tip))
		elseif not case.holds and (speaks or not tip:find(T.TIP_OWED, 1, true)) then
			fail(scenario, "with the setting off the ledger's row still speaks of the flag: " .. flat(tip))
		end
	end)
end

-- The flag kept on a favour goes into the saved debts and comes back with
-- them, so a reload does not let the fallback offer somebody last read flagged.
do
	local scenario = "pvp: the flag kept on a favour survives a reload"
	with(scenario, {}, function(ns)
		owe(ns, ANNA)
		ns.owed[ANNA].pvp = true
		ns.SaveDebts()
		local store = ns.db.char.debts
		if not (store and store[ANNA] and store[ANNA].pvp == true) then
			fail(scenario, "the flag on a favour owed was not saved with it")
		end
		local again = load(scenario)
		if not again then return end
		again.addon:OnInitialize()
		local debt = again.owed[ANNA]
		if not debt then
			fail(scenario, "SKIPPED -- the favour owed did not come back after a reload")
		elseif debt.pvp ~= true then
			fail(scenario, "the flag on a favour owed did not come back after a reload")
		end
	end)
end

-- ------------------------------------------------------------------ pvp 6
-- A group spell lands on everybody in the party, so one member flagged keeps
-- the group cast back, whether they are missing the buff too or already
-- wearing it (and so never in the queue at all); everybody else is still
-- offered one at a time, and /manners debug says why.
local MAGE_GROUP = { 10157, 10156, 1461, 1460, 1459, 23028 }
local ARCANE_POWDER = 17020
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	party4 = { "Dain", "Moor" },
}

-- The client a group scenario needs: spells known, reagents carried, classes
-- by token (the rest the mock's priests), and the auras each token wears as
-- a set of spell ids in `env.held`, which the scenario may change as it goes.
-- You keep the mock's own, wearing everything of yours.
local function groupClient(env)
	local known = {}
	for _, id in ipairs(env.known) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
	rawset(_G, "GetItemCount", function(id) return env.bags[id] or 0 end)
	rawset(_G, "GetItemInfo", function() return env.itemName end)
	local classes = env.classes or {}
	local baseClass, basePower = UnitClass, UnitPowerMax
	UnitClass = function(unit)
		local class = classes[unit]
		if class then return class, class end
		return baseClass(unit)
	end
	-- A warrior's mana bar reads zero, which is what gives him Might.
	UnitPowerMax = function(unit, power)
		if classes[unit] == "WARRIOR" then return 0 end
		return basePower(unit, power)
	end
	env.held = env.held or {}
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
			if env.held[unit] and env.held[unit][spellId] then
				return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600,
					sourceUnit = "player" }
			end
			return nil
		end,
	}, { __index = base }))
end

local function mageParty(held)
	return { known = MAGE_GROUP, bags = { [ARCANE_POWDER] = 20 }, itemName = "Arcane Powder", held = held }
end

-- The group cast in the queue, or nil, and the single casts by name.
local function groupAndSingles(ns)
	local group, singles = nil, {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.groupCast then
			group = group or entry
		else
			singles[entry.name] = entry
		end
	end
	return group, singles
end

local function fullName(pair) return pair[1] .. " " .. pair[2] end

for _, case in ipairs({
	{ label = "missing it too", flagged = "party2" },
	{ label = "already wearing it", flagged = "party4", held = { party4 = { [10157] = true } } },
}) do
	local scenario = "pvp: a party member flagged for PvP keeps back the group cast (" .. case.label .. ")"
	local env = mageParty(case.held)
	with(scenario, { groupSize = 5, people = PARTY, before = function() groupClient(env) end }, function(ns)
		if not groupAndSingles(ns) then
			fail(scenario, "SKIPPED -- no group cast for the party with nobody flagged")
			return
		end
		Mock.pvp = { [case.flagged] = true }
		local group, singles = groupAndSingles(ns)
		if group then
			fail(scenario, "a group cast was offered to a party with a member flagged for PvP")
		end
		for token, pair in pairs(PARTY) do
			local name = fullName(pair)
			if token == case.flagged then
				if singles[name] then fail(scenario, "the flagged member was offered a single cast") end
			elseif not env.held[token] and not singles[name] then
				fail(scenario, name .. " is not flagged and was not offered one at a time")
			end
		end
		local lines = pvpLines(ns)
		if not (lines:find("no Arcane Brilliance for your party", 1, true)
			and lines:find(fullName(PARTY[case.flagged]), 1, true)) then
			fail(scenario, "/manners debug does not say why the party gets no group cast: " .. flat(lines))
		end
		Mock.pvp.player = true
		if not groupAndSingles(ns) then
			fail(scenario, "flagged yourself, the party still got no group cast")
		end
	end)
end

-- In a raid on Classic Era a party-wide spell lands on the target's own
-- subgroup: a raider flagged in another subgroup keeps nothing back, one in
-- its own (wearing the buff, so never queued) keeps its group cast back.
-- Forever's reach the whole raid: tests/scenarios/data-audit.lua.
for _, case in ipairs({
	{ label = "in another subgroup", flagged = "raid3", want = true },
	{ label = "in its own subgroup", flagged = "raid10", want = false },
}) do
	local scenario = "pvp: in a raid a flagged member keeps back only their own subgroup's group cast ("
		.. case.label .. ")"
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	-- Subgroup 1 is raid1-5 (raid1 is you): two missing it. Subgroup 2 is
	-- raid6-10: four missing it, raid10 wearing it.
	local env = mageParty({ raid4 = { [10157] = true }, raid5 = { [10157] = true },
		raid10 = { [10157] = true } })
	with(scenario, { flavour = "vanilla", raid = { size = 10, player = 1 }, people = names,
		before = function() groupClient(env) end }, function(ns)
		if not groupAndSingles(ns) then
			fail(scenario, "SKIPPED -- no group cast for the second subgroup with nobody flagged")
			return
		end
		Mock.pvp = { [case.flagged] = true }
		local group = groupAndSingles(ns)
		if case.want and not group then
			fail(scenario, "a raider flagged in another subgroup kept back this subgroup's group cast")
		elseif not case.want and group then
			fail(scenario, "a group cast was offered to a subgroup with a member flagged for PvP")
		end
	end)
end

-- A Greater Blessing lands on everybody of one class: a flagged warrior keeps
-- the warriors' back, a flagged mage does not.
local PALADIN = {
	25290, 19854, 19853, 19852, 19850, 19742, -- Wisdom
	25291, 19838, 19837, 19836, 19835, 19834, 19740, -- Might
	25916, 25782, 25918, 25894, -- the Greater Blessings of each
}
for _, case in ipairs({
	{ label = "a mage", flagged = "raid4", want = true },
	{ label = "a warrior", flagged = "raid7", want = false },
}) do
	local scenario = "pvp: a flagged member keeps back only their own class's Greater Blessing (" .. case.label .. ")"
	local names, classes = {}, {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	for _, i in ipairs({ 2, 3, 6, 7 }) do classes["raid" .. i] = "WARRIOR" end
	for _, i in ipairs({ 4, 8 }) do classes["raid" .. i] = "MAGE" end
	for _, i in ipairs({ 5, 9, 10 }) do classes["raid" .. i] = "PRIEST" end
	local env = { known = PALADIN, bags = { [21177] = 10 }, itemName = "Symbol of Kings", classes = classes,
		-- The priests wear our Wisdom, so the only class left is the warriors.
		held = { raid5 = { [25290] = true }, raid9 = { [25290] = true }, raid10 = { [25290] = true } } }
	with(scenario, { class = "PALADIN", raid = { size = 10, player = 1 }, people = names,
		before = function() groupClient(env) end }, function(ns)
		local blessing = groupAndSingles(ns)
		if not (blessing and blessing.buff.key == "might") then
			fail(scenario, "SKIPPED -- no Greater Blessing of Might for the warriors with nobody flagged")
			return
		end
		Mock.pvp = { [case.flagged] = true }
		local group, singles = groupAndSingles(ns)
		if case.want and not group then
			fail(scenario, "a flagged mage kept back the warriors' Greater Blessing")
		elseif not case.want then
			if group then
				fail(scenario, "a Greater Blessing was offered to a class with a member flagged for PvP")
			end
			for _, i in ipairs({ 2, 3, 6 }) do
				if not singles["Raider" .. i .. " Stone"] then
					fail(scenario, "warrior " .. i .. " is not flagged and was not offered Might one at a time")
				end
			end
		end
	end)
end

-- The press asks as well: a group cast on the panel, then the party covered
-- (the queue empty) and a member flagged since the paint. The press on an
-- empty queue follows the panel, and must not cast the group spell over them.
do
	local scenario = "pvp: a press does not cast the group spell over a member flagged since the paint"
	local env = mageParty()
	with(scenario, { groupSize = 5, people = PARTY, before = function() groupClient(env) end }, function(ns)
		ns.addon:Tick()
		if not macro(ns):find("/cast Arcane Brilliance", 1, true) then
			fail(scenario, "SKIPPED -- the prompt was not armed with the group cast: " .. flat(macro(ns)))
			return
		end
		for token in pairs(PARTY) do env.held[token] = { [10157] = true } end
		for token in pairs(PARTY) do ns.ForgetUnitAuras(ns.plain(UnitGUID(token))) end
		Mock.pvp = { party4 = true }
		Mock.advance(0.5)
		local ran = tostring(pressButton(ns) or "")
		if ran:find("Arcane Brilliance", 1, true) then
			fail(scenario, "the press cast the group spell over a party member flagged for PvP: " .. flat(ran))
		end
	end)
end

-- And only while the rule stands: with the setting off, or flagged yourself,
-- the same press casts the group spell as it would have before.
for _, case in ipairs({
	{ label = "the setting off", set = function(ns) ns.db.profile.filters.skipPvP = false end },
	{ label = "you flagged yourself", set = function() Mock.pvp.player = true end },
}) do
	local scenario = "pvp: while the rule stands aside a press casts the group spell over a flagged member ("
		.. case.label .. ")"
	local env = mageParty()
	with(scenario, { groupSize = 5, people = PARTY, before = function() groupClient(env) end }, function(ns)
		ns.addon:Tick()
		if not macro(ns):find("/cast Arcane Brilliance", 1, true) then
			fail(scenario, "SKIPPED -- the prompt was not armed with the group cast: " .. flat(macro(ns)))
			return
		end
		for token in pairs(PARTY) do env.held[token] = { [10157] = true } end
		for token in pairs(PARTY) do ns.ForgetUnitAuras(ns.plain(UnitGUID(token))) end
		Mock.pvp = { party4 = true }
		case.set(ns)
		Mock.advance(0.5)
		local ran = tostring(pressButton(ns) or "")
		if not ran:find("Arcane Brilliance", 1, true) then
			fail(scenario, "the press held the group spell back for a flagged member with " .. case.label .. ": "
				.. flat(ran))
		end
	end)
end

-- A Greater Blessing on the panel, then every warrior covered (the queue
-- empty) and one of them flagged since the paint: the press asks the class
-- again, not a raid subgroup, and does not bless them.
do
	local scenario = "pvp: a press does not cast a Greater Blessing over a member of the class flagged since the paint"
	local names, classes = {}, {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	for _, i in ipairs({ 2, 3, 6, 7 }) do classes["raid" .. i] = "WARRIOR" end
	for _, i in ipairs({ 4, 8 }) do classes["raid" .. i] = "MAGE" end
	for _, i in ipairs({ 5, 9, 10 }) do classes["raid" .. i] = "PRIEST" end
	-- Everybody but the warriors wears our Wisdom, so the warriors' Might is
	-- all there is to cast.
	local held = {}
	for _, i in ipairs({ 4, 5, 8, 9, 10 }) do held["raid" .. i] = { [25290] = true } end
	local env = { known = PALADIN, bags = { [21177] = 10 }, itemName = "Symbol of Kings", classes = classes,
		held = held }
	with(scenario, { class = "PALADIN", raid = { size = 10, player = 1 }, people = names,
		before = function() groupClient(env) end }, function(ns)
		ns.addon:Tick()
		local armed = macro(ns)
		if not armed:find("Greater Blessing of Might", 1, true) then
			fail(scenario, "SKIPPED -- the prompt was not armed with the Greater Blessing: " .. flat(armed))
			return
		end
		for _, i in ipairs({ 2, 3, 6, 7 }) do
			env.held["raid" .. i] = { [25291] = true, [25916] = true }
			ns.ForgetUnitAuras(ns.plain(UnitGUID("raid" .. i)))
		end
		Mock.pvp = { raid7 = true }
		Mock.advance(0.5)
		local ran = tostring(pressButton(ns) or "")
		if ran:find("Greater Blessing", 1, true) then
			fail(scenario, "the press cast a Greater Blessing over a warrior flagged for PvP: " .. flat(ran))
		end
	end)
end

-- ------------------------------------------------------------------ pvp 7
-- A passer-by remembered while you were flagged yourself, flagged too, is not
-- offered from memory once you are not: the memory keeps the flag it read.
-- One remembered unflagged is, or the memory proves nothing.
for _, case in ipairs({ { label = "flagged", flagged = true }, { label = "not flagged" } }) do
	local scenario = "pvp: a passer-by remembered while you were flagged (" .. case.label .. ")"
	local names = { nameplate1 = { "Anna", "Aim" } }
	with(scenario, { people = names }, function(ns)
		Mock.pvp = { player = true, nameplate1 = case.flagged }
		if not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not offered while you are flagged")
			return
		end
		names.nameplate1 = nil
		if not offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not offered from memory while you are flagged")
			return
		end
		Mock.pvp.player = nil
		local anna, verdict = look(ns, ANNA)
		if case.flagged then
			if anna then
				fail(scenario, "a passer-by last read as flagged was offered from memory")
			elseif not verdict then
				fail(scenario, "a passer-by let go from memory for the flag was not a verdict")
			end
			if ns.passersBy[ANNA] then
				fail(scenario, "a passer-by last read as flagged is still remembered")
			end
			-- The lines of the scan that let her go: the next has nobody to name.
			local lines = table.concat(ns.PvPLines(), "\n")
			if not lines:find(ANNA, 1, true) then
				fail(scenario, "a passer-by let go from memory for the flag is not named in /manners debug: "
					.. flat(lines))
			end
		elseif not anna then
			fail(scenario, "a passer-by remembered unflagged was not offered from memory")
		end
	end)
end

-- ------------------------------------------------------------------ pvp 8
-- The cursor on the panel holds a person the cursor lost track of, and nobody
-- a scan found flagged: the panel moves on to whoever waits, or comes down.
for _, case in ipairs({ { label = "with somebody waiting", bert = true }, { label = "alone" } }) do
	local scenario = "pvp: under the cursor the prompt lets go of somebody who becomes flagged ("
		.. case.label .. ")"
	local people = { nameplate1 = { "Anna", "Aim" } }
	if case.bert then people.nameplate2 = { "Bert", "Beside" } end
	with(scenario, { people = people }, function(ns)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- Anna was not on the panel: " .. tostring(ns.Prompt:PanelName()))
			return
		end
		local button = ns.Prompt:GetButton()
		button.scripts.OnEnter(button)
		scan(ns, 1)
		Mock.pvp = { nameplate1 = true }
		scan(ns, 3)
		if case.bert and ns.Prompt:PanelName() ~= BERT then
			fail(scenario, "somebody flagged stayed on the panel under the cursor while Bert waited: "
				.. tostring(ns.Prompt:PanelName()))
		elseif not case.bert and shown(ns) then
			fail(scenario, "the prompt stayed up under the cursor on somebody flagged")
		end
	end)
end

-- ------------------------------------------------------------------ pvp 9
-- The press re-reads at the last moment: made the moment after the person on
-- the panel became flagged, with no scan in between, it does not cast at
-- them -- alone (the press on an empty queue follows the panel) or with
-- somebody waiting, inside the second and a half the panel holds its pick.
for _, case in ipairs({ { label = "alone" }, { label = "with somebody waiting", bert = true } }) do
	local scenario = "pvp: a press does not cast at somebody flagged since the paint (" .. case.label .. ")"
	local people = { nameplate1 = { "Anna", "Aim" } }
	if case.bert then people.nameplate2 = { "Bert", "Beside" } end
	with(scenario, { people = people }, function(ns)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA or not macro(ns):find(ANNA, 1, true) then
			fail(scenario, "SKIPPED -- the prompt was not armed at Anna: " .. flat(macro(ns)))
			return
		end
		Mock.pvp = { nameplate1 = true }
		Mock.advance(0.5)
		local ran = tostring(pressButton(ns) or "")
		if ran:find(ANNA, 1, true) then
			fail(scenario, "the press cast at somebody flagged for PvP since the paint: " .. flat(ran))
		end
	end)
end

-- ------------------------------------------------------------------ pvp 10
-- You are never judged by the rule: missing your own buff with a flagged
-- passer-by about, you are offered it and they are not.
do
	local scenario = "pvp: you are never skipped"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.pvp = { nameplate1 = true }
		local you
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" then you = entry end
		end
		if not you then
			fail(scenario, "you were not offered your own buff while the rule held a passer-by back")
		end
		if offered(ns, ANNA) then
			fail(scenario, "SKIPPED -- the flagged passer-by was offered, so the rule did not stand")
		end
	end)
end

-- ------------------------------------------------------------------ pvp 11
-- The switch, under "Who to skip", and kept by the saved settings: a value a
-- checkbox cannot show goes back to on, off stays off, and the settings text
-- carries it.
do
	local scenario = "pvp: the switch sits under Who to skip"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		local who = ns.optionsTable and ns.optionsTable.args.who
		local a = who and who.args
		local toggle = a and a.skipPvP
		if not toggle then
			fail(scenario, "there is no Skip players flagged for PvP on the Who to buff tab")
			return
		end
		if toggle.name ~= "Skip players flagged for PvP" then
			fail(scenario, "the switch reads " .. tostring(toggle.name))
		end
		if not tostring(toggle.desc):find("Ignored while you are flagged yourself", 1, true) then
			fail(scenario, "the tooltip does not say it stands aside while you are flagged: " .. tostring(toggle.desc))
		elseif not tostring(toggle.desc):find("not while your own flag is running out", 1, true) then
			fail(scenario, "the tooltip does not say a flag running out is no exception: " .. tostring(toggle.desc))
		end
		if not (a.skipHeader and a.neverHeader and toggle.order > a.skipHeader.order
			and toggle.order < a.neverHeader.order) then
			fail(scenario, "the switch is not under Who to skip (order " .. tostring(toggle.order) .. ")")
		end
		toggle.set({ "skipPvP" }, false)
		Mock.pvp = { nameplate1 = true }
		if toggle.get({ "skipPvP" }) ~= false or not offered(ns, ANNA) then
			fail(scenario, "switching it off on the page did not offer the flagged passer-by")
		end
	end)
end

for _, case in ipairs({
	{ label = "a string", saved = "yes", want = true },
	{ label = "off", saved = false, want = false },
}) do
	local scenario = "pvp: saved settings keep the switch (" .. case.label .. ")"
	Mock.reset()
	Mock.sv = {}
	if not H.savedProfile(scenario, function(profile)
		profile.filters.skipPvP = case.saved
	end) then
		fail(scenario, "SKIPPED -- no saved profile to edit")
	else
		local ns = load(scenario)
		if ns then
			freshPrompt(ns, scenario)
			local value = ns.db.profile.filters.skipPvP
			if value ~= case.want then
				fail(scenario, "a saved skipPvP of " .. tostring(case.saved) .. " came back as " .. tostring(value))
			end
			noErrors(scenario, ns)
		end
	end
	Mock.reset()
end

do
	local scenario = "pvp: the settings text carries the switch"
	with(scenario, {}, function(ns)
		ns.db.profile.filters.skipPvP = false
		local text = ns.ExportSettings()
		if not tostring(text):find("filters.skipPvP=0", 1, true) then
			fail(scenario, "the settings text leaves the switch out: " .. tostring(text))
		end
		ns.db.profile.filters.skipPvP = true
		local ok = ns.ImportSettings(text)
		if not ok or ns.db.profile.filters.skipPvP ~= false then
			fail(scenario, "importing the settings text did not switch it off")
		end
	end)
end

-- ------------------------------------------------------------------ pvp 12
-- A shout lands on the whole party, whoever the prompt names, so a member
-- flagged holds back every shout -- for the ones who are not flagged too.
do
	local scenario = "pvp: a party member flagged for PvP keeps back the warrior's shout"
	with(scenario, { class = "WARRIOR", groupSize = 3,
		people = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } },
		before = function(ns) H.knowShout(ns) end }, function(ns)
		local anna = look(ns, ANNA)
		if not (anna and anna.buff and anna.buff.selfCast) then
			fail(scenario, "SKIPPED -- Anna was not offered the shout with nobody flagged")
			return
		end
		Mock.pvp = { party2 = true }
		if offered(ns, ANNA) then
			fail(scenario, "Anna was offered a shout that would land on Bert, who is flagged for PvP")
		end
		local lines = pvpLines(ns)
		if not (lines:find("for your party", 1, true) and lines:find(BERT, 1, true)) then
			fail(scenario, "/manners debug does not say why the shout is held back: " .. flat(lines))
		end
		Mock.pvp.player = true
		if not offered(ns, ANNA) then
			fail(scenario, "flagged yourself, the shout was still held back")
		end
	end)
end

-- And the press: the shout armed for Anna, Bert flagged since the paint, and
-- nobody left in the queue -- the press on an empty queue follows the panel,
-- and must not shout over him.
do
	local scenario = "pvp: a press does not shout over a party member flagged since the paint"
	local people = { party1 = { "Anna", "Aim" } }
	with(scenario, { class = "WARRIOR", groupSize = 2, people = people,
		before = function(ns) H.knowShout(ns) end }, function(ns)
		ns.addon:Tick()
		if not macro(ns):find("Battle Shout", 1, true) then
			fail(scenario, "SKIPPED -- the prompt was not armed with the shout: " .. flat(macro(ns)))
			return
		end
		-- Bert joins, flagged: he takes nobody's place in the queue.
		Mock.groupSize = 3
		people.party2 = { "Bert", "Beside" }
		Mock.pvp = { party2 = true }
		Mock.advance(0.5)
		local ran = tostring(pressButton(ns) or "")
		if ran:find("Battle Shout", 1, true) then
			fail(scenario, "the press shouted over a party member flagged for PvP: " .. flat(ran))
		end
	end)
end

-- In a raid a shout lands where SameParty says it reaches: the whole raid
-- where shouts are raid-wide (the Mists and retail sets), your own subgroup
-- where they are not (vanilla, and so Camelot). One flagged where it lands
-- holds it back; one flagged in another subgroup holds back only a raid-wide
-- shout. The raid is ten, you raid1: subgroup 1 is raid1-5, 2 is raid6-10.
for _, case in ipairs({
	{ label = "raid-wide, flagged in another subgroup", wide = true, flagged = "raid8", held = true },
	{ label = "raid-wide, flagged in your own subgroup", wide = true, flagged = "raid3", held = true },
	{ label = "your subgroup only, flagged in another", flagged = "raid8" },
	{ label = "your subgroup only, flagged in your own", flagged = "raid3", held = true },
}) do
	local scenario = "pvp: in a raid a flagged member holds back a shout where it lands (" .. case.label .. ")"
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	with(scenario, { class = "WARRIOR", raid = { size = 10, player = 1 }, people = names,
		before = function(ns) H.knowShout(ns) end }, function(ns)
		ns.PARTY_IS_SUBGROUP = not case.wide
		local function shouts()
			local n = 0
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.buff and entry.buff.selfCast then n = n + 1 end
			end
			return n
		end
		if shouts() == 0 then
			fail(scenario, "SKIPPED -- nobody in the raid was offered the shout with nobody flagged")
			return
		end
		Mock.pvp = { [case.flagged] = true }
		local n = shouts()
		local who = names[case.flagged][1] .. " " .. names[case.flagged][2]
		if case.held and n > 0 then
			fail(scenario, "the shout was offered " .. n .. " times though it would land on " .. who
				.. ", flagged for PvP")
		elseif not case.held and n == 0 then
			fail(scenario, "a raider flagged in another subgroup held back a shout that reaches only your own")
		end
		if case.held then
			local lines = pvpLines(ns)
			local label = case.wide and "for your raid" or "for your group"
			if not (lines:find(label, 1, true) and lines:find(who, 1, true)) then
				fail(scenario, "/manners debug does not say why the shout is held back in a raid: " .. flat(lines))
			end
		end
	end)
end

-- ------------------------------------------------------------------ pvp 13
-- Whatever the reason they would be offered for: your target, a group member
-- at a ready check, somebody who asked in chat.
for _, case in ipairs({
	{ label = "your target", people = { target = { "Anna", "Aim" } }, token = "target" },
	{ label = "a group member at a ready check", people = { party1 = { "Anna", "Aim" } }, token = "party1",
		groupSize = 2, setup = function(ns) ns.addon:READY_CHECK("READY_CHECK", BERT, 35) end },
	{ label = "somebody who asked", people = { nameplate1 = { "Anna", "Aim" } }, token = "nameplate1",
		setup = function(ns)
			ns.db.profile.sources.asked = true
			ns.db.profile.sources.strangers = false
			ns.addon:CHAT_MSG_WHISPER("CHAT_MSG_WHISPER", "int pls", ANNA, "Common", "", "", "", 0, 0, "",
				0, 1, "Player-1-nameplate1")
		end, reason = "asked" },
}) do
	local scenario = "pvp: nobody flagged is offered, whatever the reason (" .. case.label .. ")"
	with(scenario, { people = case.people, groupSize = case.groupSize }, function(ns)
		if case.setup then case.setup(ns) end
		local anna = look(ns, ANNA)
		if not anna or (case.reason and anna.reason ~= case.reason) then
			fail(scenario, "SKIPPED -- Anna was not offered as " .. case.label .. " unflagged: "
				.. tostring(anna and anna.reason))
			return
		end
		Mock.pvp = { [case.token] = true }
		if offered(ns, ANNA) then
			fail(scenario, case.label .. " was offered while flagged for PvP")
		end
	end)
end

-- ------------------------------------------------------------------ pvp 14
-- /manners debug and Diagnostics say who is held back -- a handful by name,
-- then a count -- and that the rule stands aside while you are flagged; the
-- scan itself says nothing in chat.
do
	local scenario = "pvp: /manners debug and Diagnostics say who is held back"
	local people = {}
	for i = 1, 7 do people["nameplate" .. i] = { "Flag" .. string.char(64 + i), "Bearer" } end
	with(scenario, { people = people }, function(ns)
		Mock.pvp = { nameplate1 = true }
		Mock.printed = {}
		scan(ns, 2)
		if said():find("PvP", 1, true) then
			fail(scenario, "the scan spoke about PvP in chat unasked: " .. flat(said()))
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("FlagA Bearer|r: flagged for PvP -- buffing them would flag you", 1, true) then
			fail(scenario, "/manners debug does not say who is held back for PvP: " .. flat(said()))
		end
		local diag = findOption(ns.optionsTable, "pvpDiag")
		if not diag then
			fail(scenario, "Diagnostics has no line for PvP")
		elseif diag.hidden() or not tostring(diag.name()):find("FlagA Bearer", 1, true) then
			fail(scenario, "Diagnostics does not say who is held back for PvP")
		end
		local all = {}
		for i = 1, 7 do all["nameplate" .. i] = true end
		Mock.pvp = all
		local lines = pvpLines(ns)
		if not lines:find("...and 2 more flagged for PvP", 1, true) or lines:find("FlagF", 1, true) then
			fail(scenario, "seven held back are not five by name and a count: " .. flat(lines))
		end
		Mock.pvp.player = true
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("you are flagged for PvP", 1, true) then
			fail(scenario, "/manners debug does not say the rule stands aside while you are flagged")
		end
	end)
end
