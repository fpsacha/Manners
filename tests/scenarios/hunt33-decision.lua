-- Bug hunt 33, the decision core (Queue.lua, Core.lua, Favours.lua,
-- Requests.lua, GroupBuffs.lua). Each scenario here goes RED on the code as it
-- stands; the report names the fault and the minimal fix. Names start with
-- "hunt33-<area>:". Globals a scenario replaces are put back after it.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "C_UnitAuras", "UnitExists", "UnitName", "IsSpellKnown", "IsPlayerSpell",
	"UnitIsDeadOrGhost", "UnitInParty", "UnitInRaid", "GetNumGroupMembers", "IsInRaid",
	"C_FriendList", "UnitLevel", "UnitClass", "UnitGUID", "GetItemCount", "IsUsableSpell",
	"C_Item", "C_Spell", "UnitIsVisible", "UnitIsPVP" }

-- One scenario: the mock reset to `flavour` as `class`, `names` standing about on
-- their tokens, the addon loaded and driven to a fresh prompt, body(ns) run, and
-- everything put back.
local function run(scenario, flavour, class, names, body, before)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = class or "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		if before then before() end
		restore = strangers(names or {})
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function queueNames(ns)
	local out = {}
	for _, entry in ipairs((ns.BuildQueue())) do out[#out + 1] = entry.name end
	return table.concat(out, ",")
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- ------------------------------------------------------ the never-offer list: a namesake
-- hunt33-never: Queue.lua ListedAs / SameName(key, ShortName(name)).
--
-- Off Forever somebody from another realm is filed "Anna-Aim", and the prompt
-- shows her as "Anna". A same-realm Anna is filed "Anna". Listing her (the
-- prompt's shift-right-click files her under "Anna") matches every later
-- "Anna-<realm>" through the realm taken off, so a different player, who was
-- never listed and is not the person the line named, is never offered
-- anything either -- the namesake mistake hunt 23 mended for friends.
for _, flavour in ipairs({ "vanilla", "mainline" }) do
	local scenario = "hunt33-never: listing a same-realm Anna does not list a namesake from another realm ("
		.. flavour .. ")"
	run(scenario, flavour, "MAGE", {
		nameplate1 = { "Anna" }, nameplate2 = { "Anna", "Aim" },
	}, function(ns)
		Mock.crossRealm = true
		Mock.advance(60)
		for unit in pairs(Mock.unitNames) do ns.nameplateUnits[unit] = true end
		local before = {}
		for _, entry in ipairs(ns.BuildQueue()) do before[entry.name] = true end
		if not (before["Anna"] and before["Anna-Aim"]) then
			fail(scenario, "SKIPPED -- both Annas were not offered to begin with: " .. queueNames(ns))
			return
		end
		local listed = ns.PutOnNeverList("Anna")
		local names = {}
		for _, entry in ipairs(ns.BuildQueue()) do names[entry.name] = true end
		if names["Anna"] then
			fail(scenario, "SKIPPED -- the listed Anna was still offered")
			return
		end
		if not names["Anna-Aim"] then
			fail(scenario, "listing '" .. tostring(listed) .. "' also took Anna-Aim, a different player from another"
				.. " realm, off the prompt for good: " .. queueNames(ns))
		end
	end)

	-- The same match lets go the favour the namesake did you (PutOnNeverList
	-- walks the debts with the same rule), and the ledger row with it.
	local scenario2 = "hunt33-never: listing a same-realm Anna keeps the favour a namesake from another realm did you ("
		.. flavour .. ")"
	run(scenario2, flavour, "MAGE", { nameplate2 = { "Anna", "Aim" } }, function(ns)
		Mock.crossRealm = true
		Mock.advance(60)
		ns.owed["Anna-Aim"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		ns.PutOnNeverList("Anna")
		if not ns.owed["Anna-Aim"] then
			fail(scenario2, "listing 'Anna' let go the favour Anna-Aim, somebody else, did you")
		end
	end)
end
