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

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- ------------------------------------------------------ favours: a reload in a fight
-- hunt33-favours: Favours.lua ScanOwnBuffs, `local key = spellId or knownAuras[..] or true`.
--
-- Retail and Forever hand the aura list over in a fight with the spell id of
-- each aura withheld and the instance id plain. A /reload (or a login into a
-- restricted fight) primes the baseline on two agreeing readings, every aura
-- filed under the key `true`. When the fight ends the same auras read with their
-- real spell ids: the key differs, IsNew calls each one new ("it may have landed
-- in the fight"), and every buff you were already wearing from somebody is
-- announced as a favour they just did you, with a debt and a chat line.
for _, case in ipairs({
	{ "camelot", true }, { "mainline", true },
	-- Control: the same reload with the spell ids readable all through is quiet.
	{ "camelot", false },
}) do
	local scenario = "hunt33-favours: a reload in a fight does not turn what you already wear into favours"
	local flavour, withhold = case[1], case[2]
	if not withhold then scenario = scenario .. " (control: ids readable)" end
	local hide = false
	run(scenario, flavour, "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		local api = C_UnitAuras
		rawset(_G, "C_UnitAuras", {
			GetUnitAuraBySpellID = api.GetUnitAuraBySpellID,
			GetAuraDataByIndex = function(unit, i)
				local aura = api.GetAuraDataByIndex(unit, i)
				if aura and hide then
					local copy = {}
					for k, v in pairs(aura) do copy[k] = v end
					copy.spellId = Mock.SECRET
					return copy
				end
				return aura
			end,
		})
		wipe(ns.owed)
		Mock.printed = {}
		-- Logged in (reloaded) in the middle of a fight, spell ids withheld.
		Mock.inCombat = true
		hide = withhold
		ns.addon:PLAYER_REGEN_DISABLED()
		ns.addon:PLAYER_ENTERING_WORLD(nil, false, true)
		for _ = 1, 40 do Mock.runTimers(0.1) end
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline did not settle in the fight")
			return
		end
		-- The fight ends and the spell ids read again.
		Mock.inCombat = false
		hide = false
		Mock.advance(2)
		ns.addon:PLAYER_REGEN_ENABLED()
		ns.addon:UNIT_AURA(nil, "player")
		Mock.runTimers(1)
		if next(ns.owed) then
			fail(scenario, "buffs worn since before the reload were filed as new favours from "
				.. tostring((next(ns.owed))) .. " once the fight ended: " .. flat(table.concat(Mock.printed, " | ")))
		end
	end)
end
