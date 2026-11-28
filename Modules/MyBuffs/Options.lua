-- Manners: My Buffs -- option controls owned by the optional module.

local api = assert(MannersAPI, 'Manners is required')
local ns = assert(api:ModuleContext('mybuffs'), 'Manners module API is missing')
local L, Page = ns.L, ns.OptionsPage
local InCombatLockdown = _G.InCombatLockdown
local function S() return api:GetProfile().sources end
local function sGet(info) return S()[info[#info]] == true end
local function sSet(info, value) S()[info[#info]] = value == true end

local function NothingForSelf()
	-- Well Fed is a family of every class on a client that has it, bags or
	-- none; a flask in the bags, switched off, is no known family yet: their
	-- switches are under Myself all the same (Page.BaggedShown; a retail
	-- warrior's flask, whose shout is no buff of his own).
	return #ns.SelfBuffs() == 0 and #ns.KnownOwnFamilies() == 0 and not Page.BaggedSwitchShown()
end

-- The family dropdown's Automatic, saying what it would pick right now, in
-- plain words, from the same answer the scan uses (ns.OwnAutoPick).
local function OwnAutoLabel(family)
	local spell, why = ns.OwnAutoPick(family)
	if why == "tank" or why == "notank" then return L["Automatic (only while I'm the tank)"] end
	-- Passing over one somebody else of your class has on you: no one spell
	-- to name for long, since theirs comes and goes.
	if why == "covered" then return L["Automatic"] end
	local name = spell and ns.BuffName(spell)
	if not name then return L["Automatic"] end
	if why == "last" then return L["Automatic (%s, the one you had up last)"]:format(name) end
	if why == "dungeon" then return L["Automatic (%s, in a dungeon or raid)"]:format(name) end
	if why == "world" then return L["Automatic (%s, outside dungeons and raids)"]:format(name) end
	if why == "best" then return L["Automatic (%s, the best you can use now)"]:format(name) end
	return L["Automatic (%s, until you have put one up)"]:format(name)
end

-- The choices a family's dropdown lists: the spells you know, or for a
-- mage's scrolls every one of them, so a pick stays on the list while you
-- have none of it left. A weapon enhancement has dozens to a family, so its
-- list is the ones your bags hold and the one picked, which stays while the
-- bags are empty of it.
local function OwnChoice(family, spell)
	if family.enhance then
		local picks = ns.db.profile.ownBuffs.pick
		return ns.OwnSpellKnown(spell) or (type(picks) == "table" and picks[family.key] == spell.key)
	end
	return family.scroll or ns.OwnSpellKnown(spell)
end

-- A flask, an elixir or a scroll (Buffs.lua, consumable): whether any of the
-- family is in the bags, asked of the client only for the page, and what its
-- switch says it does.
local Consumable = {}
function Consumable.Held(family)
	local count = C_Item and C_Item.GetItemCount
	if type(count) ~= "function" then return false end
	for _, spell in ipairs(family.spells) do
		local n = ns.plain(count(spell.item))
		if type(n) == "number" and n > 0 then return true end
	end
	return false
end
function Consumable.Desc(family)
	if family.key == "flask" then
		return L["Reminds you to drink a flask when none is on you and one is in your bags, the best you can use first. Off until you turn it on."]
	elseif family.slot then
		-- Burning Crusade and Mists: a family a slot (Buffs.lua, CONSUME).
		local text = family.slot == "guardian"
			and L["Reminds you to drink a guardian elixir when no guardian elixir or flask is on you and one is in your bags, the best you can use first. A flask fills both elixir slots. Off until you turn it on."]
			or L["Reminds you to drink a battle elixir when no battle elixir or flask is on you and one is in your bags, the best you can use first. A flask fills both elixir slots. Off until you turn it on."]
		-- Mists: a scroll takes one of the two slots (Buffs.lua, slotScrolls).
		if family.slotScrolls then
			text = text .. " " .. L["A scroll counts as a battle or a guardian elixir, as its own tooltip says."]
		end
		return text
	elseif family.key == "elixir" then
		return L["Reminds you to drink an elixir when none is on you and one is in your bags, the best you can use first. Off until you turn it on."]
	end
	local text = L["Reminds you to use one on yourself when none of it is on you and one is in your bags, the best you can use first. Off until you turn it on."]
	-- Intellect, Stamina and Spirit where a class buff gives the same stat.
	ns.ConsumableAuras(family)
	if family.classBuff then
		text = text .. " " .. L["Not while a class buff of the same stat is on you."]
	end
	return text
end

-- Whether the Scrolls switch is shown: on a client where your class has a
-- scroll (Buffs.lua, isScroll; never retail), while it is off, so it can be
-- turned on again, or while the switch of any scroll is shown: a stat scroll
-- switched on or in the bags, a mage's familiar or imbue in the bags.
local function ScrollSwitchShown()
	if not ns.HasScrollFamilies() then return false end
	if ns.db.profile.ownBuffs.scrolls == false then return true end
	for _, family in ipairs(ns.GetOwnFamilies() or {}) do
		if family.isScroll and family.consumable and (ns.OwnPick(family) ~= "off" or Consumable.Held(family)) then
			return true
		end
	end
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.isScroll then return true end
	end
	return false
end

-- One control per family of your class's own buffs, under "Myself" on Who to
-- buff: a dropdown where there is a choice (Automatic, each spell you know,
-- Don't remind me), a checkbox for a spell alone. Made for every family of
-- every class on this client and hidden but for your class's and the ones you
-- know, so learning an aspect mid-session shows it without a reload.
local function AddOwnControls(args)
	local order = 15.2
	local classes = {}
	for class in pairs(ns.OWN_BUFFS or {}) do classes[#classes + 1] = class end
	table.sort(classes)
	for _, class in ipairs(classes) do
		for _, family in ipairs(ns.OWN_BUFFS[class]) do
			-- The player's own added spells (OwnSpells.lua, `custom`), always last,
			-- have no control of their own: their rows are Add a spell of my own's.
			if family.custom then break end
			-- A family of several classes (tracking, a stone) is made once for each,
			-- and the last stands; a thousandth apiece keeps every one of them
			-- inside 15.2x, ahead of Also in cities and inns at 15.9.
			order = order + 0.001
			local pick = function() return (ns.OwnPick(family)) end
			local write = function(_, value)
				ns.db.profile.ownBuffs.pick[family.key] = value
				-- Food (and the sleeping bag) is counted in the bags only while
				-- its switch is on.
				if family.bagged and ns.ForgetScrolls then ns.ForgetScrolls() end
				-- Nor a reagent (a Soul Shard for a stone to make).
				if (family.reagent or family.holds) and ns.ForgetScrolls then ns.ForgetScrolls() end
				-- The prompt follows at once rather than at the next scan.
				ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
			end
			local control = {
				order = order,
				width = "full",
				hidden = function()
					-- Every scroll's switch goes while Scrolls is off, its pick kept.
					if ns.ScrollsOff(family) then return true end
					-- Shown bags or none: food is not counted until it is switched on.
					if family.food then return false end
					-- A companion pet: shown while one is in the bags or the journal,
					-- or switched on (Options/Shared.lua, BaggedHeld).
					if family.pet then return pick() == "off" and not Page.BaggedHeld(family) end
					-- The sleeping bag, which few have: shown while it is in the
					-- bags or switched on. Asked of the client only here.
					if family.rest then
						if pick() ~= "off" then return false end
						local count = C_Item and C_Item.GetItemCount
						local n = type(count) == "function" and ns.plain(count(family.spells[1].item)) or nil
						return not (type(n) == "number" and n > 0)
					end
					-- A flask, an elixir or a scroll: the same, for any of its items.
					if family.consumable then return pick() == "off" and not Consumable.Held(family) end
					for _, known in ipairs(ns.KnownOwnFamilies()) do
						if known == family then return false end
					end
					return true
				end,
				disabled = function() return not S().self end,
			}
			if (#family.spells > 1 or family.tank) and not family.bagged then
				control.type = "select"
				control.name = function() return ns.OwnFamilyLabel(family) end
				control.desc = function()
					if family.tank then
						return L["Automatic reminds you while your group role is tank, or, when you are alone, while your talents are a tank's; Always reminds you whenever it is not up."]
					end
					-- Fire Ward or Frost Ward (Buffs.lua, brief): outside a fight only.
					if family.brief then return L["Reminds you when no ward is on you. Automatic takes the one you had up last, else the first you know. Outside a fight only: from the pull until the fight ends Manners offers no ward, so in a fight you recast it yourself. Off until you turn it on."] end
					if family.enhance then
						-- A poison keeps the kind last on its hand (Buffs.lua, byLine);
						-- the rest take the best (Core.lua, Best).
						if family.byLine then
							return L["Reminds you when nothing is on the weapon in your %s and one of these in your bags fits it. Automatic takes the kind you had on that hand last, at the best rank your level allows, else the first you can use; pick one by name to keep to it."]
								:format(ns.HandName(family.slot))
						end
						return L["Reminds you when nothing is on the weapon in your %s and one of these in your bags fits it. Automatic takes the best you can use now: by your level, weapon and Fishing, an oil by your group role or talents, a warlock's stone by your talents; pick one by name to keep to it."]
							:format(ns.HandName(family.slot))
					end
					-- A shaman's imbues are spells, with no scroll to name (Buffs.lua, shamanimbue).
					if family.imbue and not family.spells[1].item then
						-- Retail's off hand, and a paladin's rites (Buffs.lua, MAINLINE_OWN).
						if family.slot == 17 then
							return L["Reminds you when no imbue is on the weapon or shield in your off hand. Automatic takes the first of these you know."]
						elseif family.key ~= "shamanimbue" then
							return L["Reminds you when no imbue is on the weapon in your main hand. Automatic takes the first of these you know."]
						end
						return L["Reminds you when no imbue is on the weapon in your main hand. Automatic takes the first of these you know, Windfury ahead of the rest."]
					end
					-- Making a Firestone or Spellstone (Buffs.lua, makes).
					if family.makes then
						return L["Reminds you to make a stone when none is in your bags or on the weapon in your main hand and a Soul Shard is in your bags. Once it is made, Firestone or Spellstone offers to put it on. Automatic makes the kind your talents favour, else the kind you used last. Off until you turn it on."]
					end
					if family.imbue then
						return L["Reminds you when nothing is on the weapon in your main hand and a scroll in your bags fits it. Automatic takes the best you can use now: one of the school your talents favour, then your level and weapon; pick one by name to keep to it."]
					elseif family.scroll then
						return L["Reminds you when no familiar is with you and a scroll for one is in your bags. Automatic takes the best your level allows."]
					end
					local text = L["Reminds you when none of these is up. Automatic takes the one you had up last; pick one to always be reminded of that one."]
					-- Demonic Sacrifice with Demonic Pact known (Buffs.lua, splitTo):
					-- Soul Link has moved to a switch of its own.
					local split = family.splitTo and ns.FindOwnFamily(family.splitTo)
					if split and ns.OwnSpellKnown(split.spells[1]) then
						return L["Reminds you when it is not up. With Demonic Pact, %s has a switch of its own below and is reminded of too."]
							:format(ns.BuffName(split.spells[1]))
					end
					-- A mage before any armor has been up: where Automatic
					-- goes, both ways, while that is what it is doing.
					local dungeon = family.dungeon and ns.FindOwnSpell(family.dungeon)
					local _, why = ns.OwnAutoPick(family)
					if dungeon and ns.OwnSpellKnown(dungeon) and (why == "dungeon" or why == "world") then
						for _, spell in ipairs(family.spells) do
							if spell ~= dungeon and ns.OwnSpellKnown(spell) and not spell.neverAuto then
								return text .. " " .. L["Until you have had one up: %s in a dungeon or raid, %s elsewhere."]
									:format(ns.BuffName(dungeon), ns.BuffName(spell))
							end
						end
					end
					return text
				end
				control.values = function()
					local values = { auto = OwnAutoLabel(family), off = L["Don't remind me"] }
					for _, spell in ipairs(family.spells) do
						if OwnChoice(family, spell) then
							values[spell.key] = family.tank and L["Always"] or ns.BuffName(spell)
						end
					end
					return values
				end
				-- Automatic, the spells in the table's order, Don't remind me:
				-- AceConfig would sort them by their translated names.
				control.sorting = function()
					local sorted = { "auto" }
					for _, spell in ipairs(family.spells) do
						if OwnChoice(family, spell) then sorted[#sorted + 1] = spell.key end
					end
					sorted[#sorted + 1] = "off"
					return sorted
				end
				control.get = pick
				control.set = write
			else
				control.type = "toggle"
				control.name = function() return ns.OwnFamilyLabel(family) end
				control.desc = family.consumable and function() return Consumable.Desc(family) end
					or family.food
					and L["Reminds you to eat when Well Fed is not on you and food that gives it is in your bags. Off until you turn it on. A food you keep for something else, a fishing food say, can be ticked under %s."]
						:format(L["Never remind me about"])
					-- Mists and retail: the journal alone, no pet is used from the bags.
					or family.pet and family.journal and #family.spells == 0
					and L["Keeps a companion pet out: Manners brings one out of your pet journal itself, with no press. Never in a fight, a dungeon, a raid, a battleground, an arena or a pet battle, nor while you are mounted, stealthed or flying, and a pet you put away stays away until you bring one out. Off until you turn it on."]
					or family.pet and family.journal
					and L["Keeps a companion pet out. Manners brings one out of your pet journal itself, with no press; a pet you use from your bags each time comes up on the prompt. Never in a fight, a dungeon, a raid, a battleground or an arena, nor while you are mounted, stealthed or flying, and a pet you put away stays away until you bring one out. Off until you turn it on."]
					or family.pet
					and L["Reminds you to bring out your companion pet when none is out and one is in your bags. Never in a fight, a dungeon, a raid, a battleground or an arena, nor while you are mounted, stealthed or flying, and a pet you put away stays away until you bring one out. Off until you turn it on."]
					or family.rest
					and L["Reminds you to lay down your Cozy Sleeping Bag when Well-Rested is not on you and the bag is in your bags. Not at the level cap, where there is no experience to gain. Off until you turn it on."]
					-- Mana Shield (Buffs.lua, brief): outside a fight only.
					or family.brief
					and L["Reminds you when it is not on you, outside a fight only: from the pull until the fight ends Manners does not offer it, so in a fight you recast it yourself. Off until you turn it on."]
					-- A healthstone to make (Buffs.lua, holds): on until it is unticked.
					or family.holds and (family.reagent
						and L["Reminds you to make a healthstone when none is in your bags and a Soul Shard is. Outside a fight only. Uncheck it if you would rather not be reminded."]
						or L["Reminds you to make a healthstone when none is in your bags. Outside a fight only. Uncheck it if you would rather not be reminded."])
					or family.optIn
					and L["Reminds you when it is not on you, whoever cast it. Off until you turn it on."]
					-- Forever's Find Treasure (Buffs.lua, onceUp): nothing until it has been up.
					or family.onceUp
					and L["Reminds you when it is not up, once you have had it up yourself."]
					-- Unending Breath on yourself (Buffs.lua, swimming).
					or family.swimming
					and L["Reminds you while you are swimming and it is not on you, whoever cast it. Never on dry land."]
					or family.form
					and L["Reminds you when you are not in it, and never while you are in another form."]
					-- Forever's Soul Link beside Demonic Sacrifice (Buffs.lua, pact).
					or family.pact
					and L["Reminds you when it is not up and a demon is out. With Demonic Pact it stands beside Demonic Sacrifice, which is reminded of first: the sacrifice takes the demon Soul Link needs."]
					or L["Reminds you when it is not up."]
				control.get = function() return pick() ~= "off" end
				control.set = function(info, value) write(info, value and "auto" or "off") end
			end
			args["own_" .. family.key] = control
		end
	end

	-- The spells of a family of several that can be left out one by one, for
	-- those you know: ticked, never offered. Under the families and above
	-- Also in cities and inns (15.9). Hidden while there is nothing to tick.
	-- Food has a list of its own, right under Well Fed (own_leave_food): the
	-- same ticks (ownBuffs.leave), shown where they belong.
	local function LeaveChoices(food)
		local values = {}
		for _, family in ipairs(ns.KnownOwnFamilies()) do
			if ns.OwnLeaveable(family) and (family.food and true or false) == (food == true) then
				for _, spell in ipairs(family.spells) do
					if ns.OwnSpellKnown(spell) then values[spell.key] = ns.BuffName(spell) end
				end
			end
		end
		return values
	end
	local function LeaveSet(_, key, on)
		ns.db.profile.ownBuffs.leave[key] = on and true or false
		-- The prompt follows at once rather than at the next scan.
		ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
	end
	local function LeaveGet(_, key) return ns.db.profile.ownBuffs.leave[key] == true end
	args.own_leave = {
		type = "multiselect",
		name = L["Never remind me about"],
		desc = L["Ticked spells are left out of Automatic and never offered, even one you picked above. The others of their kind still are."],
		order = 15.8,
		hidden = function() return next(LeaveChoices()) == nil end,
		disabled = function() return not S().self end,
		values = function() return LeaveChoices() end,
		get = LeaveGet,
		set = LeaveSet,
	}
	-- The foods to leave out, under Well Fed, while it is on.
	args.own_leave_food = {
		type = "multiselect",
		name = L["Never remind me about"],
		desc = L["Ticked spells are left out of Automatic and never offered, even one you picked above. The others of their kind still are."],
		order = 15.79,
		hidden = function()
			local family
			for _, f in ipairs(ns.KnownOwnFamilies()) do
				if f.food then family = f end
			end
			return not family or ns.OwnPick(family) == "off" or next(LeaveChoices(true)) == nil
		end,
		disabled = function() return not S().self end,
		values = function() return LeaveChoices(true) end,
		get = LeaveGet,
		set = LeaveSet,
	}
	-- Elixirs to keep up at once (Classic Era, Forever: Buffs.lua, `keep`;
	-- ownBuffs.elixirKeep), under the elixir switch while it is on Automatic:
	-- those in the bags, and any already ticked.
	local function KeepFamily()
		for _, family in ipairs(ns.GetOwnFamilies() or {}) do
			if family.keep then return family end
		end
		return nil
	end
	local function KeepChoices()
		local values, family = {}, KeepFamily()
		local ticks = ns.db.profile.ownBuffs.elixirKeep
		for _, spell in ipairs(family and family.spells or {}) do
			if ns.OwnSpellKnown(spell) or (type(ticks) == "table" and ticks[spell.key] == true) then
				values[spell.key] = ns.BuffName(spell)
			end
		end
		return values
	end
	args.own_elixirkeep = {
		type = "multiselect",
		name = L["Elixirs to keep up"],
		desc = L["Tick the elixirs you want on you at once: Manners reminds you of each ticked one that is in your bags and not on you, one at a time. With none ticked, any one elixir on you will do, the best you can use first."],
		order = 15.797,
		hidden = function()
			local family = KeepFamily()
			return not family or ns.OwnPick(family) ~= "auto" or next(KeepChoices()) == nil
		end,
		disabled = function() return not S().self end,
		values = function() return KeepChoices() end,
		get = function(_, key)
			local ticks = ns.db.profile.ownBuffs.elixirKeep
			return type(ticks) == "table" and ticks[key] == true
		end,
		set = function(_, key, on)
			local own = ns.db.profile.ownBuffs
			if type(own.elixirKeep) ~= "table" then own.elixirKeep = {} end
			own.elixirKeep[key] = on and true or nil
			-- Two kept as one (db.char.elixirClash) part again with either tick:
			-- the way back from a pair wrongly taken for not stacking.
			ns.ForgetElixirClash(key)
			-- The prompt follows at once rather than at the next scan.
			ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
		end,
	}
end

local function AddOwnSpellControls(args)
	local OS = ns.OwnSpells
	args.ownBriefNote = {
		type = "description",
		fontSize = "medium",
		order = 15.2999,
		name = L["Mana Shield, Fire Ward and Frost Ward are reminded outside a fight only: from the pull until the fight ends Manners offers none of them, so in a fight you recast them yourself. Each lasts a minute or less."],
		hidden = function()
			for _, family in ipairs(ns.KnownOwnFamilies()) do
				if family.brief then return false end
			end
			return true
		end,
	}
	if not OS then return end
	args.ownSpellNote = {
		type = "description",
		fontSize = "medium",
		order = 15.85,
		name = L["A buff of yours Manners does not know: type its name as your spellbook shows it, or its spell id, and press Enter. It must be one this character knows, not passive and not cast on an enemy. Manners then reminds you of it as it does your other buffs, outside a fight, and in cities and inns only with Also in cities and inns. Up to ten, kept for this character."],
	}
	args.ownSpellAdd = {
		type = "input",
		name = L["Add a spell"],
		desc = L["Its name as your spellbook shows it, or its spell id. Press Enter to add it."],
		order = 15.851,
		width = "full",
		disabled = function() return InCombatLockdown() end,
		-- Always empty, as Never offer's box: the answer is the line under it.
		get = function() return "" end,
		set = function(_, value) OS.Add(value) end,
	}
	args.ownSpellSaid = {
		type = "description",
		fontSize = "medium",
		order = 15.852,
		name = function() return OS.Said() or "" end,
		hidden = function() return OS.Said() == nil end,
	}
	for i = 1, OS.MAX do
		args["ownSpell" .. i] = {
			type = "execute",
			order = 15.853 + i / 10000,
			width = "full",
			name = function()
				local row = OS.List()[i]
				return row and L["Remove %s"]:format(OS.Label(row)) or ""
			end,
			desc = L["Stop reminding you of it and take it off the list. You can add it again."],
			hidden = function() return OS.List()[i] == nil end,
			disabled = function() return InCombatLockdown() end,
			func = function() OS.Remove(i) end,
		}
	end
end

local function AddSelfControls(args)
	local entries = {
-------------------------------------------------- myself
			-- You, last, as the queue ranks you: behind favours and requests,
			-- ahead of your group. Its own heading, with everything about you
			-- under the one switch: your group buff, then only your class's
			-- own buffs you know (AddOwnControls), then where. Hidden, not
			-- disabled, like the passer-by switch: nothing on this page makes
			-- a shout go on you alone.
			myselfHeader = { type = "header", name = L["Myself"], order = 15, hidden = NothingForSelf },
			self = {
				type = "toggle",
				name = L["Remind me when my own buff is missing"],
				desc = function()
					-- A hunter gives nobody anything, so his are the ones
					-- below alone.
					if #ns.KnownOwnFamilies() > 0 and #ns.SelfBuffs() == 0 then
						return L["Offer your own buffs to you when one is not up: the ones below. They are cast on you, your target is handed back, and nothing is said."]
					elseif #ns.KnownOwnFamilies() > 0 then
						return L["Offer your own buffs to you too, when one is not up: the ones below, and the buff you give others. They are cast on you, your target is handed back, and nothing is said."]
					end
					return L["Offer your own buff to you too, when you are missing it or, with top-ups on, it is running low. It is cast on you, your target is handed back, and nothing is said."]
				end,
				order = 15.1,
				width = "full",
				hidden = NothingForSelf,
				get = sGet,
				set = sSet,
			},
			-- The families sit at 15.2x (AddOwnControls), and this under them.
			ownCities = {
				type = "toggle",
				name = L["Also in cities and inns"],
				desc = L["Off: your own buffs are not offered while you are in a city or an inn."],
				order = 15.9,
				width = "full",
				hidden = NothingForSelf,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.inCities == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.inCities = value
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			ownDungeons = {
				type = "toggle",
				name = L["Consumables only in dungeons and raids"],
				desc = L["On: the reminder for an oil or a stone for your weapon, for food, and for a flask, an elixir or a scroll comes up only in a dungeon or a raid, not out in the world. Poisons and fishing lures are not held back."],
				order = 15.95,
				width = "full",
				hidden = NothingForSelf,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.itemsInDungeons == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.itemsInDungeons = value
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- Food still comes up out in the world while the rest waits for a
			-- dungeon (GitHub issue 37). Greyed while the switch above is off.
			ownFoodOutside = {
				type = "toggle",
				name = L["Food still offered outside dungeons and raids"],
				desc = L["On: food for Well Fed still comes up out in the world, while weapon stones and oils, flasks, elixirs and scrolls keep waiting for a dungeon or a raid. Only matters while Consumables only in dungeons and raids is on."],
				order = 15.9502,
				width = "full",
				hidden = NothingForSelf,
				disabled = function() return not S().self or ns.db.profile.ownBuffs.itemsInDungeons ~= true end,
				get = function() return ns.db.profile.ownBuffs.foodOutside == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.foodOutside = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
					if ns.Supplies then ns.Guard("consumables button", ns.Supplies.Refresh, ns.Supplies) end
				end,
			},

			-- Your own consumables after everybody else (Queue.lua, PRIORITY.selfLast):
			-- asked for on CurseForge by a player who buffs others in a busy place
			-- and keeps the food and stones for later.
			ownItemsLast = {
				type = "toggle",
				name = L["My food, stones and oils after everybody else"],
				desc = L["On: your own food, weapon stones and oils, flasks, elixirs and scrolls wait until nobody else needs a buff from you. In a busy place you buff other people first and keep your own for later."],
				order = 15.9505,
				width = "full",
				hidden = NothingForSelf,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.itemsLast == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.itemsLast = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- Your own uses with a cast held while you move (Core.lua, CutByMoving), asked
			-- for on GitHub (issue 31): off, they stay on the prompt on the run.
			ownHoldMoving = {
				type = "toggle",
				name = L["Hold my food, stones and oils while I move"],
				desc = L["On: food, a weapon stone or oil, and anything else of your own that takes a cast leave the prompt while you move, and come back a moment after you stand still. Off: they stay on the prompt while you move, but the game may refuse a press on the run or cut it short, and food may be used up for nothing."],
				order = 15.9506,
				width = "full",
				hidden = NothingForSelf,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.holdMoving ~= false end,
				set = function(_, value)
					ns.db.profile.ownBuffs.holdMoving = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
					if ns.Supplies then ns.Guard("consumables button", ns.Supplies.Refresh, ns.Supplies) end
				end,
			},

			-- Which pet the journal brings out (Companion.lua): Forever, with the
			-- companion pet switched on.
			ownPetChoice = {
				type = "select",
				name = L["Which pet"],
				desc = L["The pet Manners brings out of your pet journal: the one you had out last, a random favourite, any pet, or one of your pets by name. With none out last, a favourite; with no favourites, any pet."],
				order = 15.951,
				width = "full",
				-- The three ways to choose, then every pet of the journal by name
				-- (Companion.lua, Pet.Choices), read as the page is drawn.
				values = function()
					return (ns.Pet.Choices({ last = L["The one I had out last"], favourite = L["A random favourite"],
						random = L["Any pet"] }, { "last", "favourite", "random" }))
				end,
				sorting = function()
					return select(2, ns.Pet.Choices({}, { "last", "favourite", "random" }))
				end,
				hidden = function()
					local family = ns.Pet and ns.Pet.Family()
					return not (family and family.journal and ns.OwnPick(family) ~= "off")
				end,
				disabled = function() return not S().self end,
				-- A pet chosen by name that the journal no longer lists reads as
				-- what Manners then does: the one out last.
				get = function()
					local choice = ns.db.profile.ownBuffs.petChoice
					if type(choice) == "string" and choice:match(ns.Pet.PICKED) then
						local listed = select(2, ns.Pet.Choices({}, {}))
						for _, key in ipairs(listed) do
							if key == choice then return choice end
						end
						return "last"
					end
					return choice
				end,
				set = function(_, value) ns.db.profile.ownBuffs.petChoice = value end,
			},

			-- Which food Well Fed reminds you to eat (Core.lua, FoodByChoice), asked
			-- for on CurseForge: the best, the weakest first, or one in the bags by
			-- name. Under Well Fed, while it is on.
			ownFoodChoice = {
				type = "select",
				name = L["Which food"],
				desc = L["Which food Manners reminds you to eat when you have several in your bags. The best one you can eat is what it did before. The weakest first uses up your cheaper food. Or pick one of the foods in your bags by name. A food you tick under Never remind me about is never picked."],
				order = 15.795,
				width = "full",
				values = function()
					local values = { best = L["The best one I can eat"], weakest = L["The weakest first"] }
					for _, family in ipairs(ns.KnownOwnFamilies()) do
						if family.food then
							for _, spell in ipairs(family.spells) do
								if ns.OwnSpellKnown(spell) then values[spell.key] = ns.BuffName(spell) end
							end
						end
					end
					return values
				end,
				sorting = function()
					local foods = {}
					for _, family in ipairs(ns.KnownOwnFamilies()) do
						if family.food then
							for _, spell in ipairs(family.spells) do
								if ns.OwnSpellKnown(spell) then foods[#foods + 1] = { spell.key, ns.BuffName(spell) or "" } end
							end
						end
					end
					table.sort(foods, function(a, b) return a[2] < b[2] end)
					local out = { "best", "weakest" }
					for _, food in ipairs(foods) do out[#out + 1] = food[1] end
					return out
				end,
				hidden = function()
					local family
					for _, f in ipairs(ns.KnownOwnFamilies()) do
						if f.food then family = f end
					end
					return not family or ns.OwnPick(family) == "off"
				end,
				disabled = function() return not S().self end,
				-- A food that is not in the bags now reads as the best: what Manners
				-- then does, until it is back.
				get = function()
					local order = ns.db.profile.ownBuffs.foodOrder
					if order == "best" or order == "weakest" then return order end
					for _, family in ipairs(ns.KnownOwnFamilies()) do
						if family.food then
							for _, spell in ipairs(family.spells) do
								if spell.key == order and ns.OwnSpellKnown(spell) then return order end
							end
						end
					end
					return "best"
				end,
				set = function(_, value)
					ns.db.profile.ownBuffs.foodOrder = value
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- Asked for on CurseForge: the consumables on a button of their own
			-- (Prompt/Supplies.lua), so the prompt can stay in plain sight and
			-- they out of the way.
			ownApart = {
				type = "toggle",
				name = L["Put consumables on a button of their own"],
				desc = L["Food, flasks, elixirs, scrolls and your weapon's oils, stones and poisons come up on a small button of their own instead of on the prompt. Unlock the prompt to drag it where you want it; its key is set just below, and a right-click skips that item for now. It is never shown in a fight."],
				order = 15.955,
				width = "full",
				hidden = NothingForSelf,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.apart == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.apart = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
					if ns.Supplies then ns.Guard("consumables button", ns.Supplies.Refresh, ns.Supplies) end
				end,
			},
			-- Its key, the game's binding as the prompt's is (Options/Start.lua,
			-- Setup), saved with the binding set; under the switch. Shown only
			-- while the button is on.
			ownApartKey = {
				type = "keybinding",
				name = L["Key for the consumables button"],
				desc = L["Saved with your game key bindings, so it works on every profile."],
				order = 15.956,
				hidden = function()
					return NothingForSelf() or ns.db.profile.ownBuffs.apart ~= true or not ns.Setup.CanBind()
				end,
				-- SetBinding is refused in a fight.
				disabled = function() return InCombatLockdown() end,
				get = function() return ns.Setup.Key(ns.Supplies.COMMAND) or "" end,
				set = function(_, value)
					ns.Setup.SetKey(value, ns.Supplies.COMMAND, function(key, was)
						return L["%s was bound to %s; it now uses the consumables button."]:format(key, was)
					end)
					if ns.Supplies then ns.Guard("consumables button", ns.Supplies.Refresh, ns.Supplies) end
				end,
			},

			-- A warrior's shout for himself when he is in no group, asked for on
			-- GitHub: it is never offered to you otherwise, so a warrior on his
			-- own was never reminded (Core.lua, CastsOnSelf).
			ownShout = {
				type = "toggle",
				name = L["Remind me of my shout when I'm alone"],
				desc = L["Off: a shout is only offered to your group. On: with nobody in your group, Battle Shout is offered to you too when it is missing or running low. In a group the group's own offer covers you."],
				order = 15.96,
				width = "full",
				hidden = function() return not ns.HasShout() end,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.shoutAlone == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.shoutAlone = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- Dampen Magic in a group cuts the healing you get: held to when you
			-- are alone unless this is off (Buffs.lua, `solo`; Core.lua,
			-- OwnVerdict). Asked for on GitHub. Shown to a mage who knows it.
			ownDampenAlone = {
				type = "toggle",
				name = L["Dampen Magic only when I'm alone"],
				desc = L["On: Dampen Magic is not offered while you are in a party or raid, where it would cut the healing you get."],
				order = 15.965,
				width = "full",
				hidden = function()
					local spell = ns.FindOwnSpell("dampenmagic")
					return not (spell and ns.OwnSpellKnown(spell))
				end,
				disabled = function()
					local family = ns.FindOwnFamily("magicmod")
					return not family or ns.OwnPick(family) == "off"
				end,
				get = function() return ns.db.profile.ownBuffs.dampenAlone ~= false end,
				set = function(_, value)
					ns.db.profile.ownBuffs.dampenAlone = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- Amplify Magic's own switch, the same as Dampen Magic's.
			ownAmplifyAlone = {
				type = "toggle",
				name = L["Amplify Magic only when I'm alone"],
				desc = L["On: Amplify Magic is not offered while you are in a party or raid."],
				order = 15.966,
				width = "full",
				hidden = function()
					local spell = ns.FindOwnSpell("amplifymagic")
					return not (spell and ns.OwnSpellKnown(spell))
				end,
				disabled = function()
					local family = ns.FindOwnFamily("magicmod")
					return not family or ns.OwnPick(family) == "off"
				end,
				get = function() return ns.db.profile.ownBuffs.amplifyAlone ~= false end,
				set = function(_, value)
					ns.db.profile.ownBuffs.amplifyAlone = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- A shaman's weapon imbues ahead of his shield (Core.lua,
			-- KnownOwnFamilies), asked for on CurseForge. Shown to a shaman who
			-- knows an imbue.
			ownImbueFirst = {
				type = "toggle",
				name = L["Weapon imbues before the shield"],
				desc = L["On: your weapon imbues come up ahead of your shield, so a shield you cannot cast for want of mana does not keep your imbue waiting behind it."],
				order = 15.967,
				width = "full",
				hidden = function()
					for _, family in ipairs(ns.KnownOwnFamilies()) do
						if family.imbue then return false end
					end
					return true
				end,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.imbueFirst == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.imbueFirst = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- The sleeping bag before Well-Rested has gone (Core.lua, OwnVerdict),
			-- asked for on CurseForge. Shown under Well-Rested while it is on.
			ownRestedEarly = {
				type = "toggle",
				name = L["Remind me before Well-Rested runs out"],
				desc = L["On: the sleeping bag comes up again when Well-Rested has five minutes left, so you can lie down in it and renew it before it runs out. Off: only once it has gone."],
				order = 15.968,
				width = "full",
				hidden = function()
					for _, family in ipairs(ns.KnownOwnFamilies()) do
						if family.rest then return ns.OwnPick(family) == "off" end
					end
					return true
				end,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.restedEarly == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.restedEarly = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- Food, flasks, elixirs and scrolls wait for the sleeping bag
			-- (Core.lua, ns.RestedComesFirst), asked for on CurseForge: their
			-- minutes are not spent lying in it. Shown under Well-Rested while
			-- it is on.
			ownRestedFirst = {
				type = "toggle",
				name = L["Sleeping bag before food and elixirs"],
				desc = L["On: while the sleeping bag is due, or you are lying in it, food, flasks, elixirs and scrolls wait, so none of them runs out while you rest. Off: they come up as usual."],
				order = 15.969,
				width = "full",
				hidden = function()
					for _, family in ipairs(ns.KnownOwnFamilies()) do
						if family.rest then return ns.OwnPick(family) == "off" end
					end
					return true
				end,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.restedFirst == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.restedFirst = value == true
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-- Every scroll at once (Buffs.lua, isScroll), asked for by a player
			-- who wanted them off this list: off, none is offered and their
			-- switches go (ns.ScrollsOff); each keeps its own pick for when it
			-- is on again. Shown as ScrollSwitchShown says.
			ownScrolls = {
				type = "toggle",
				name = L["Scrolls"],
				desc = L["Off: no scroll is ever offered to you, and the switches for scrolls leave this list. Turned back on, each scroll is as you left it."],
				order = 15.97,
				width = "full",
				hidden = function() return NothingForSelf() or not ScrollSwitchShown() end,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.scrolls ~= false end,
				set = function(_, value)
					ns.db.profile.ownBuffs.scrolls = value == true
					-- The bags are counted again for the scrolls switched on.
					if ns.ForgetScrolls then ns.ForgetScrolls() end
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

	}
	for key, value in pairs(entries) do args[key] = value end
end

api:RegisterOptionsExtension("who", function(_, args)
	AddOwnControls(args)
	AddSelfControls(args)
	AddOwnSpellControls(args)
end)
