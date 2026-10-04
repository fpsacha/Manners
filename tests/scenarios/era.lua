-- Classic Era 1.15.9, as the mock stands in for it (Mock.setFlavour("vanilla")):
-- interface 11509, a combat log, no secret values, no surnames, conditional
-- targeting, no C_Item.GetWeaponEnchantInfo and no C_PaperDollInfo. What was
-- read off the classic_era branch of Gethe/wow-ui-source to build it is in
-- tests/mockapi.lua's FLAVOURS.
--
-- Nobody here has played Era, so every scenario below is a claim about the
-- mock as much as about the addon. What they hold the addon to is the part
-- that is the addon's: the vanilla tables chosen and none of Forever's own,
-- every class's buffs found by the calls Era really has, the log read where
-- Era keeps it, a stranger targeted by the name Era gives them, a group cast
-- aimed at one raid group, and the options window built with and without the
-- client's menus.
--
-- Every scenario name starts with "era:" so the mutations in
-- tests/mutations/era.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- Globals a scenario replaces, put back after each one whatever happens:
-- Mock.reset owns none of them.
local TOUCHED = {
	"IsSpellKnown", "IsPlayerSpell", "C_SpellBook", "MenuUtil", "UnitExists",
	"UnitClass", "UnitInParty", "GetItemCount", "C_UnitAuras",
}

