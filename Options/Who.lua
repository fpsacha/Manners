-- Manners -- options: the Who to buff tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local restyleAndMacro, S, F, B = Page.restyleAndMacro, Page.S, Page.F, Page.B
local sGet, sSet, fGet, fSet = Page.sGet, Page.sSet, Page.fGet, Page.fSet
local bSet, prGet, prSet, HasClassBuffs = Page.bSet, Page.prGet, Page.prSet, Page.HasClassBuffs
local OnlyReachesGroup, HasPrompt, TAB = Page.OnlyReachesGroup, Page.HasPrompt, Page.TAB

local function BuffChoices()
	local values = { auto = L["Automatic (whatever they are missing)"] }
	for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		local label = (info and info.name) or buff.key
		if not (info and info.known) then label = L["%s |cff808080(not learned)|r"]:format(label) end
		values[buff.key] = label
	end
	return values
end

-- The named distances, read off the list Range.lua measures with, so the
-- dropdown cannot offer a setting nothing implements. Each with its rough
-- yardage, since what somebody picks is a feeling but they will want to know
-- roughly what they just asked for.
local function ProximityChoices()
	local values = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		values[tier.key] = tier.about and ("%s (%s)"):format(tier.name, tier.about) or tier.name
	end
	return values
end

-- AceConfig sorts a select's values by their labels unless it is given an
-- order, and a translation would scramble loosest-to-tightest.
local function ProximityOrder()
	local keys = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		keys[#keys + 1] = tier.key
	end
	return keys
end

-- The spell's name, with the one thing about it that changes who it is offered
-- to. "Mana users only" only while "Skip players it does nothing for" is
-- on, since that filter is what holds a mana-only spell back.
local function BuffLabel(buff)
	local label = ns.BuffName(buff)
	if buff.manaOnly and F().relevantOnly then
		label = L["%s |cff808080(mana users only)|r"]:format(label)
	end
	if buff.partyOnly or buff.groupOnly or buff.oneTarget then label = L["%s |cff808080(your group only)|r"]:format(label) end
	return label
end

-- What "Automatic" will actually do, for this character, as it is configured
-- right now: the list in the order it is walked, taken from the same function
-- the scan uses so the two cannot drift.
local function AutoExplanation()
	local castable = ns.CastableBuffs()
	if #castable == 0 then
		-- Each way to have nothing to offer gets its own answer, so nobody is
		-- sent looking at switches that are already on.
		if not HasClassBuffs() then
			return L["This character has nothing it can cast on another player."]
		end
		local anyKnown = false
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if ns.IsBuffKnown(buff) then anyKnown = true end
		end
		if not anyKnown then
			return "|cffff8080"
				.. L["You have not learned any of these yet, so nobody will be offered anything."]
				.. "|r"
		end
		-- The only thing learned is one Automatic never reaches for -- a Mists
		-- warlock with Unending Breath and no Dark Intent yet.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if buff.neverAuto and ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return "|cffff8080"
					.. L["Automatic never offers %s -- nobody standing in a city wants it -- so nobody will be offered anything."]
						:format(ns.BuffName(buff))
					.. "|r\n\n"
					.. L["Pick it in Buff to offer if you want it given out anyway."]
			end
		end
		-- Everything learned is switched off, but a spell not learned yet is
		-- still ticked, and learning it brings the prompt back. A neverAuto
		-- spell is left out: learning it would bring nothing back.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if not buff.neverAuto and not ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return "|cffff8080"
					.. L["Every spell you have learned is switched off, so nothing is offered until you switch one back on or learn one of the others."]
					.. "|r"
			end
		end
		return "|cffff8080" .. L["Every spell below is switched off, so the prompt will never appear."]
			.. "|r"
	end

	local names = {}
	for _, buff in ipairs(castable) do
		names[#names + 1] = "|cffffffff" .. BuffLabel(buff) .. "|r"
	end
	local list = table.concat(names, ", ")

	-- Blessings overwrite one another, so for these classes Automatic gives one
	-- and stops. "Left alone" rests on reading what they carry: "Always offer"
	-- chooses not to look and a client that hides a blessing's aura cannot, and
	-- either way the first blessing that suits them can replace one of yours
	-- (deliberately, see PickBuffFor).
	--
	-- Whole sentences rather than one with a clause bolted on, so that a
	-- translation can put the exception wherever its own grammar wants it.
	if ns.EXCLUSIVE_BUFFS[ns.caps.class] then
		-- A buff for one target at a time (a paladin's Beacon of Light) is
		-- not one of the blessings that replace one another: the line after
		-- this says who gets it.
		local blessings = {}
		for _, buff in ipairs(castable) do
			if not buff.oneTarget then blessings[#blessings + 1] = "|cffffffff" .. BuffLabel(buff) .. "|r" end
		end
		if #blessings > 0 then list = table.concat(blessings, ", ") end
		local hidden = false
		for _, buff in ipairs(castable) do
			local info = ns.BuffInfo(buff)
			if not (info and info.readable) then hidden = true end
		end
		if F().whenBuffed == "always" then
			return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. |cffffd100Always offer|r does not check what they carry, so it can replace one of yours."]
				:format(list)
		elseif hidden then
			return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. Where the game hides which blessing somebody carries, it can replace one of yours."]
				:format(list)
		end
		return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. Anybody already carrying one of yours is left alone."]
			:format(list)
	end

	local text = L["Automatic may offer, in this order: %s. Each person gets the first one they are missing."]
		:format(list)
	if ns.RotatesBuffs() then
		text = text .. "\n|cff888888"
			.. L["When the game hides what someone has, it tries the next one each time."]
			.. "|r"
	end
	return text
end

-- Who a buff for one target at a time goes to (Buffs.lua, oneTarget), one
-- line for each the walk holds, after what Automatic does: those sentences
-- speak of everybody, and this one goes to one person. Empty for none.
local function OneTargetNote(castable)
	local out = ""
	for _, buff in ipairs(castable) do
		if buff.oneTarget then
			local line = buff.notOwnClass
				and L["Only one person can have %s at a time, so it goes to one member of your group who is not of your class, and only while none of yours is on anybody in it."]
				or L["Only one person can have %s at a time, so it goes to a tank of your group (the tank role, or main tank in a raid), and only while none of yours is on anybody in it."]
			out = out .. "\n|cff888888" .. line:format("|cffffffff" .. ns.BuffName(buff) .. "|r") .. "|r"
		end
	end
	return out
end

-- What pinning one spell means, and the one case where pinning is a silent
-- switch-off: a pinned buff you have not learned is offered to nobody. The pin
-- is deliberately not reset for you (a failed spell probe must not rewrite a
-- setting), which is why it has to be said out loud here.
local function PinExplanation()
	local choice = B().choice
	local buff = ns.FindBuff(ns.caps.class, choice)
	local name = buff and ns.BuffName(buff) or tostring(choice)

	if buff and ns.IsBuffKnown(buff) then
		return L["Only |cffffffff%s|r is offered, to everybody, whatever else they are missing. The per-spell switches come back with Automatic."]
			:format(name)
	end

	return "|cffff8080"
		.. L["You picked %s in Buff to offer, but have not learned it, so nothing is offered."]:format(name)
		.. "|r\n\n"
		.. L["Learn it or set Buff to offer back to Automatic."]
end

-- One toggle per spell the class can put on somebody else, built once with the
-- page (only whether each is learned changes, and the label asks that live).
-- Switched on is the *absence* of a key, so an untouched profile stores nothing.
local function AddBuffToggles(args)
	local buffs = ns.GetClassBuffs(ns.caps.class) or {}
	-- One spell is not a choice. The walk has nothing to walk, and a lone
	-- toggle under "Automatic" reads as a second way to switch the addon off --
	-- unless it is one many do not want (Buffs.lua, switchable: Unending Breath).
	if #buffs < 2 and not (buffs[1] and buffs[1].switchable) then return end

	for index, buff in ipairs(buffs) do
		args["offer_" .. buff.key] = {
			type = "toggle",
			name = function()
				local label = BuffLabel(buff)
				if not ns.IsBuffKnown(buff) then
					label = L["%s |cff808080(not learned)|r"]:format(label)
				end
				return label
			end,
			desc = L["Untick to never offer this buff."],
			-- Sub-one steps so the whole block sits between the buff dropdown
			-- and "Skip players it does nothing for" (4.9) whatever the class
			-- has, and in the order the buff set lists them (which is the walk's,
			-- but for a paladin's Kings first: Automatic's note says that one).
			order = 4 + index / 10,
			width = "full",
			-- A pinned spell is the only one considered, so these would be
			-- switches over something that is not consulted. Only a pin of this
			-- class's counts: another class's is Automatic here.
			hidden = function() return ns.PinnedBuff() ~= nil end,
			disabled = function() return not ns.IsBuffKnown(buff) end,
			get = function() return not B().skip[buff.key] end,
			set = function(_, value)
				-- nil rather than false: AceDB stores the difference from the
				-- defaults, and an empty table is stored as nothing.
				B().skip[buff.key] = (not value) or nil
				restyleAndMacro()
			end,
		}
		-- A buff the player may hold to the tanks of their group (Buffs.lua,
		-- tankChoice: Thorns), under its own switch. Everybody is the absence of
		-- a key, as the switches are.
		if buff.tankChoice then
			args["tank_" .. buff.key] = {
				type = "select",
				name = function() return L["Offer %s to"]:format(ns.BuffName(buff) or buff.key) end,
				desc = L["In a group, Tanks only offers this buff only to players the game gives the tank role, or marks as main tank in a raid, so the rest of a dungeon or raid is left alone. A player with no role is not a tank. People outside your group, and anybody who asks you for it in chat, are offered it as usual."]
					.. "\n\n" .. L["Only me offers it to nobody else, and still reminds you when yours is down (Myself must be on)."],
				order = 4 + index / 10 + 0.05,
				width = "full",
				values = function() return { all = L["Everyone"], tanks = L["Tanks only"], me = L["Only me"] } end,
				sorting = { "all", "tanks", "me" },
				hidden = function() return ns.PinnedBuff() ~= nil and ns.PinnedBuff().key ~= buff.key end,
				disabled = function() return not ns.IsBuffKnown(buff) or B().skip[buff.key] == true end,
				get = function()
					if B().meOnly[buff.key] then return "me" end
					return B().tanksOnly[buff.key] and "tanks" or "all"
				end,
				set = function(_, value)
					-- One of the three: nil rather than false, as the switches are.
					B().tanksOnly[buff.key] = (value == "tanks") or nil
					B().meOnly[buff.key] = (value == "me") or nil
					restyleAndMacro()
				end,
			}
		end
	end
end

-- Whether nothing this character can offer goes on themselves -- a warrior,
-- whose shout already covers him and who has no buff of his own -- which
-- leaves "Myself" with nothing behind it. Follows the per-spell switches, as
-- the scan does (ns.SelfBuffs), and counts every family of the class's own
-- buffs you know, switched off or not: their switches live under it.
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
	elseif family.key == "elixir" and family.covers then
		return L["Reminds you to drink an elixir when no elixir or flask is on you and an elixir is in your bags, the best you can use first. A flask fills both elixir slots. Off until you turn it on."]
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
						return L["Automatic reminds you only while your group role is tank; Always reminds you whenever it is not up."]
					end
					if family.enhance then
						return L["Reminds you when nothing is on the weapon in your %s and one of these in your bags fits it. Automatic takes the one you used last, else the best you can use."]
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
					if family.imbue then
						return L["Reminds you when nothing is on the weapon in your main hand and a scroll in your bags fits it. Automatic takes the one you used last, else the best you can use."]
					elseif family.scroll then
						return L["Reminds you when no familiar is with you and a scroll for one is in your bags. Automatic takes the one you used last, else the best your level allows."]
					end
					local text = L["Reminds you when none of these is up. Automatic takes the one you had up last."]
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
					or family.rest
					and L["Reminds you to lay down your Cozy Sleeping Bag when Well-Rested is not on you and the bag is in your bags. Not at the level cap, where there is no experience to gain. Off until you turn it on."]
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
	local function LeaveChoices()
		local values = {}
		for _, family in ipairs(ns.KnownOwnFamilies()) do
			if ns.OwnLeaveable(family) then
				for _, spell in ipairs(family.spells) do
					if ns.OwnSpellKnown(spell) then values[spell.key] = ns.BuffName(spell) end
				end
			end
		end
		return values
	end
	args.own_leave = {
		type = "multiselect",
		name = L["Never remind me about"],
		desc = L["Ticked spells are left out of Automatic and never offered, even one you picked above. The others of their kind still are."],
		order = 15.8,
		hidden = function() return next(LeaveChoices()) == nil end,
		disabled = function() return not S().self end,
		values = LeaveChoices,
		get = function(_, key) return ns.db.profile.ownBuffs.leave[key] == true end,
		set = function(_, key, on)
			ns.db.profile.ownBuffs.leave[key] = on and true or false
			-- The prompt follows at once rather than at the next scan.
			ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
		end,
	}
end

-- Everything on Who to buff but "Myself", hidden from a class with nothing
-- for anybody else (a hunter, a shaman): their tab is their own buffs alone.
-- Each control keeps its own rule on top.
local function ForOthersOnly(args)
	for key, arg in pairs(args) do
		-- Consumables only in dungeons and raids is about your own buffs too:
		-- a hunter's or a shaman's food and flasks.
		if not (key == "myselfHeader" or key == "self" or key == "ownCities" or key == "ownDungeons"
			or key == "ownScrolls" or key == "ownShout" or key:find("^own_")) then
			local was = arg.hidden
			arg.hidden = function(...)
				if not HasClassBuffs() then return true end
				if type(was) == "function" then return was(...) end
				return was
			end
		end
	end
end

-- Who is picked in the never-offer dropdown, waiting for Remove from list; a
-- state of the window, like Page.reportOpen.
local neverPicked

-- The never-offer list as dropdown choices, built fresh each time, because a
-- shift-right-click or /manners never can add to it while the page is open.
local function NeverChoices()
	local values = {}
	for _, name in ipairs(ns.NeverList()) do values[name] = name end
	return values
end

-- The eight raid groups as checkbox labels, keyed by group number, which is
-- what the profile stores.
local function RaidGroupChoices()
	local values = {}
	for group = 1, 8 do values[group] = L["Group %d"]:format(group) end
	return values
end

-- The classes this client has, for "Classes I buff as passers-by": the nine of
-- the old world, Death Knights and Monks from Mists, Demon Hunters and Evokers
-- on retail. By class token, in the player's own words.
local CLASSES_BY_FLAVOUR = {
	classic = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
	mists = { "DEATHKNIGHT", "MONK" },
	mainline = { "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" },
}
local function ClassChoices()
	local values = {}
	local flavour = ns.Flavour and ns.Flavour.flavour
	for _, class in ipairs(CLASSES_BY_FLAVOUR.classic) do values[class] = ns.ClassName(class) end
	for _, class in ipairs(CLASSES_BY_FLAVOUR[flavour] or {}) do values[class] = ns.ClassName(class) end
	return values
end

-- A passer-by is seen mostly through a nameplate token, and with the game's
-- friendly nameplates off almost nobody outside your group has one, so the
-- note and the button under the passers-by switch say so (they hold only
-- while it is so, and What I say has the same pair for spoken lines). Away
-- with passers-by off or meaningless for this class, and unless the client
-- plainly says the nameplates are off (Speech.lua).
local function PlatesHidden()
	return not S().strangers or OnlyReachesGroup() or not ns.FriendlyPlatesOff()
end

-- The same answer for the pages that call the player to it: Who to buff's red
-- dot (Shared.lua, Page.Warn) and Start here's note and button under step 1.
function Page.PlatesWanted()
	return not PlatesHidden()
end

-- The buff order (Core.lua, ns.WalkBuffs): a list of the class's buffs in the
-- order they are tried, each one moved up or down a place, and the way back to
-- Automatic. For a class with a choice to make -- two buffs or more on this
-- client -- and not while one spell is pinned, which is all that is considered
-- then (as the Kings switch's rule is).
local function OrderHidden()
	return ns.PinnedBuff() ~= nil or #(ns.GetClassBuffs(ns.caps.class) or {}) < 2
end

-- Who is picked in the list, for the buttons that move one: a state of the
-- window, like the never-offer list's.
local orderPicked

-- The class's buffs as the walk tries them: their keys, and a key's place (0
-- for none).
local function OrderKeys()
	local keys = {}
	for _, buff in ipairs(ns.BuffWalkOrder()) do
		keys[#keys + 1] = buff.key
	end
	return keys
end

local function OrderRank(key)
	for rank, k in ipairs(OrderKeys()) do
		if k == key then return rank end
	end
	return 0
end

-- The name as the switches above show it: the spell, what narrows who it goes
-- to, and that it is not learned.
local function OrderLabel(buff)
	local label = BuffLabel(buff)
	if not ns.IsBuffKnown(buff) then label = L["%s |cff808080(not learned)|r"]:format(label) end
	return label
end

local function OrderChoices()
	local values = {}
	for _, buff in ipairs(ns.BuffWalkOrder()) do
		values[buff.key] = OrderLabel(buff)
	end
	return values
end

-- The one picked, or the first when nothing is (or what was picked is gone).
local function OrderPick()
	if orderPicked and OrderRank(orderPicked) > 0 then return orderPicked end
	return OrderKeys()[1]
end

-- What the list is: how the walk goes about it, then whose order it is. Two
-- sentences for the two kinds of class, since a blessing and a Fortitude do not
-- cover somebody alike.
local function OrderNote()
	local text = ns.EXCLUSIVE_BUFFS[ns.caps.class]
		and L["Manners offers each person the first of these they can use, and leaves alone anybody who already wears one of yours."]
		or L["Manners offers each person the first of these they are missing."]
	local state
	if ns.HasBuffOrder() then
		state = L["Your own order is in use."]
	else
		local first = B().kingsFirst == true and ns.StrongestBuff()
		state = first and L["Following Automatic's order, with %s first."]:format(ns.BuffName(first))
			or L["Following Automatic's order."]
	end
	return text .. "\n|cffe6c45e" .. state .. "|r"
end

-- One step of the picked buff; the picked one stays picked, so a buff goes up
-- three places in three presses.
local function MoveOrder(step)
	local key = OrderPick()
	if key and ns.MoveBuff(key, step) then
		orderPicked = key
		restyleAndMacro()
		ns.RefreshOptionsDisplay()
	end
end

-- Four questions, top to bottom: what to cast, who it goes to (with the group
-- and raid settings under their own heading), who comes first, and who is
-- skipped or never offered.
function Page.BuildWhoTab()
	-- The dropdown in the order the per-spell switches are drawn, Automatic
	-- first: AceConfig would otherwise sort it by the translated names.
	local function BuffOrder()
		local keys = { "auto" }
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			keys[#keys + 1] = buff.key
		end
		return keys
	end

	-- A class with one spell to give has nothing to choose between, the rule
	-- AddBuffToggles already follows. Except where Automatic never reaches for
	-- that one spell: the dropdown is then the only way to offer it at all.
	local function OneBuff()
		local buffs = ns.GetClassBuffs(ns.caps.class) or {}
		return #buffs == 1 and not buffs[1].neverAuto
	end

	-- The class's own spells that "Skip players it does nothing for" holds
	-- back, by name, so the tooltip names what the switch acts on here.
	local function ManaOnlyNames()
		local names = {}
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if buff.manaOnly then names[#names + 1] = ns.BuffName(buff) end
		end
		return names
	end

	-- The mana switch's label names the spells it holds back, so it reads as
	-- what it does here ("Only give Arcane Intellect to players with mana").
	-- On ns for the chat line that names the switch (Favours.lua).
	local function RelevantLabel()
		local names = ManaOnlyNames()
		if #names == 0 then return L["Only give mana buffs to players with mana"] end
		return L["Only give %s to players with mana"]:format(table.concat(names, ", "))
	end
	ns.RelevantOnlyLabel = RelevantLabel

	local function NoGroupBuffs()
		return not (ns.ClassHasGroupBuffs and ns.ClassHasGroupBuffs())
	end

	-- One line per reagent the group spells this character would cast eat, as
	-- the bags hold it now: a group buff that is never offered is most often a
	-- bag with no candles in it, and nothing else on the page says so.
	local function ReagentLines()
		local lines, seen = {}, {}
		for _, buff in ipairs(ns.CastableBuffs()) do
			local info = ns.BuffInfo(buff)
			local item = info and info.groupReagent
			if item and not seen[item] then
				seen[item] = true
				local name = (ns.ReagentName and ns.ReagentName(item)) or tostring(item)
				local count = ns.ReagentCount and ns.ReagentCount(item)
				if count == nil then
					lines[#lines + 1] = "|cff888888"
						.. L["%s: the game does not say how many you carry."]:format(name) .. "|r"
				elseif count > 0 then
					lines[#lines + 1] = L["%s: %d in your bags"]:format(name, count)
				elseif ns.ReagentWaived and ns.ReagentWaived(info, count) then
					-- Forever's Reagent Economy (GroupBuffs.lua).
					lines[#lines + 1] = L["%s: none needed -- the game lets you cast without it."]:format(name)
				else
					lines[#lines + 1] = "|cffff8080"
						.. L["%s: none in your bags, so group buffs are not offered."]:format(name)
						.. "|r"
				end
			end
		end
		if #lines == 0 then
			return "|cff888888" .. L["You have not learned a group version of your buffs yet."] .. "|r"
		end
		return table.concat(lines, "\n")
	end

	local who = {
		type = "group",
		name = TAB.who,
		order = 2,
		-- A hunter has "Myself" here and nothing else (ForOthersOnly); so
		-- does a class whose only prompt waits on a switch here (a retail
		-- death knight's flask), or that switch could never be reached.
		hidden = function() return not HasPrompt() and not Page.OwnSwitchWaiting() end,
		args = {
			-- Who the prompt is on right now, over this page and Who to skip.
			rightNow = Page.RightNowNote(0.5),
			rightNowSkip = Page.RightNowNote(39.5, true),

			-------------------------------------------------- what to cast
			buffsHeader = { type = "header", name = L["What to cast"], order = 1 },
			choice = {
				type = "select",
				name = L["Buff to offer"],
				order = 2,
				values = BuffChoices,
				sorting = BuffOrder,
				-- Shown again for a pin, so there is a way back to Automatic.
				hidden = function() return OneBuff() and ns.PinnedBuff() == nil end,
				-- What the walk is honouring, rather than what is stored. The
				-- profile is shared, so a pin can be another class's, and read
				-- raw the dropdown was blank over a walk that was Automatic.
				get = function()
					local pin = ns.PinnedBuff()
					return pin and pin.key or "auto"
				end,
				set = bSet,
			},
			autoNote = {
				type = "description",
				order = 3,
				hidden = function() return ns.PinnedBuff() ~= nil end,
				-- One spell and it is castable: just which one. Anything else
				-- (not learned, switched off) keeps Automatic's warning.
				name = function()
					local castable = ns.CastableBuffs()
					if OneBuff() and #castable == 1 then
						return "|cff888888" .. L["You offer %s."]:format("|cffffffff" .. BuffLabel(castable[1]) .. "|r") .. "|r"
							.. OneTargetNote(castable)
					end
					return AutoExplanation() .. OneTargetNote(castable)
				end,
			},
			-- After the per-spell switches (4.1, 4.2, ...) and ahead of the mana
			-- switch: all of them decide what is cast. Only for a class whose list
			-- has a strongest buff to put first (a paladin's Kings on Classic Era,
			-- Burning Crusade and Forever), and not while one spell is pinned, which
			-- is all that is considered then, nor once the player has put the buffs
			-- in an order of their own (Buff order below): that is what it means then.
			kingsFirst = {
				type = "toggle",
				name = function()
					local buff = ns.StrongestBuff()
					return buff and L["%s first"]:format(ns.BuffName(buff)) or ""
				end,
				desc = function()
					local buff = ns.StrongestBuff()
					return buff and L["Offer %s to everybody before any other blessing. Somebody who already carries it from another paladin, or who cannot be given it, gets the blessing Automatic would have chosen instead; anybody carrying one of yours is left alone."]
						:format(ns.BuffName(buff)) or ""
				end,
				order = 4.8,
				width = "full",
				hidden = function() return ns.PinnedBuff() ~= nil or ns.StrongestBuff() == nil or ns.HasBuffOrder() end,
				get = function() return B().kingsFirst == true end,
				set = bSet,
			},
			-- For a class whose buffs overwrite one another (a paladin's
			-- blessings): leave alone whoever another paladin has blessed. Asked
			-- for on CurseForge, by a player whose group shares out the blessings.
			leaveBlessed = {
				type = "toggle",
				name = L["Skip players another paladin has blessed"],
				desc = L["On: somebody who already carries any blessing from another paladin is not offered one of yours, even one they lack. Somebody who asks you for a blessing by name is still offered it."],
				order = 4.85,
				width = "full",
				hidden = function() return not ns.EXCLUSIVE_BUFFS[ns.caps.class] end,
				get = function() return B().leaveBlessed == true end,
				set = bSet,
			},
			-- A melee blessing (Buffs.lua, meleeOnly) is no use to the three
			-- classes that never fight in melee. Asked for on CurseForge.
			skipCasters = {
				type = "toggle",
				name = function()
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						if buff.meleeOnly then
							return L["Don't offer %s to mages, warlocks and priests"]:format(ns.BuffName(buff))
						end
					end
					return ""
				end,
				desc = L["On: they are never offered it, however the blessing would be chosen, since it does nothing for them. Their other blessings are still offered and refreshed. Somebody who asks you for it by name is still given it."],
				order = 4.86,
				width = "full",
				hidden = function()
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						if buff.meleeOnly then return false end
					end
					return true
				end,
				get = function() return B().skipCasters == true end,
				set = bSet,
			},
			-- The per-spell switches (AddBuffToggles) sit at 4.1, 4.2, ... and
			-- this one after them: all three decide what is cast. Only for a
			-- class with a mana-only spell, which is all it holds back.
			relevantOnly = {
				type = "toggle",
				name = RelevantLabel,
				desc = function()
					local names = ManaOnlyNames()
					if #names == 1 then
						return L["%s is not offered to players without mana, such as warriors and rogues."]:format(names[1])
					end
					return L["%s are not offered to players without mana, such as warriors and rogues."]
						:format(table.concat(names, ", "))
				end,
				order = 4.9,
				width = "full",
				hidden = function() return #ManaOnlyNames() == 0 end,
				get = fGet,
				set = fSet,
			},
			-- Below the per-spell switches, because when it is red the thing it
			-- is about is the dropdown at the top rather than the switches.
			pinNote = {
				type = "description",
				order = 5,
				fontSize = "medium",
				hidden = function() return ns.PinnedBuff() == nil end,
				name = function() return PinExplanation() end,
			},

			-------------------------------------------------- buff order
			-- A list of the class's buffs in the order they are tried, each with
			-- an arrow up and one down (the window draws these five as one piece,
			-- Window/WidgetsOrder.lua; the old dialog gets a dropdown and buttons).
			orderHeader = { type = "header", name = L["Buff order"], order = 6, hidden = OrderHidden },
			orderNote = {
				type = "description",
				order = 6.1,
				hidden = OrderHidden,
				name = OrderNote,
			},
			orderPick = {
				type = "select",
				name = L["Buff order"],
				order = 6.2,
				values = OrderChoices,
				sorting = OrderKeys,
				hidden = OrderHidden,
				get = OrderPick,
				set = function(_, value) orderPicked = value end,
			},
			orderUp = {
				type = "execute",
				name = L["Move up"],
				order = 6.3,
				hidden = OrderHidden,
				disabled = function() return OrderRank(OrderPick()) <= 1 end,
				func = function() MoveOrder(-1) end,
			},
			orderDown = {
				type = "execute",
				name = L["Move down"],
				order = 6.4,
				hidden = OrderHidden,
				disabled = function()
					local rank = OrderRank(OrderPick())
					return rank == 0 or rank >= #OrderKeys()
				end,
				func = function() MoveOrder(1) end,
			},
			-- Only once something has been moved: Automatic needs no way back.
			orderReset = {
				type = "execute",
				name = L["Back to Automatic"],
				order = 6.5,
				hidden = function() return OrderHidden() or not ns.HasBuffOrder() end,
				func = function()
					if ns.ClearBuffOrder() then
						restyleAndMacro()
						ns.RefreshOptionsDisplay()
					end
				end,
			},

			-------------------------------------------------- who it goes to
			sourcesHeader = { type = "header", name = L["Offer my buff to"], order = 10 },
			-- Every source off, and the only symptom is a prompt that never
			-- appears -- which is what a broken addon looks like.
			emptyWarning = {
				type = "description",
				order = 10.5,
				-- The same answer the page's red dot reads (Shared.lua).
				hidden = function() return not Page.NoSources() end,
				name = "|cffff8080"
					.. L["Nothing is ticked here, so the prompt will never appear."] .. "|r",
			},
			owed = {
				type = "toggle",
				name = L["People who buff me"],
				-- A function: a warrior's shout reaches only his group (his own
				-- subgroup in a raid on the older flavours), so a stranger who
				-- buffed him is turned down until they join.
				desc = function()
					if OnlyReachesGroup() then
						if ns.GroupMeansSubgroup() then
							return L["Offer a buff back to anyone who buffs you. Yours reaches only your own party (in a raid, your subgroup), so someone outside it is offered once they join."]
						end
						return L["Offer a buff back to anyone who buffs you. Yours reaches only your group, so someone outside it is offered once they join."]
					end
					return L["Offer a buff back to anyone who buffs you, in your group or not."]
				end,
				order = 11,
				width = "full",
				get = sGet,
				set = sSet,
			},
			group = {
				type = "toggle",
				name = L["My party and raid"],
				order = 12,
				width = "full",
				get = sGet,
				set = sSet,
			},
			strangers = {
				type = "toggle",
				name = L["Passers-by (players near me, not in my group)"],
				-- IterateUnits asks target, mouseover and focus before it
				-- touches a single nameplate.
				desc = L["Seen through nameplates, your target, focus and mouseover."],
				order = 13,
				width = "full",
				-- Hidden, not disabled: nothing on this page could ever make a
				-- shout reach a stranger.
				hidden = OnlyReachesGroup,
				get = sGet,
				set = sSet,
			},
			strangersPlatesNote = {
				type = "description",
				order = 13.05,
				hidden = PlatesHidden,
				-- Red, under the page's red dot: passers-by are switched on and
				-- Manners can hardly find any.
				name = "|cffff8080"
					.. L["Turn on friendly nameplates so Manners can see passers-by: without them it sees almost nobody outside your group."]
					.. "|r",
			},
			strangersShowPlates = {
				type = "execute",
				name = L["Show friendly nameplates"],
				desc = L["The game's own setting, under Nameplates in its options, where you can turn it off again."],
				order = 13.06,
				hidden = PlatesHidden,
				-- The client refuses the setting in a fight.
				disabled = function() return InCombatLockdown() end,
				func = function()
					if ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end
				end,
			},
			strangersNote = {
				type = "description",
				order = 13.1,
				hidden = function() return not OnlyReachesGroup() end,
				-- A shout is cast on yourself; Earth Shield, Beacon of Light or
				-- Symbiosis goes to a member of your group, never on yourself.
				name = function()
					for _, buff in ipairs(ns.CastableBuffs()) do
						if not buff.selfCast then
							return "|cff888888"
								.. L["What you can offer goes only to members of your group, so there is nothing for passers-by."]
								.. "|r"
						end
					end
					return "|cff888888"
						.. L["Everything you can offer is cast on yourself and reaches only your party, so there is nothing for passers-by."]
						.. "|r"
				end,
			},
			-- The two passer-by settings, right under the switch they narrow
			-- and greyed while it is off. Which signal is measuring, and how
			-- well, is on Diagnostics.
			proximity = {
				type = "select",
				name = L["Passers-by within"],
				desc = L["Only passers-by are measured, and only roughly: the game gives no exact distance."],
				order = 13.2,
				width = "full",
				values = ProximityChoices,
				sorting = ProximityOrder,
				hidden = OnlyReachesGroup,
				disabled = function() return not S().strangers end,
				get = fGet,
				set = fSet,
			},
			restingOnly = {
				type = "toggle",
				name = L["Only in cities and inns"],
				desc = L["Out in the world, passers-by are left alone; your group and people who buff you are offered anywhere."],
				order = 13.3,
				width = "full",
				hidden = OnlyReachesGroup,
				-- And while nothing at all is offered in cities and inns (When
				-- to offer), which leaves this switch nothing to narrow.
				disabled = function() return not S().strangers or F().quietInTowns == true end,
				get = fGet,
				set = fSet,
			},
			quietInTowns = {
				type = "toggle",
				name = L["Offer nothing in cities and inns"],
				-- Drawn on When to offer, so the other switch's page is named.
				desc = L["On: nothing is offered to anybody while the game calls you resting, in a city or an inn: not passers-by, not your group, not a favour you owe. Somebody you target or focus is still offered. Your own buffs have their own switch, under %s on %s."]
					:format(L["Myself"], TAB.who),
				order = 13.35,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- The same rule inside an instance: a player asked on CurseForge for
			-- no offers in a dungeon, where the group sorts out its own buffs.
			quietInInstances = {
				type = "toggle",
				name = L["Offer nothing in dungeons, raids and battlegrounds"],
				desc = L["On: inside a dungeon, a raid, a battleground or an arena, nothing is offered to anybody: not your group, not a favour you owe. Somebody you target or focus is still offered, and your own buffs are not held back."],
				order = 13.36,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- Both place rules leave the target and focus alone; this takes
			-- them in (a player asked on GitHub for no offers at all in a
			-- city).
			quietTargets = {
				type = "toggle",
				name = L["Hold back my target and focus too"],
				desc = L["On: the two switches above leave nobody out, not even somebody you target or focus. Off: they are still offered there."],
				order = 13.37,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- The source that reads chat. The full rule for what counts as
			-- asking lives in Requests.lua, which is the rule in code.
			asked = {
				type = "toggle",
				name = L["People who ask me in chat"],
				desc = L["For a minute, offer your buff to someone who asks for it (\"fort pls\"); off by default because chat is guesswork."],
				order = 14,
				width = "full",
				get = sGet,
				set = sSet,
			},
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
				name = L["Myself, when I'm missing my own buff"],
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
				desc = L["Off: nothing is offered to you while the game calls you resting, in a city or an inn."],
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

			-------------------------------------------------- group and raid
			-- Group buffs (GroupBuffs.lua) only ever replace offers to your
			-- party, so they follow My party and raid. Shown to the classes that
			-- have a group version at all, learned yet or not.
			groupHeader = { type = "header", name = L["My group and raid"], order = 20 },
			groupBuffsUse = {
				type = "toggle",
				name = L["Use group buffs"],
				-- Worded for this class and the group spells it has learned.
				desc = function() return (ns.GroupBuffDescriptions()) end,
				order = 21,
				width = "full",
				hidden = NoGroupBuffs,
				disabled = function() return not S().group end,
				get = function() return ns.db.profile.groupBuffs.use end,
				-- The next scan (a fraction of a second) folds or unfolds the
				-- party, and the macro follows it.
				set = function(_, v) ns.db.profile.groupBuffs.use = v end,
			},
			groupBuffsAtLeast = {
				type = "range",
				name = L["When this many need it"],
				desc = function() return select(2, ns.GroupBuffDescriptions()) end,
				order = 22,
				min = 2,
				max = 5,
				step = 1,
				hidden = NoGroupBuffs,
				disabled = function() return not (S().group and ns.db.profile.groupBuffs.use) end,
				get = function() return ns.db.profile.groupBuffs.atLeast end,
				set = function(_, v) ns.db.profile.groupBuffs.atLeast = math.floor(v) end,
			},
			reagentNote = {
				type = "description",
				order = 22.5,
				hidden = function()
					return NoGroupBuffs() or not (S().group and ns.db.profile.groupBuffs.use)
				end,
				-- Guarded: a `name` is read by AceConfig with nothing around
				-- it, and an item API that throws must not take the page down.
				name = function()
					local ok, text = pcall(ReagentLines)
					return ok and text or ""
				end,
			},
			skipRaidGroups = {
				type = "multiselect",
				name = L["Raid groups I buff"],
				-- Somebody told "groups 1 to 4" should be able to untick the
				-- rest and forget about it.
				desc = L["In a raid, only these groups are offered your buff; people who buff you or ask are offered anyway."],
				order = 23,
				values = RaidGroupChoices,
				disabled = function() return not S().group end,
				-- Stored as the groups switched off, so a new profile buffs all
				-- eight and the box shows them ticked.
				get = function(_, group) return F().skipRaidGroups[group] ~= true end,
				set = function(_, group, on)
					F().skipRaidGroups[group] = (not on) or nil
				end,
			},

			-------------------------------------------------- who comes first
			-- Not a source: everybody here is already on the list by one of the
			-- sources above. This decides who reaches the top of it.
			firstHeader = { type = "header", name = L["Who comes first"], order = 30 },
			target = {
				type = "toggle",
				name = L["My target first"],
				-- Always offer (When to offer) reads nobody's buffs, so there is
				-- never a reading to promote a target on. The switch greys out
				-- then, and says why only while it is grey.
				desc = function()
					local text = L["Your target goes ahead of everyone when the game can see they lack the buff."]
					if F().whenBuffed == "always" then
						text = text .. "\n\n"
							.. L["Greyed out while |cffffd100Always offer|r is chosen on %s: nothing is read then."]:format(TAB.when)
					end
					return text
				end,
				order = 31,
				width = "full",
				disabled = function() return F().whenBuffed == "always" end,
				get = prGet,
				set = prSet,
			},
			friends = {
				type = "toggle",
				name = L["Friends and guildmates first"],
				-- Inside a kind of offer and never across one, which is what the
				-- sort does; see BuildQueue.
				desc = L["Only changes the order; nobody is added or left out."],
				order = 32,
				width = "full",
				get = prGet,
				set = prSet,
			},
			readyCheck = {
				type = "toggle",
				name = L["My group first at a ready check"],
				desc = L["From a ready check until the pull, group members missing your buff go first."],
				order = 33,
				width = "full",
				get = prGet,
				set = prSet,
			},
			revived = {
				type = "toggle",
				name = L["Group members just revived first"],
				desc = L["For two minutes after someone is brought back, they go first if they lack your buff."],
				order = 34,
				width = "full",
				get = prGet,
				set = prSet,
			},

			-------------------------------------------------- who to skip
			skipHeader = { type = "header", name = L["Who to skip"], order = 40 },
			minLevel = {
				type = "range",
				name = L["Skip players below level"],
				desc = L["Someone known only by name is offered anyway."],
				order = 41,
				min = 1,
				-- This client's level cap, as the repair has it (Core.lua):
				-- 70 on Burning Crusade, 90 on Mists and retail. A number
				-- when the tab is built, which AceConfig requires.
				max = ns.MaxPlayerLevel(),
				step = 1,
				get = fGet,
				set = fSet,
			},
			-- What the slider's 1 means, under it while it is there.
			minLevelNote = {
				type = "description",
				order = 41.5,
				hidden = function() return (tonumber(F().minLevel) or 1) > 1 end,
				name = "|cff888888" .. L["1: nobody is skipped for their level."] .. "|r",
			},
			requireInRange = {
				-- The label is the promise: only a known out-of-range is hidden.
				type = "toggle",
				name = L["Skip players out of range"],
				desc = L["If the game cannot tell the range they are still offered."],
				order = 42,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- For everybody, a favour owed included: see "flagged for PvP" in
			-- Queue.lua. The exception, and the countdown that is no
			-- exception, are what a player would ask about, so they are in
			-- the tooltip.
			skipPvP = {
				type = "toggle",
				name = L["Skip players flagged for PvP"],
				desc = L["Buffing somebody flagged for PvP flags you too. Ignored while you are flagged yourself, as in a battleground, but not while your own flag is running out."],
				order = 43,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- Asked for by a player: see SelfServed in Queue.lua.
			skipSameClass = {
				type = "toggle",
				name = L["Skip my own class when they can cast it too"],
				desc = L["Somebody of your class can give themselves your buff, so they are left out -- unless they are too low a level for the rank you cast, and then they still get yours. People who buffed you, asked or you targeted are always offered."],
				order = 43.5,
				width = "full",
				get = fGet,
				set = fSet,
			},

			-- Asked for on CurseForge: leave a guild out of the list. A box, one
			-- name a line; your own guild's name works too.
			skipGuilds = {
				type = "input",
				name = L["Leave out these guilds (one per line)"],
				desc = L["People in these guilds are not offered anything, in your group or as passers-by. Type a guild's name as it shows under a player, with or without the < >. Somebody who buffed you or asked, and your target and focus, are still offered. |cffffd100Show their guild under the name|r (%s) shows whose guild it is."]:format(TAB.appearance),
				order = 43.6,
				multiline = 4,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- Asked for on CurseForge: some classes left out as passers-by.
			-- Stored as the classes switched off, so a new profile offers all
			-- of them and the boxes show them ticked.
			skipNearbyClasses = {
				type = "multiselect",
				name = L["Classes I buff as passers-by"],
				desc = L["Passers-by of a class you untick are not offered your buff. Your group, people who buff you or ask, and your target and focus are offered anyway."],
				order = 43.7,
				values = ClassChoices,
				disabled = function() return not S().strangers end,
				get = function(_, class) return F().skipNearbyClasses[class] ~= true end,
				set = function(_, class, on)
					F().skipNearbyClasses[class] = (not on) or nil
				end,
			},

			-------------------------------------------------- never offer
			neverHeader = { type = "header", name = L["Never offer"], order = 50 },
			neverNote = {
				type = "description",
				order = 51,
				fontSize = "medium",
				name = function()
					local count = #ns.NeverList()
					if count == 0 then
						return L["Nobody is on the list. Shift-right-click the prompt to add the person it shows, or type a name below."]
					end
					-- The favour exception (STATUS.md) is said every time the list
					-- is, rather than in a tooltip nobody hovers.
					local text = count == 1
						and L["One person is on the list. They are never offered anything as a passer-by or as a member of your group."]
						or L["%d people are on the list. They are never offered anything as passers-by or as members of your group."]:format(count)
					return text .. "\n\n"
						.. L["Somebody on it who buffs you is still offered the favour back. Shift-right-click them on the prompt to let that favour go."]
				end,
			},
			neverAdd = {
				type = "input",
				name = L["Add a name"],
				desc = L["Type it as the prompt shows it and press Enter."],
				order = 52,
				width = "full",
				-- Always empty: it is a box to type into, not a setting with a
				-- value to show back.
				get = function() return "" end,
				set = function(_, value) ns.PutOnNeverList(value, true) end,
			},
			neverPick = {
				type = "select",
				name = L["Pick a name"],
				order = 53,
				values = NeverChoices,
				disabled = function() return #ns.NeverList() == 0 end,
				-- Only somebody still on the list: the pick outlives a removal
				-- made from chat.
				get = function()
					if neverPicked and ns.IsNeverOffered(neverPicked) then return neverPicked end
					return nil
				end,
				set = function(_, value) neverPicked = value end,
			},
			neverRemove = {
				type = "execute",
				name = L["Remove from list"],
				order = 54,
				disabled = function()
					return not (neverPicked and ns.IsNeverOffered(neverPicked))
				end,
				func = function()
					local name = neverPicked and ns.AllowAgain(neverPicked)
					neverPicked = nil
					if name then
						ns.addon:Print(L["|cffffffff%s|r can be offered again."]:format(name))
					end
				end,
			},
			neverClear = {
				type = "execute",
				name = L["Clear the list"],
				order = 55,
				disabled = function() return #ns.NeverList() == 0 end,
				confirm = true,
				confirmText = L["Take everybody off the never-offer list?"],
				func = function()
					ns.ClearNeverList()
					neverPicked = nil
				end,
			},
		},
	}
	AddBuffToggles(who.args)
	AddOwnControls(who.args)
	-- Last, over everything above and the per-spell switches alike.
	ForOthersOnly(who.args)
	return who
end
