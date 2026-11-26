-- A shaman's weapon imbue with a fishing pole in the main hand (GitHub issue
-- 56, LT2138 on CurseForge: "reminders for shaman weapon imbues do not appear
-- when you have a fishing pole equipped? You can't apply imbues to fishing
-- poles anyway"). Core.lua's OwnVerdict holds the imbue back ("noweapon")
-- while the hand holds weapon subclass 20; a real weapon there is offered it.
--
-- Every scenario name starts with "imbue-fishing:" so the mutations in
-- tests/mutations/imbue-fishing.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local ROCKBITER = 16316
local POLE, MACE = 6256, 2489
local SUBCLASS = { [POLE] = 20, [MACE] = 4 }

local function mine(ns)
	for _, e in ipairs(ns.BuildQueue()) do
		if e.reason == "self" then return e end
	end
	return nil
end

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "GetInventoryItemID", "C_Item" }

local function with(scenario, held, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "SHAMAN"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	rawset(_G, "IsSpellKnown", function(id) return id == ROCKBITER end)
	rawset(_G, "IsPlayerSpell", function(id) return id == ROCKBITER end)
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" and slot == 16 then return held end
		return nil
	end)
	local item = {}
	for k, v in pairs(saved.C_Item or {}) do item[k] = v end
	item.GetItemInfoInstant = function(id)
		if SUBCLASS[id] then return id, "Weapon", "", "", 0, 2, SUBCLASS[id] end
		return nil
	end
	rawset(_G, "C_Item", item)
	Mock.weaponEnchants = { [0] = {} }
	local undo = strangers({})
	local ok, err = pcall(function()
		Mock.playerHeld = {}
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		H.extrasOn(ns)
		Mock.playerHeld = {}
		ns.ForgetHands()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants = nil
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "imbue-fishing: a fishing pole in the main hand is not offered an imbue"
	with(scenario, POLE, function(ns)
		local e = mine(ns)
		if e and e.buff and e.buff.key == "rockbiterweapon" then
			fail(scenario, "Rockbiter Weapon was offered for a fishing pole")
		end
	end)
end

do
	local scenario = "imbue-fishing: a mace in the main hand is still offered its imbue"
	with(scenario, MACE, function(ns)
		local e = mine(ns)
		if not (e and e.buff and e.buff.key == "rockbiterweapon") then
			fail(scenario, "a shaman with a mace and no imbue on it was not offered Rockbiter Weapon: "
				.. tostring(e and e.buff and e.buff.key))
		end
	end)
end