-- One Era session: `opts.class` (a mage by default), knowing `opts.known`
-- (spell ids) through the deprecated globals, or through C_SpellBook alone
-- with `opts.spellBook`; `opts.before` runs ahead of the load. body(ns) runs
-- with the lifecycle driven and the probe taken.
local function era(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = opts.class or "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		if opts.known then
			local set = {}
			for _, id in ipairs(opts.known) do set[id] = true end
			if opts.spellBook then
				-- Blizzard_DeprecatedSpellBook not loaded: the two globals are
				-- gone, and C_SpellBook is how Era answers.
				rawset(_G, "IsSpellKnown", nil)
				rawset(_G, "IsPlayerSpell", nil)
				rawset(_G, "C_SpellBook", {
					IsSpellInSpellBook = function(id) return set[id] == true end,
					IsSpellKnown = function(id) return set[id] == true end,
				})
			else
				IsSpellKnown = function(id) return set[id] == true end
				IsPlayerSpell = IsSpellKnown
			end
		end
		if opts.before then opts.before() end
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		Mock.printed = {}
		body(ns)
		if not opts.allowErrors then guarded(scenario, ns) end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the client
-- Era is recognised for what it is and handed the vanilla tables as they are:
-- no mage scrolls (Forever's own), Blessing of Sanctuary still there, Omen of
-- Clarity still a buff a druid casts, a group spell reaching one party.
do
	local scenario = "era: Classic Era is read as vanilla and given the vanilla set without Forever's scrolls"
	era(scenario, {}, function(ns)
		local f, caps = ns.Flavour or {}, ns.caps or {}
		if f.flavour ~= "vanilla" or f.family ~= "classic" or f.interface ~= 11509 then
			fail(scenario, "read as " .. tostring(ns.FlavourSummary and ns.FlavourSummary()))
		end
		if ns.BUFFS_SOURCE ~= "vanilla" then
			fail(scenario, "handed the " .. tostring(ns.BUFFS_SOURCE) .. " set")
		end
		if ns.GROUP_IS_RAID ~= false or ns.PARTY_IS_SUBGROUP ~= true then
			fail(scenario, ("a group spell is taken to reach the whole raid (GROUP_IS_RAID=%s,"
				.. " PARTY_IS_SUBGROUP=%s)"):format(tostring(ns.GROUP_IS_RAID), tostring(ns.PARTY_IS_SUBGROUP)))
		end
		if caps.combatLog ~= true then fail(scenario, "no combat log on a client that has one") end
		if caps.secretRestrictions ~= false then
			fail(scenario, "secretRestrictions=" .. tostring(caps.secretRestrictions) .. " on a client without secrets")
		end
		if caps.unitNameIsSurname ~= false then fail(scenario, "UnitName's realm is taken for a surname") end
		-- No scroll and no familiar anywhere: items and spells only Forever has.
		for class, families in pairs(ns.OWN_BUFFS or {}) do
			for _, family in ipairs(families) do
				if family.scroll or family.imbue then
					fail(scenario, class .. " has Forever's " .. tostring(family.key) .. " on Era")
				end
				for _, spell in ipairs(family.spells or {}) do
					if spell.item then
						fail(scenario, class .. " is reminded of scroll " .. tostring(spell.key) .. ", which Era has none of")
					end
				end
			end
		end
		-- The mock holding to what the classic_era branch documents, so the
		-- rest of this file is about Era and not about Forever renamed.
		if C_PaperDollInfo ~= nil or (C_Item and C_Item.GetWeaponEnchantInfo) ~= nil
			or type(GetWeaponEnchantInfo) ~= "function"
			or type(C_CombatLog and C_CombatLog.GetCurrentEventInfo) ~= "function" then
			fail(scenario, "the mock is not Era: C_PaperDollInfo, C_Item.GetWeaponEnchantInfo,"
				.. " GetWeaponEnchantInfo or C_CombatLog is not as the classic_era branch has it")
		end
		if not ns.FindBuff("PALADIN", "sanctuary") then
			fail(scenario, "Era's paladin has no Blessing of Sanctuary")
		end
		if not ns.FindOwnFamily("omen") then
			fail(scenario, "Era's druid has no Omen of Clarity to cast on himself")
		end
	end)
end

-- ------------------------------------------------------------------ class buffs
-- Every class's buffs are found by the top rank it knows, and named, so the
-- macro has a spell to cast: through the deprecated globals and, with
-- Blizzard_DeprecatedSpellBook not loaded, through C_SpellBook alone.
local CLASSES = {
	{ class = "MAGE", buffs = { intellect = 10157 } },
	{ class = "PRIEST", buffs = { fortitude = 10938, spirit = 27841, shadow = 10958 } },
	{ class = "DRUID", buffs = { motw = 9885, thorns = 9910 } },
	{ class = "PALADIN", buffs = { wisdom = 25290, might = 25291, kings = 20217, salvation = 1038,
		light = 19979, sanctuary = 20914 } },
	{ class = "WARLOCK", buffs = { breath = 5697 } },
	{ class = "WARRIOR", buffs = { battleshout = 25289 } },
}
for _, spellBook in ipairs({ false, true }) do
	for _, case in ipairs(CLASSES) do
		local scenario = ("era: a %s's buffs are found (%s)"):format(case.class:lower(),
			spellBook and "C_SpellBook" or "IsSpellKnown")
		local known = {}
		for _, id in pairs(case.buffs) do known[#known + 1] = id end
		era(scenario, { class = case.class, known = known, spellBook = spellBook }, function(ns)
			for key, id in pairs(case.buffs) do
				local info = ns.caps.buffs and ns.caps.buffs[key]
				if not (info and info.known) then
					fail(scenario, key .. " is not known with rank " .. id .. " learned")
				elseif info.topRank ~= id then
					fail(scenario, key .. "'s top rank is " .. tostring(info.topRank) .. ", wanted " .. id)
				elseif type(info.name) ~= "string" then
					fail(scenario, key .. " has no name to cast it by")
				end
			end
			if not ns.CanCastAnything() then fail(scenario, "nothing to cast for a class that knows its buffs") end
		end)
	end
end

-- A druid's own: Omen of Clarity is cast on Era, and asked for when it is down.
do
	local scenario = "era: a druid without Omen of Clarity up is offered it"
	era(scenario, { class = "DRUID", known = { 9885, 16864 }, before = function()
		Mock.playerHeld = { [9885] = true }
	end }, function(ns)
		local info = ns.caps.own and ns.caps.own.omen
		if not (info and info.known) then
			fail(scenario, "Omen of Clarity is not known to a druid who has it")
			return
		end
		ns.db.profile.sources.self = true
		local found
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" and entry.buff and entry.buff.key == "omen" then found = entry end
		end
		if not found then fail(scenario, "Omen of Clarity down and never offered") end
	end)
end

-- ------------------------------------------------------------------ the combat log
-- Era keeps the log reading in C_CombatLog.GetCurrentEventInfo, and the global
-- CombatLogGetCurrentEventInfo only in Blizzard_DeprecatedCombatLog, which
-- loads with the loadDeprecationFallbacks setting. With it off, a stranger
-- who buffs you is still filed from the log.
for _, fallbacks in ipairs({ true, false }) do
	local scenario = "era: a buff from a stranger is read off the combat log (deprecation fallbacks "
		.. (fallbacks and "on" or "off") .. ")"
	era(scenario, { before = function()
		Mock.deprecationFallbacks = fallbacks
		Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" } }
	end }, function(ns)
		if not ns.logScan.armed then
			fail(scenario, "the combat log was never armed on a client that has one")
			return
		end
		Mock.advance(60)
		wipe(ns.owed)
		ns.addon:COMBAT_LOG_EVENT_UNFILTERED()
		if not ns.owed["Petra"] then
			fail(scenario, "Petra's Fortitude landed and the log filed nobody (noted "
				.. tostring(ns.logScan.noted) .. ")")
		elseif ns.owed["Petra"].class ~= "PRIEST" then
			fail(scenario, "filed as " .. tostring(ns.owed["Petra"].class))
		end
	end)
end

-- ------------------------------------------------------------------ the macro
-- A stranger is targeted by the name Era gives them: UnitName's second return
-- is a realm there, empty for somebody from your own, and never a surname.
-- The macro is the /target route Manners uses on every client.
do
	local scenario = "era: a stranger is targeted by their own name, with no surname"
	era(scenario, { before = function()
		H.strangers({ nameplate1 = { "Petra", "Stonewell" } })
	end }, function(ns)
		H.clearClicks(ns)
		if ns.UnitFullName("nameplate1") ~= "Petra" then
			fail(scenario, "nameplate1 is filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		ns.addon:Tick()
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("/target Petra\n", 1, true) then
			fail(scenario, "the macro does not target Petra: " .. flat(text))
		elseif text:find("Stonewell", 1, true) then
			fail(scenario, "a realm-less stranger is targeted with a surname: " .. flat(text))
		elseif not text:find("/cast Arcane Intellect", 1, true) then
			fail(scenario, "the macro casts nothing: " .. flat(text))
		end
	end)
end

-- From another realm the realm comes off the /target line, and stays on the
-- name the debt is filed under.
do
	local scenario = "era: a stranger from another realm is filed with the realm and targeted without it"
	era(scenario, { before = function()
		Mock.crossRealm = true
		H.strangers({ nameplate1 = { "Petra", "Ravencrest" } })
	end }, function(ns)
		H.clearClicks(ns)
		if ns.UnitFullName("nameplate1") ~= "Petra-Ravencrest" then
			fail(scenario, "filed as " .. tostring(ns.UnitFullName("nameplate1")))
		end
		if ns.TargetName("Petra-Ravencrest") ~= "Petra" then
			fail(scenario, "targeted as " .. tostring(ns.TargetName("Petra-Ravencrest")))
		end
	end)
end

-- ------------------------------------------------------------------ group casts
-- In a raid a group spell reaches the target's own party on Era, so it needs
-- a target there and counts one raid group. Subgroup 2 (raid6-10) has four
-- missing Arcane Intellect: one Arcane Brilliance, aimed at one of them,
-- reaching those four and nobody from the player's own subgroup.
do
	local scenario = "era: a group cast is aimed at one raid group and counts that group alone"
	local ARCANE_POWDER, BRILLIANCE = 17020, 23028
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	-- raid1 is the player; raid4 and raid5 wear it, raid2 and raid3 do not.
	local held = { raid4 = { [10157] = true }, raid5 = { [10157] = true }, raid10 = { [10157] = true } }
	era(scenario, { known = { 10157, 10156, 1461, 1460, 1459, BRILLIANCE }, before = function()
		Mock.raid = { size = 10, player = 1 }
		H.strangers(names)
		GetItemCount = function(id) return id == ARCANE_POWDER and 20 or 0 end
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, spellId)
				if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
				if held[unit] and held[unit][spellId] then
					return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600 }
				end
				return nil
			end,
		}, { __index = base }))
	end }, function(ns)
		H.clearClicks(ns)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local group
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then group = group or entry end
		end
		if not group then
			fail(scenario, "no group cast for the raid group with four missing it")
			return
		end
		local covered = { [group.name] = true }
		for _, name in ipairs(group.groupCast.members or {}) do covered[name] = true end
		for _, name in ipairs({ "Raider6", "Raider7", "Raider8", "Raider9" }) do
			if not covered[name] then fail(scenario, name .. " is missing from the group cast") end
		end
		for _, name in ipairs({ "Raider2", "Raider3", "Raider10" }) do
			if covered[name] then fail(scenario, name .. " is counted in another raid group's cast") end
		end
		local text = macro(ns)
		if type(text) ~= "string" or not text:find("/cast Arcane Brilliance", 1, true) then
			fail(scenario, "the press does not cast Arcane Brilliance: " .. flat(text))
		elseif not text:find("/target Raider[6-9]\n") then
			fail(scenario, "Era's Arcane Brilliance reaches the target's party, and the macro targets nobody in that raid group: "
				.. flat(text))
		end
	end)
