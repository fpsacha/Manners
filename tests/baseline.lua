-- A fingerprint of what this addon decides and arms, printed in a stable order.
--
-- It exists for one job: proving that a change made for another WoW client did
-- not move WoW Forever's behaviour. Forever is the only client anybody here can
-- test, and only one class on it has ever been verified in game, so "the suites
-- are still green" is not enough -- a suite asserts what somebody thought to
-- assert, and this prints everything whether anybody thought of it or not.
--
-- Run it before a change and after, and diff the two. An intended difference
-- shows up as a line; an unintended one shows up the same way, which is the
-- point.
--
--     python tests/baseline.py > before.txt
--     ...make the change...
--     python tests/baseline.py > after.txt
--     diff before.txt after.txt

local dir = ...

dofile(dir .. "/tests/mockapi.lua")

local function load()
	local ns = {}
	for _, file in ipairs({ "Buffs.lua", "Core.lua", "Prompt.lua", "Options.lua" }) do
		local chunk, err = loadfile(dir .. "/" .. file)
		if not chunk then return nil, "load " .. file .. ": " .. tostring(err) end
		local ok, runErr = pcall(chunk, "Manners", ns)
		if not ok then return nil, "run " .. file .. ": " .. tostring(runErr) end
	end
	return ns
end

-- Sorted, because a table walk is not a stable order and a diff full of
-- reordered lines hides the one line that matters.
local function sortedKeys(t)
	local keys = {}
	for k in pairs(t or {}) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	return keys
end

local function show(value)
	if value == nil then return "nil" end
	if type(value) == "string" then return value end
	return tostring(value)
end

local CLASSES = { "MAGE", "PRIEST", "DRUID", "PALADIN", "WARLOCK", "WARRIOR",
	"HUNTER", "ROGUE", "SHAMAN" }

print("== Manners behaviour fingerprint ==")

-- Solo and grouped. A party-only buff -- which is the whole of what a warrior
-- has to give -- is unreachable in the solo pass, so the self-cast macro would
-- otherwise be absent from the record, and it is the shape nobody has run in
-- game.
local SETUPS = {
	{ name = "alone", groupSize = 0 },
	{ name = "in a group of 3", groupSize = 3 },
}

for _, class in ipairs(CLASSES) do
for _, setup in ipairs(SETUPS) do
	Mock.reset()
	Mock.class = class
	Mock.groupSize = setup.groupSize

	local ns, err = load()
	if not ns then
		print(("\n-- %s, %s\n  LOAD FAILED: %s"):format(class, setup.name, err))
	else
		print(("\n-- %s, %s"):format(class, setup.name))

		-- Teach the client this character's own spells. Without it only the
		-- mock's default class knows anything, and every other class prints
		-- "nothing offered" -- which fingerprints the mock rather than the
		-- addon, and would go on matching after a change broke the macro.
		local known = {}
		for _, buff in ipairs(ns.BUFFS[class] or {}) do
			for _, id in ipairs(buff.ranks) do known[id] = true end
		end
		local realKnown = IsSpellKnown
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown

		ns.addon:OnInitialize()
		ns.addon:OnEnable()
		ns.addon:PLAYER_ENTERING_WORLD()
		Mock.advance(60)
		ns.Guard("probe", ns.ProbeCapabilities)

		-- What the client is judged to allow.
		print(("  caps: class=%s hasClassBuffs=%s anyKnown=%s anyReadable=%s"):format(
			show(ns.caps.class), show(ns.caps.hasClassBuffs),
			show(ns.caps.anyKnown), show(ns.caps.anyReadable)))
		print(("  caps: auraBySpellId=%s secrets=%s nameplates=%s"):format(
			show(ns.caps.getUnitAuraBySpellID), show(ns.caps.hasSecrets),
			show(ns.caps.namePlates)))

		-- Every buff, and what was learned about it.
		for _, key in ipairs(sortedKeys(ns.caps.buffs)) do
			local info = ns.caps.buffs[key]
			print(("  buff %-12s name=%-28s known=%-5s readable=%s"):format(
				key, show(info.name), show(info.known), show(info.readable)))
		end

		-- What it would offer, to whom, and why.
		local queue = ns.BuildQueue()
		print(("  queue: %d"):format(#queue))
		for i, entry in ipairs(queue) do
			print(("    %d %-22s buff=%-12s reason=%-8s unit=%-10s priority=%s known=%s"):format(
				i, show(entry.name), show(entry.buff and entry.buff.key),
				show(entry.reason), show(entry.unit), show(entry.priority),
				show(entry.known)))
		end

		-- The macro that would actually run. This is the line that matters most:
		-- it is the addon's whole output, and the form it takes is the single
		-- thing about this client that took ten attempts to get right.
		local top = queue[1]
		if top then
			ns.Prompt:ApplyTarget(top)
			local button = ns.Prompt:GetButton()
			local macro = button and button.attributes and button.attributes["macrotext1"]
			print("  macro:")
			for line in tostring(macro or "(none)"):gmatch("[^\n]+") do
				print("    | " .. line)
			end
			print(("  attributes: type1=%s type=%s type2=%s"):format(
				show(button.attributes["type1"]), show(button.attributes["type"]),
				show(button.attributes["type2"])))
		else
			print("  macro: (nothing offered)")
		end

		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown

		-- Anything the addon caught on the way through. Silence here is part of
		-- the fingerprint too.
		if ns.errors and #ns.errors > 0 then
			for _, e in ipairs(ns.errors) do
				print(("  CAUGHT %s: %s"):format(show(e.where), show(e.err)))
			end
		end
	end
end
end

print("\n== end ==")