end

-- ------------------------------------------------------------------ the options window
-- Era has the client's own menus (Blizzard_Menu loads there, with MenuUtil)
-- and the Settings window. Every page builds either way, a dropdown opens the
-- menu where there is one and steps to the next choice where there is not,
-- and the Settings entry is registered.
for _, withMenu in ipairs({ true, false }) do
	local scenario = "era: the options window builds " .. (withMenu and "with" or "without") .. " MenuUtil"
	era(scenario, { known = { 10157 }, before = function()
		Mock.installSettings()
		if withMenu then Mock.useMenu() else rawset(_G, "MenuUtil", nil) end
	end }, function(ns)
		local UI = ns.WindowUI
		if not (UI and ns.WindowLayout) then
			fail(scenario, "SKIPPED -- no options window in this checkout")
			return
		end
		ns.OpenOptions()
		local pages = 0
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do
				if (UI.visiblePages or {})[id] then
					ns.OpenOptions(id)
					ns.RefreshOptionsDisplay()
					pages = pages + 1
				end
			end
		end
		if pages < 3 then fail(scenario, ("only %d pages opened"):format(pages)) end

		ns.OpenOptions("appearance")
		local row = UI.RowFor("appearance.style")
		if not (row and row.field) then
			fail(scenario, "SKIPPED -- no look dropdown on Look")
		else
			local P = ns.db.profile.prompt
			local was = P.style
			Mock.menu = nil
			row.field:Click()
			if withMenu then
				if not Mock.menu then fail(scenario, "the look dropdown opened no menu") end
				if P.style ~= was then fail(scenario, "opening the menu changed the look") end
			else
				if P.style == was then
					fail(scenario, "with no MenuUtil the look dropdown does nothing: still " .. tostring(was))
				end
			end
		end
		ns.CloseOptions()

		local record = Mock.settings
		if not (record and #record.canvases >= 1 and #record.added >= 1) then
			fail(scenario, "no Manners entry in Era's Settings window")
		end
	end)
	Mock.removeSettings()
end
