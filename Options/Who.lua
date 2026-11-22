-- Manners -- options: the Who to buff tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local restyleAndMacro, S, F, B = Page.restyleAndMacro, Page.S, Page.F, Page.B
local sGet, sSet, fGet, fSet = Page.sGet, Page.sSet, Page.fGet, Page.fSet
local bSet, prGet, prSet, HasClassBuffs = Page.bSet, Page.prGet, Page.prSet, Page.HasClassBuffs
local OnlyReachesGroup, HasPrompt, TAB = Page.OnlyReachesGroup, Page.HasPrompt, Page.TAB
local function TabOf(path) return Page.TabOf(path) or "" end

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
	-- Held to your group by choice (Buffs.lua, membersOnly: Detect Invisibility).
	if buff.membersOnly and not (buff.partyOnly or buff.groupOnly or buff.oneTarget) then
		-- Not once it goes to passers-by too (the switch under it).
		if not ns.PassersToo(buff) then label = L["%s |cff808080(your group only)|r"]:format(label) end
	end
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
			if not buff.neverAuto and not ns.IsBuffKnown(buff) and not B().skip[buff.key] and not ns.OptedOut(buff, B()) then
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
			get = function() return not ns.BuffOff(buff, B()) end,
			set = function(_, value)
				-- nil rather than false: AceDB stores the difference from the
				-- defaults, and an empty table is stored as nothing.
				if buff.optIn then
					-- Off until it is ticked (Buffs.lua, optIn): ticked is a key in
					-- buff.optIn, and a key in skip would hold it off all the same.
					B().optIn[buff.key] = value or nil
					if value then B().skip[buff.key] = nil end
				else
					B().skip[buff.key] = (not value) or nil
				end
				restyleAndMacro()
			end,
		}
		-- One that is off until it is ticked says so (Buffs.lua, optIn).
		if buff.optIn then
			args["offer_" .. buff.key].desc = L["Off until you tick it. Tick to offer this buff."]
		end
		-- And a switch under one that may be kept for a favour returned and a
		-- request by name (Buffs.lua, returnOnly: Unending Breath, a warlock's
		-- only buff for others): on, it goes to everybody as before 1.11.19.
		if buff.returnOnly then
			args["everyone_" .. buff.key] = {
				type = "toggle",
				name = function() return L["Offer %s to everybody near me"]:format(ns.BuffName(buff) or buff.key) end,
				desc = L["On: it is offered to your group and to passers-by, as it was before 1.11.19. Off: it is kept for returning a favour and for somebody who asks you for it by name in chat."],
				order = 4 + index / 10 + 0.05,
				width = "full",
				hidden = function() return ns.PinnedBuff() ~= nil and ns.PinnedBuff().key ~= buff.key end,
				disabled = function() return not ns.IsBuffKnown(buff) or B().skip[buff.key] == true end,
				get = function() return B().keptBack[buff.key] ~= true end,
				set = function(_, value)
					B().keptBack[buff.key] = (not value) or nil
					restyleAndMacro()
				end,
			}
		end
		-- And a switch under one Manners holds to your group by choice (Buffs.lua,
		-- membersOnly: a warlock's Detect Invisibility), asked for by a player:
		-- on, passers-by are offered it too. Off by default, there only where the
		-- class and the client have such a buff, and shown once the buff itself
		-- is ticked.
		if buff.membersOnly and not (buff.partyOnly or buff.groupOnly or buff.oneTarget) then
			args["passers_" .. buff.key] = {
				type = "toggle",
				name = function() return L["Offer %s to passers-by too"]:format(ns.BuffName(buff) or buff.key) end,
				desc = L["Off: it is offered to the members of your party or raid only. On: passers-by missing it are offered it as well, and so is a passer-by who asks you for it in chat. Passers-by must be ticked above for it to reach them unasked."],
				order = 4 + index / 10 + 0.05,
				width = "full",
				hidden = function()
					if ns.PinnedBuff() ~= nil and ns.PinnedBuff().key ~= buff.key then return true end
					-- Pinned, it is offered whatever its own tick says
					-- (ns.CastableBuffs), and that tick is hidden under a pin:
					-- this one stays in reach.
					if ns.PinnedBuff() ~= nil then return false end
					return ns.BuffOff(buff, B())
				end,
				disabled = function() return not ns.IsBuffKnown(buff) end,
				get = function() return B().detectPassers == true end,
				set = function(_, value)
					B().detectPassers = value and true or false
					restyleAndMacro()
				end,
			}
		end
		-- A buff the player may hold to the tanks of their group (Buffs.lua,
		-- tankChoice: Thorns), under its own switch. Everybody is the absence of
		-- a key, as the switches are.
		if buff.tankChoice then
			args["tank_" .. buff.key] = {
				type = "select",
				name = function() return L["Offer %s to"]:format(ns.BuffName(buff) or buff.key) end,
				desc = L["Who is offered it."] .. "\n\n"
					.. L["Tanks only: in your group, only its tanks; nobody outside it. In a group you are reminded of yours only while you tank."] .. "\n"
					.. L["Tanks, and anyone outside my group: your group's tanks, and passers-by and people who buffed you as usual."] .. "\n"
					.. L["Tanks and me: the tanks, and you whatever your role (Myself must be on)."] .. "\n"
					.. L["Only me: nobody else; you are still reminded when yours is down (Myself must be on)."] .. "\n\n"
					.. L["Somebody who asks you for it in chat always gets it."],
				order = 4 + index / 10 + 0.05,
				width = "full",
				-- "tanks" is Tanks only as it reads: nobody outside the group
				-- either (a player's report). "outside" is what it did before it
				-- was made to mean it, kept as a choice of its own: both keep the
				-- buff's key in buff.tanksOnly, "outside" in buff.tanksOutside too.
				values = function()
					return { all = L["Everyone"], tanks = L["Tanks only"], tanksme = L["Tanks and me"],
						outside = L["Tanks, and anyone outside my group"], me = L["Only me"] }
				end,
				sorting = { "all", "tanks", "tanksme", "outside", "me" },
				hidden = function() return ns.PinnedBuff() ~= nil and ns.PinnedBuff().key ~= buff.key end,
				disabled = function() return not ns.IsBuffKnown(buff) or B().skip[buff.key] == true end,
				get = function()
					if B().meOnly[buff.key] then return "me" end
					if B().tanksOnly[buff.key] and B().tanksOutside[buff.key] then return "outside" end
					if B().tanksOnly[buff.key] and B().tanksMe[buff.key] then return "tanksme" end
					return B().tanksOnly[buff.key] and "tanks" or "all"
				end,
				set = function(_, value)
					-- One of the five: nil rather than false, as the switches are.
					B().tanksOnly[buff.key] = (value == "tanks") or nil
					-- "outside" and "tanksme" hold the group to its tanks too, and
					-- say so in both sets.
					if value == "outside" or value == "tanksme" then B().tanksOnly[buff.key] = true end
					B().tanksOutside[buff.key] = (value == "outside") or nil
					B().tanksMe[buff.key] = (value == "tanksme") or nil
					B().meOnly[buff.key] = (value == "me") or nil
					restyleAndMacro()
				end,
			}
			-- Under it, a switch of its own: not on yourself inside a dungeon or a
			-- raid, whatever Offer to says (asked for on CurseForge by a druid who
			-- heals there).
			args["notMeInside_" .. buff.key] = {
				type = "toggle",
				name = L["Not on me in a dungeon or raid"],
				desc = L["On: in a dungeon or a raid you are not reminded of your own, whatever Offer to says and whatever your role; the rest of your group is offered it as Offer to says. Out in the world, and in a battleground or an arena, you are reminded as before."],
				order = 4 + index / 10 + 0.06,
				width = "full",
				hidden = function() return ns.PinnedBuff() ~= nil and ns.PinnedBuff().key ~= buff.key end,
				disabled = function() return not ns.IsBuffKnown(buff) or B().skip[buff.key] == true end,
				get = function() return B().notMeInside[buff.key] == true end,
				set = function(_, value)
					B().notMeInside[buff.key] = value and true or nil
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
				if family.reagent and ns.ForgetScrolls then ns.ForgetScrolls() end
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
						return L["Automatic reminds you only while your group role is tank; Always reminds you whenever it is not up."]
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
					local split = family.splitTo and ns.OWN_FAMILY_BY_KEY[family.splitTo]
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

-- Everything on Who to buff but "Myself", hidden from a class with nothing
-- for anybody else (a hunter, a shaman): their tab is their own buffs alone.
-- Each control keeps its own rule on top.
local function ForOthersOnly(args)
	for key, arg in pairs(args) do
		-- Consumables only in dungeons and raids is about your own buffs too:
		-- a hunter's or a shaman's food and flasks.
		if not (key == "myselfHeader" or key == "self" or key == "ownCities" or key == "ownDungeons"
			-- Which pet stands under the companion pet's switch, which is every
			-- class's own (a retail death knight has nothing else on this page).
			or key == "ownScrolls" or key == "ownShout" or key == "ownImbueFirst" or key == "ownPetChoice"
			or key == "ownRestedEarly"
			or key:find("^own_")) then
			local was = arg.hidden
			arg.hidden = function(...)
				if not HasClassBuffs() then return true end
				if type(was) == "function" then return was(...) end
				return was
			end
		end
	end
end

-- Added after ForOthersOnly, as the cures are: a shaman on WoW Forever and a
-- monk on retail have no buff for anybody else and still raise the dead.
function Page.AddResControls(args)
	-- Your resurrection for the group's dead (Resurrect.lua): on, and
	-- shown only to a class that has one on this client. A dead
	-- passer-by is a second switch under it, off until ticked, and not
	-- shown while the first is off (the layout's `parents`).
	args.res = {
		type = "toggle",
		name = L["Resurrect my group's dead"],
		desc = L["Offer your resurrection for somebody of your party or raid who is dead and within reach, ahead of everything else. Never in a fight, never for somebody who has released their spirit, and not while another resurrection is already on its way to them."],
		order = 12.7,
		width = "full",
		hidden = function() return not (ns.Resurrect and ns.Resurrect.Has()) end,
		get = sGet,
		set = sSet,
	}
	args.resStrangers = {
		type = "toggle",
		name = L["Dead passers-by too"],
		desc = L["Also offer it for a dead player outside your group whom you could help: your target, your focus or whoever is under your cursor."],
		order = 12.8,
		width = "full",
		hidden = function() return not (ns.Resurrect and ns.Resurrect.Has() and S().res) end,
		get = sGet,
		set = sSet,
	}
end

-- Asking, not only giving (Ask.lua): the one thing on Who to buff that is about
-- what other people cast, under a heading of its own after the sources. The
-- switch, and under it how the ask is said: shown only while it is on (the
-- layout's `parents` lets search find them). In the fallback dialog the block
-- runs 14.45 to 14.8, after the courtesies (to 14.4) and before the cures (14.9).
function Page.AddAskControls(args)
	local function off() return S().ask ~= true end
	args.askHeader = { type = "header", name = L["Asking for buffs"], order = 14.45 }
	args.ask = {
		type = "toggle",
		name = L["Ask people for a buff I'm missing"],
		desc = L["When somebody in your group, or right beside you, could cast a buff you would want and do not have, the prompt can offer to ask them. A press says one short polite line to them and casts nothing. It comes last of everything on the prompt; never in a fight, a battleground or an arena; one ask a person for each buff in ten minutes, and one ask in all in two minutes. Nobody on your never-offer list or your ignore list is asked."],
		order = 14.5,
		width = "full",
		get = function() return S().ask == true end,
		set = function(_, v)
			S().ask = v == true
			ns.Prompt:InvalidateMacro()
			ns.Prompt:Refresh()
			-- Start here and this page's own shape follow the switch.
			ns.RepaintOptions()
		end,
	}
	args.askChannel = {
		type = "select",
		name = L["Ask in"],
		desc = L["A whisper reaches only the person you ask. /say is heard by everybody near you."],
		order = 14.6,
		values = { WHISPER = L["A whisper to them"], SAY = L["/say, aloud"] },
		sorting = { "WHISPER", "SAY" },
		hidden = off,
		get = function() return ns.db.profile.ask.channel end,
		set = function(_, v)
			ns.db.profile.ask.channel = v
			ns.Prompt:InvalidateMacro()
		end,
	}
	args.askLine = {
		type = "select",
		name = L["What the ask says"],
		desc = L["{name} is their name and {buff} the spell. With the In character set chosen on %s, a line in character is said instead."]
			:format(TabOf("click.preset")),
		order = 14.7,
		width = "full",
		values = function() return ns.Ask.Choices() end,
		sorting = function() return ns.Ask.CHOICE_ORDER end,
		hidden = off,
		get = function() return ns.db.profile.ask.line end,
		set = function(_, v)
			ns.db.profile.ask.line = v
			ns.Prompt:InvalidateMacro()
		end,
	}
	-- My own words (Ask.lua, CleanOwn), shown while they are the choice.
	args.askOwn = {
		type = "input",
		name = L["My own words"],
		desc = L["What the ask says, in your own words, even with the In character set on. {name} is their name and {buff} the spell; leave {name} out and no name is said. One line. Left empty, the first line above is said."],
		order = 14.75,
		width = "full",
		hidden = function() return off() or ns.db.profile.ask.line ~= "own" end,
		get = function() return ns.db.profile.ask.own or "" end,
		set = function(_, v)
			ns.db.profile.ask.own = ns.Ask.CleanOwn(v)
			ns.Prompt:InvalidateMacro()
		end,
	}
	args.askInTowns = {
		type = "toggle",
		name = L["Ask in cities and inns too"],
		desc = L["Off: nobody is asked while you are in a city or an inn."],
		order = 14.8,
		width = "full",
		hidden = off,
		get = function() return ns.db.profile.ask.inTowns == true end,
		set = function(_, v) ns.db.profile.ask.inTowns = v == true end,
	}
end

-- Cures (Cures.lua): a heading of their own under the sources, the two
-- switches and the seconds a debuff must have left. Added after ForOthersOnly:
-- a shaman on Classic Era has no buff for anybody else and still has a cure.
-- Shown only for a class with a cure on this client, learned or not; the note
-- says which spell takes off what, or that none is learned yet.
local function AddCureControls(args)
	local function NoCures() return not ns.ClassHasCures() end
	local function CuresOff() return not (S().cures or S().curesStrangers or S().curesSelf) end
	args.curesHeader = { type = "header", name = L["Cures"], order = 14.9, hidden = NoCures }
	args.curesNote = {
		type = "description",
		order = 14.91,
		hidden = NoCures,
		name = function() return "|cff888888" .. ns.CureSummary() .. "|r" end,
	}
	args.cures = {
		type = "toggle",
		name = L["Cure my party and raid"],
		desc = L["Out of combat, offer to take a poison, a disease, a curse or a harmful spell off someone in your party or raid, with the spell your class has for it. A cure comes before a buff for the same person, and after a favour you owe."],
		order = 14.92,
		width = "full",
		hidden = NoCures,
		get = sGet,
		set = sSet,
	}
	args.curesStrangers = {
		type = "toggle",
		name = L["Cure passers-by"],
		desc = L["The same for players near you who are not in your group, seen through nameplates, your target, focus and mouseover."],
		order = 14.93,
		width = "full",
		hidden = NoCures,
		get = sGet,
		set = sSet,
	}
	args.curesSelf = {
		type = "toggle",
		name = L["Cure myself too"],
		desc = L["Out of combat, offer to take a poison, a disease, a curse or a harmful spell off yourself, with the spell your class has for it. It comes before your own buffs."],
		order = 14.935,
		width = "full",
		hidden = NoCures,
		get = sGet,
		set = sSet,
	}
	args.cureSeconds = {
		type = "range",
		name = L["Only when it has at least this long left"],
		desc = L["In seconds."] .. " " .. L["A poison, disease, curse or spell about to run out on its own is left alone. One with no timer is never offered."],
		order = 14.94,
		min = 0,
		max = 120,
		step = 5,
		hidden = NoCures,
		disabled = CuresOff,
		get = fGet,
		set = fSet,
	}
	-- The fight's own button (Prompt/CureFight.lua) has its switch on Look, In
	-- a fight; the same switch sits here too, where somebody turning cures on
	-- looks for it. It does not follow the switches above or the seconds.
	args.curesFight = {
		type = "toggle",
		name = L["Show a cure button in a fight when somebody needs it"],
		desc = function()
			if ns.caps.conditionalTargeting then
				return L["A button of its own beside the prompt, with its own key. It shows when somebody near you has a poison, disease, curse or harmful magic your class can remove, and says who. A press cures whoever is under your mouse, else your target, else you; Shift casts your second cure. Where the game hides debuffs in a fight it stays hidden, but its key still works. A change made in a fight counts from the next one."]
			end
			return L["A button of its own beside the prompt, with its own key. It shows when somebody near you has a poison, disease, curse or harmful magic your class can remove, and says who. A press cures your target when it is a friend, else you; Shift casts your second cure. Where the game hides debuffs in a fight it stays hidden, but its key still works. A change made in a fight counts from the next one."]
		end,
		order = 14.95,
		width = "full",
		hidden = function() return NoCures() or not ns.CureLearned() end,
		get = function() return ns.db.profile.prompt.cureFight == true end,
		set = function(_, value)
			ns.db.profile.prompt.cureFight = value == true
			if ns.CureFight then ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight) end
		end,
	}
end

-- A hunter's pet (HunterPet.lua): care, a switch each, held to Myself, and the
-- moments with it under a switch of their own, with what Manners remembers of
-- each pet under that. Shown to a hunter alone; Feed Pet only where pets eat.
-- Added after ForOthersOnly: a hunter has no buff for anybody else.
function Page.AddBeastControls(args)
	local function NotHunter() return not (ns.Beast and ns.Beast.IsHunter()) end
	local function SelfOff() return S().self ~= true end
	local function AllOff() return ns.db.profile.beast.all == false end
	local function BondOff() return AllOff() or ns.db.profile.beast.bond ~= true end
	local function Toggle(key, field, name, desc, order, hidden, disabled)
		args[key] = {
			type = "toggle",
			name = name,
			desc = desc,
			order = order,
			width = "full",
			hidden = hidden or NotHunter,
			disabled = function() return AllOff() or (disabled ~= nil and disabled()) end,
			get = function() return ns.db.profile.beast[field] == true end,
			set = function(_, value)
				ns.db.profile.beast[field] = value == true
				ns.Guard("pet repaint", ns.Prompt.Refresh, ns.Prompt)
			end,
		}
	end
	-- The master, built by hand: Toggle greys a row while it is off.
	args.beastAll = { type = "toggle", name = L["Everything for my pet"],
		desc = L["Off, Manners leaves your pet to you: no care, no moments, no hints and no Mend Pet button in a fight. Each switch below keeps its own setting for when this is on again."],
		order = 15.980, width = "full", hidden = NotHunter,
		get = function() return ns.db.profile.beast.all ~= false end,
		set = function(_, value)
			ns.db.profile.beast.all = value == true
			ns.Guard("pet repaint", ns.Prompt.Refresh, ns.Prompt)
			if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
		end }
	Toggle("beastCall", "call", L["Call my pet when none is out"],
		L["Offers Call Pet when no pet is with you. Not in a fight, not while mounted, not in a city unless your own buffs are offered there, and not after you dismissed it yourself."],
		15.981, nil, SelfOff)
	Toggle("beastRevive", "revive", L["Revive my pet when it is dead"],
		L["Offers Revive Pet when your pet has died."], 15.982, nil, SelfOff)
	Toggle("beastFeed", "feed", L["Feed my pet when it is not happy"],
		L["Offers Feed Pet with a food it eats from your bags while it is not happy, and nothing once it is. Food that makes you Well Fed is kept for you."],
		15.983, function() return NotHunter() or not ns.Beast.Feeds() end, SelfOff)
	Toggle("beastMend", "mend", L["Mend my pet when it is hurt after a fight"],
		L["Offers Mend Pet when your pet is badly hurt and the fight is over."], 15.984, nil, SelfOff)
	-- The fight's own Mend Pet button (Prompt/MendPet.lua) has its switch on
	-- Look, In a fight; the same switch sits here too, under the other Mend
	-- Pet one, where a hunter turning Mend Pet off looks for it.
	args.beastMendFight = { type = "toggle", name = L["Show a Mend Pet button in a fight when my pet is badly hurt"],
		desc = L["A button of its own beside the prompt, with its own key. It shows while your pet is under half health, in reach, and Mend Pet is ready. Where the game hides your pet's health in a fight, it shows only with Show the fight buttons set to All fight; its key works either way. A change made in a fight counts from the next one."],
		order = 15.9841, width = "full",
		hidden = function() return NotHunter() or not ns.Beast.KnowsMend() end,
		disabled = AllOff,
		get = function() return ns.db.profile.beast.fightMend ~= false end,
		set = function(_, value)
			ns.db.profile.beast.fightMend = value == true
			if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
		end }
	Toggle("beastLeaveFood", "leaveFood", L["Tell me at a vendor when my pet is low on food"],
		L["At a vendor who sells a food your pet eats, a line in chat when your bags hold fewer than five meals for your pet. Once a vendor each session. Manners never buys anything."],
		15.9844, function() return NotHunter() or not ns.Beast.Feeds() end)
	Toggle("beastGrowl", "growl", L["Remind me about Growl in groups and alone"],
		L["A line in chat when Growl is on autocast in a dungeon or raid with a tank in your group (once a zone), or off while you are alone in the open world (once a session). Manners never changes it for you. Off by default: the game does not always say who the tank is."],
		15.9845)
	Toggle("beastTraining", "training", L["Tell me when my pet has training points to spend"],
		L["A line in chat when your pet has training points left unspent: once a session, and again when there are more, at most once in fifteen minutes."],
		15.9846, function() return NotHunter() or not ns.Beast.Trains() end)
	Toggle("beastBond", "bond", L["Bond with my pet"],
		L["Now and then, after a hard fight, a revive, at login or on a quiet road, offers a moment with your pet: an emote for it, and a line from your people when In character is on and lines go in /say. Never in a fight; letting it pass costs nothing."],
		15.985)
	args.beastPace = { type = "select", name = L["How often moments come"],
		desc = L["The least time between two moments with your pet: an hour, twenty minutes or ten. Before one on a quiet road: half an hour, a quarter of an hour or ten minutes."],
		order = 15.9851, hidden = NotHunter, disabled = BondOff,
		values = { rarely = L["Rarely"], sometimes = L["Sometimes"], often = L["Often"] },
		sorting = { "rarely", "sometimes", "often" },
		get = function() return ns.db.profile.beast.pace end,
		set = function(_, value) ns.db.profile.beast.pace = value ns.Guard("pet repaint", ns.Prompt.Refresh, ns.Prompt) end }
	local function Moment(extra) return function() return NotHunter() or BondOff() or (extra ~= nil and extra()) end end
	local feeds = function() return not ns.Beast.Feeds() end
	local MOMENTS = {
		{ "beastPraise", "praise", L["After a hard fight or a boss: well done"] },
		{ "beastComfort", "comfort", L["After a fight your pet barely lived through: comfort"] },
		{ "beastWelcome", "welcome", L["After a revive: welcome back"] },
		{ "beastSorry", "sorry", L["After a revive, when your pet fell in a fight: say sorry"], L["Takes turns with welcome back when both are on; never both at once."] },
		{ "beastHello", "hello", L["At login: hello"] },
		{ "beastMorning", "morning", L["After a night at an inn: good morning"], L["With a line in chat at login that your pet slept by the fire."] },
		{ "beastRoad", "road", L["On a quiet road: a pat"] },
		{ "beastPlay", "play", L["On a quiet road: a game of fetch"], L["Takes turns with the pat when both are on."] },
		{ "beastShare", "share", L["When you sit down to eat: share your meal"], L["While your pet is not happy and a food your pet eats is in your bags: offered once your meal is over, so a press never stands you up."], feeds },
		{ "beastFamily", "family", L["A newly tamed pet: welcome to the family"], L["Right after Tame Beast. If the name is still the kind's (Wolf, Cat), the prompt suggests choosing one."] },
		{ "beastMissed", "missed", L["Back after three days or more apart"] },
		{ "beastSaved", "saved", L["When your pet saved you: thanks"], L["After a fight you ended alive below a fifth of your health, with your pet out from start to end."] },
		{ "beastGrown", "grown", function() return ns.Beast.Loyal() and L["When your pet grows: a level, or more loyalty"] or L["When your pet gains a level"] end },
		{ "beastAnniversary", "anniversary", L["Your days together: 7, 30, 100 and 365"] },
		{ "beastAnswer", "answer", L["My pet answers"], L["After the gesture, how your pet answers, by kind: a wolf wags, an owl hoots."] },
		{ "beastWords", "words", L["Say a line to my pet"], L["With In character on and lines going in /say, a line from your people to your pet with each moment."] },
		{ "beastMilestones", "memory", L["Remember fights, pats and meals, with a line at milestones"], L["What Manners counts of each pet by name, and a line in chat at a milestone. Off, nothing is counted and nothing is said."] },
	}
	for i, row in ipairs(MOMENTS) do Toggle(row[1], row[2], row[3], row[4], 15.987 + i / 10000, Moment(row[5])) end
	args.beastMemory = {
		type = "description",
		order = 15.9899,
		hidden = function() return NotHunter() or BondOff() or ns.db.profile.beast.memory == false end,
		name = function()
			local lines = ns.Beast.MemoryLines()
			if #lines == 0 then return "|cff888888" .. L["No pet remembered yet."] .. "|r" end
			return "|cff888888" .. table.concat(lines, "\n") .. "|r"
		end,
	}
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

-- A blessing for each class (buff.forClass; Core.lua, PickBuffFor): for a class
-- whose buffs replace one another and that knows two of them, and not while one
-- spell is pinned. One class is picked at a time, a state of the window.
local classPicked

local function ClassHidden()
	return ns.PinnedBuff() ~= nil or #ns.ClassBlessings() < 2
end

-- The classes by their names, as the client spells them.
local function ClassKeys()
	local values, keys = ClassChoices(), {}
	for class in pairs(values) do keys[#keys + 1] = class end
	table.sort(keys, function(a, b)
		if values[a] == values[b] then return a < b end
		return tostring(values[a]) < tostring(values[b])
	end)
	return keys
end

local function ClassPick()
	local values = ClassChoices()
	if classPicked and values[classPicked] then return classPicked end
	return ClassKeys()[1]
end

-- The chosen blessing's buff for a class, or nil: one this character knows.
local function ClassBlessing(class)
	local key = B().forClass[class]
	if not key then return nil end
	for _, buff in ipairs(ns.ClassBlessings()) do
		if buff.key == key then return buff end
	end
	return nil
end

local function ClassNote()
	local values, chosen = ClassChoices(), {}
	for _, class in ipairs(ClassKeys()) do
		local buff = ClassBlessing(class)
		if buff then chosen[#chosen + 1] = tostring(values[class]) .. ": " .. (ns.BuffName(buff) or buff.key) end
	end
	local text = "|cffffd100" .. L["A blessing for each class"] .. "|r\n"
		.. L["Pick a class, then the blessing its players are offered first. Somebody who already wears it from another paladin, or who cannot be given it, gets what the order above would have chosen; anybody wearing one of yours is left alone."]
	if #chosen == 0 then
		return text .. "\n\n" .. L["No class has a blessing of its own yet."]
	end
	return text .. "\n\n" .. L["Chosen: %s."]:format(table.concat(chosen, ", "))
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

-- The dungeon switch's name, true to what it holds back. Ticking it unticks
-- Buff my team there, so it holds a battleground too; ticked with that switch
-- ticked again since, a battleground is that one's (Battle.lua) and the name
-- leaves it out. Read wherever the switch is named, so they agree.
function Page.InstancesLabel()
	local db = ns.db and ns.db.profile
	if db and db.filters.quietInInstances == true and type(db.battle) == "table" and db.battle.team == true then
		return L["Offer nothing in dungeons and raids"]
	end
	return L["Offer nothing in dungeons, raids and battlegrounds"]
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
			return "|cff9d9d9d" .. L["You have not learned a group version of your buffs yet."] .. "|r"
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
			-- Asked for on GitHub (issue 12): WoW Forever's Fish Bowl, which Kings
			-- replaces. Only where the camp's Fish Bowl exists, and for a class
			-- whose strongest blessing is the one at stake.
			spareFishBowl = {
				type = "toggle",
				name = L["Offer Kings last to someone with a Fish Bowl's Boosted Stats"],
				desc = L["Sitting by a Fish Bowl gives Boosted Stats, 8% to all stats, and Blessing of Kings replaces it. On: somebody wearing it is offered your other blessings first, and Kings only when nothing else of yours is missing for them."],
				order = 4.87,
				width = "full",
				hidden = function()
					if not (ns.Flavour and ns.Flavour.flavour == "camelot") then return true end
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						if buff.strongest then return false end
					end
					return true
				end,
				get = function() return B().spareFishBowl == true end,
				set = bSet,
			},
			-- Asked for on GitHub (issue 17): the strict one, under it. Greyed
			-- while the switch above is off, so the window does not draw it
			-- (the layout's `parents`).
			neverFishBowl = {
				type = "toggle",
				name = L["Never offer them Kings while it lasts"],
				desc = L["On: somebody wearing a Fish Bowl's Boosted Stats is not offered Blessing of Kings at all while it lasts, even with nothing else of yours missing. Somebody who asks you for Kings by name is still given it."],
				order = 4.871,
				width = "full",
				hidden = function()
					if not (ns.Flavour and ns.Flavour.flavour == "camelot") then return true end
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						if buff.strongest then return false end
					end
					return true
				end,
				disabled = function() return B().spareFishBowl ~= true end,
				get = function() return B().neverFishBowl == true end,
				set = bSet,
			},
			-- Asked for on CurseForge: WoW Forever's campsite gives Boosted
			-- Stamina, Intellect and Spirit, which a stronger Fortitude, Arcane
			-- Intellect or Divine Spirit is cast over. Only for a class with a
			-- buff a campsite's buff holds off (Buffs.lua, blockers).
			spareCamp = {
				type = "toggle",
				name = L["Leave a campsite's Boosted Stamina, Intellect or Spirit alone"],
				desc = L["Resting at a campsite gives Boosted Stamina, Intellect or Spirit. Manners already leaves it alone when it gives as much as yours would. On: nobody wearing it, you included, is offered the buff it would replace, even a stronger one."],
				order = 4.872,
				width = "full",
				hidden = function()
					if not next(ns.STAT_TIERS or {}) then return true end
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						for _, id in ipairs(buff.blockerIds or {}) do
							if ns.STAT_TIERS[id] then return false end
						end
					end
					return true
				end,
				get = function() return B().spareCamp == true end,
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

			-------------------------------------------------- a blessing a class
			-- Asked for on CurseForge by a paladin: Wisdom for mages, say, where
			-- the order would give them Kings.
			classNote = {
				type = "description",
				order = 6.6,
				fontSize = "medium",
				hidden = ClassHidden,
				name = ClassNote,
			},
			classPick = {
				type = "select",
				name = L["Class"],
				order = 6.7,
				values = ClassChoices,
				sorting = ClassKeys,
				hidden = ClassHidden,
				get = ClassPick,
				set = function(_, value) classPicked = value end,
			},
			classBlessing = {
				type = "select",
				name = L["Blessing for that class"],
				desc = L["Automatic leaves this class to the order above."],
				order = 6.8,
				values = function()
					local values = { auto = L["Automatic"] }
					for _, buff in ipairs(ns.ClassBlessings()) do
						values[buff.key] = ns.BuffName(buff) or buff.key
					end
					return values
				end,
				sorting = function()
					local keys = { "auto" }
					for _, buff in ipairs(ns.ClassBlessings()) do keys[#keys + 1] = buff.key end
					return keys
				end,
				hidden = ClassHidden,
				get = function()
					local buff = ClassBlessing(ClassPick())
					return buff and buff.key or "auto"
				end,
				set = function(_, value)
					B().forClass[ClassPick()] = (value ~= "auto") and value or nil
					restyleAndMacro()
					ns.RefreshOptionsDisplay()
				end,
			},
			-- Only once a class has one: nothing chosen needs no way back.
			classReset = {
				type = "execute",
				name = L["Clear every class's blessing"],
				order = 6.9,
				hidden = function() return ClassHidden() or next(B().forClass) == nil end,
				func = function()
					wipe(B().forClass)
					restyleAndMacro()
					ns.RefreshOptionsDisplay()
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
			-- Their pets, under the switch it widens (asked for on CurseForge
			-- by a hunter and a warlock). Off until ticked, and not shown
			-- while the group is off, when it would offer nobody: search
			-- still finds it (the layout's `parents`).
			pets = {
				type = "toggle",
				name = L["My group's pets too"],
				desc = L["Also offer your buffs to the pets of the people in your party or raid: a hunter's beast, a warlock's demon. A pet is targeted by its name, so one with a name of its own is reached most surely."],
				order = 12.5,
				width = "full",
				hidden = function() return not S().group end,
				get = sGet,
				set = sSet,
			},
			-- The group split with the other Manners users of your class in it
			-- (Share.lua), under the switch it narrows. On: it only takes double
			-- offers away. Not shown while the group is off; search still finds
			-- it (the layout's `parents`).
			share = {
				type = "toggle",
				name = L["Split the group with others of my class who use Manners"],
				desc = L["When somebody else of your class in your party or raid uses Manners too, the group is split between you, so you are not both sent to buff the same person. A favour owed, a request, your target and your focus are never held back, and anybody still missing the buff after 45 seconds is offered anyway."],
				order = 12.6,
				width = "full",
				hidden = function() return not S().group end,
				get = sGet,
				set = sSet,
			},
			strangers = {
				type = "toggle",
				name = L["Passers-by: players near me who are not in my group"],
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
					-- How far a shout reaches is the client's (Buffs.lua): your own
					-- party on Classic Era and Burning Crusade, the whole raid
					-- round you on WoW Forever, Mists and retail.
					return "|cff888888"
						.. (ns.PARTY_IS_SUBGROUP
							and L["Everything you can offer is cast on yourself and reaches only your party, so there is nothing for passers-by."]
							or L["Everything you can offer is cast on yourself and reaches your party and raid around you, so there is nothing for passers-by."])
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
				desc = L["On: nothing is offered to anybody while you are in a city or an inn: not passers-by, not your group, not a favour you owe. Somebody you target or focus is still offered. Your own buffs have a switch of their own: %s."]
					:format(Page.Ref(L["Also in cities and inns"], TabOf("who.ownCities"))),
				order = 13.35,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- Where that switch holds (asked for on CurseForge: no offers in a
			-- city, but the people resting at an inn buffed). A city is a
			-- capital by the map the client says you are on (Range.lua,
			-- ns.InCity); a map it will not name counts as both.
			quietInTownsWhere = {
				type = "select",
				name = L["Where"],
				desc = L["A city is a capital, such as Stormwind or Orgrimmar; an inn is anywhere else you rest. When the game will not say which map you are on, both count."],
				order = 13.355,
				values = {
					both = L["Cities and inns"],
					cities = L["Cities only"],
					inns = L["Inns only"],
				},
				sorting = { "both", "cities", "inns" },
				disabled = function() return F().quietInTowns ~= true end,
				get = fGet,
				set = fSet,
			},
			-- The same rule inside an instance: a player asked on CurseForge for
			-- no offers in a dungeon, where the group sorts out its own buffs.
			quietInInstances = {
				type = "toggle",
				-- Says what it holds back now: ticked with Buff my team there
				-- ticked again afterwards, a battleground is that switch's.
				name = function() return Page.InstancesLabel() end,
				-- How it meets In battlegrounds and arenas (When.lua, Battle.lua):
				-- there that section's own switch decides, and ticking this one
				-- unticks it, so the name still holds.
				desc = function()
					return L["On: inside a dungeon or a raid, nothing is offered to anybody: not your group, not a favour you owe. Somebody you target or focus is still offered, and your own buffs are not held back. A battleground or an arena goes by its own switch, %s, which ticking this one unticks."]
						:format("|cffffd100" .. L["Buff my team there"] .. "|r")
				end,
				order = 13.36,
				width = "full",
				get = fGet,
				set = function(info, value)
					fSet(info, value)
					if value == true then ns.db.profile.battle.team = false end
				end,
			},
			-- Short buffs alone held back while resting (asked for on CurseForge: a
			-- druid wants Mark of the Wild shared everywhere and Thorns not).
			quietShortInTowns = {
				type = "toggle",
				name = L["Hold back short buffs in cities and inns"],
				desc = L["On: while you are in a city or an inn, buffs that last only a few minutes (Thorns, say) are not offered, since they run out before you reach anywhere they matter; longer ones, such as Mark of the Wild, still are. Somebody who asks for a buff by name, and somebody you target or focus, is still offered it."],
				order = 13.356,
				width = "full",
				get = fGet,
				set = fSet,
			},
			quietShortMinutes = {
				type = "range",
				name = L["A buff counts as short up to"],
				desc = L["In minutes."] .. " " .. L["Buffs that last up to this long are held back in a city or an inn."],
				order = 13.357,
				min = 5,
				max = 60,
				step = 5,
				disabled = function() return F().quietShortInTowns ~= true end,
				get = fGet,
				set = fSet,
			},
			-- Both place rules leave the target and focus alone; this takes
			-- them in (a player asked on GitHub for no offers at all in a
			-- city).
			quietTargets = {
				type = "toggle",
				name = L["Hold back my target and focus too"],
				-- And a battleground or an arena with its own switch off, which
				-- is the same rule there (Queue.lua, inTown).
				desc = function()
					return L["On: the switches above hold back everybody, even somebody you target or focus. Off: somebody you target or focus is still offered."]
						.. " " .. L["In a battleground or an arena with %s off, %s holds back somebody you target or focus too."]
							:format("|cffffd100" .. L["Buff my team there"] .. "|r",
								"|cffffd100" .. L["Hold back my target and focus too"] .. "|r")
				end,
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
			-- A class's courtesies for whoever asks (Courtesy.lua), under the
			-- switch above: each off until ticked, and shown only for the class
			-- that has it on this client.
			courtesyRefresh = {
				type = "toggle",
				name = L["Water and food, when they ask"],
				desc = L["Somebody who asks for water or food (\"water pls\", \"mage food\") is offered it. With none in your bags the first press conjures it; the next targets them and opens a trade with it in the window. Accepting the trade stays yours. Never in a fight."],
				order = 14.1,
				width = "full",
				hidden = function() return not (S().asked and ns.Courtesy.Has("courtesyRefresh")) end,
				get = sGet,
				set = sSet,
			},
			courtesyPortals = {
				type = "toggle",
				name = L["Portals, when my group asks"],
				desc = L["A member of your party or raid who asks for a portal by its city (\"port to Orgrimmar pls\", \"portal uc?\") is offered it, when you have learned it and carry what it costs. The press targets nobody and casts the portal. Never in a fight."],
				order = 14.2,
				width = "full",
				hidden = function() return not (S().asked and ns.Courtesy.Has("courtesyPortals")) end,
				get = sGet,
				set = sSet,
			},
			courtesyHealthstones = {
				type = "toggle",
				name = L["Healthstones, when they ask"],
				desc = function()
					if ns.Courtesy.FromSoulwell() then
						return L["A member of your party or raid who asks for a healthstone (\"hs pls\") is offered a Soulwell: the press targets nobody and casts it. Never in a fight."]
					end
					return L["Somebody who asks for a healthstone (\"hs pls\") is offered one. With none in your bags the first press creates it; the next targets them and opens a trade with it in the window. Accepting the trade stays yours. Never in a fight."]
				end,
				order = 14.3,
				width = "full",
				hidden = function() return not (S().asked and ns.Courtesy.Has("courtesyHealthstones")) end,
				get = sGet,
				set = sSet,
			},
			courtesySummons = {
				type = "toggle",
				name = L["Summons, when my group asks"],
				desc = L["A member of your party or raid who asks for a summon (\"summon pls\") is offered it: the press targets them and casts Ritual of Summoning, and leaves them targeted for the summoning. Never in a fight."],
				order = 14.4,
				width = "full",
				hidden = function() return not (S().asked and ns.Courtesy.Has("courtesySummons")) end,
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
			-- A shout is cast on yourself and lands on whoever it reaches, so
			-- the ticks above cannot aim it: they choose whose missing shout
			-- brings the prompt up. How far it reaches is the client's
			-- (Buffs.lua: partyIsSubgroup on Classic Era and Burning Crusade).
			skipRaidGroupsNote = {
				type = "description",
				order = 23.1,
				hidden = function()
					if not S().group then return true end
					local castable = ns.CastableBuffs()
					if #castable == 0 then return true end
					for _, buff in ipairs(castable) do
						if not buff.selfCast then return true end
					end
					return false
				end,
				name = function()
					return "|cff888888" .. (ns.PARTY_IS_SUBGROUP
						and L["What you offer is cast on yourself and reaches only your own group of a raid, so the other groups' ticks change nothing."]
						or L["What you offer is cast on yourself and reaches every group of the raid around you: these ticks only choose whose missing buff brings the prompt up."])
						.. "|r"
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
							.. L["Greyed out while |cffffd100Always offer|r is chosen on %s: nothing is read then."]:format(TabOf("when.whenBuffed"))
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
			-- Asked for on CurseForge: see "in a fight" in Queue.lua.
			skipFighting = {
				type = "toggle",
				name = L["Skip players in a fight"],
				desc = L["Buffing somebody in a fight pulls you into it, and what they are fighting may turn on you. They are offered again once the fight is over. Your target and focus are still offered."],
				order = 43.2,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- Asked for by a player: see SelfServed in Queue.lua.
			skipSameClass = {
				type = "toggle",
				name = L["Skip players of my class, who can buff themselves"],
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
				name = L["Skip these guilds"],
				desc = L["One guild per line, or several with commas between. Blank lines and repeats are dropped when you press Accept."] .. " " .. L["People in these guilds are not offered anything, in your group or as passers-by. Type a guild's name as it shows under a player, with or without the < >. Somebody who buffed you or asked, and your target and focus, are still offered. |cffffd100Show their guild under the name|r (%s) shows whose guild it is."]:format(TabOf("appearance.showGuild")),
				order = 43.6,
				multiline = 4,
				width = "full",
				get = fGet,
				set = function(info, value) fSet(info, ns.TidyGuildList(value)) end,
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
			neverPaste = {
				type = "input",
				name = L["Paste a list of names"],
				desc = L["One name per line, or several with commas between, as the prompt shows them. Press Accept to put them all on the list. Blank lines and names already on it are passed over."],
				order = 52.5,
				multiline = 4,
				width = "full",
				get = function() return "" end,
				set = function(_, value) ns.NeverOfferList(value) end,
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
			-- Beside the list: the buffs the game refused on somebody, held off
			-- them for ten minutes (Queue.lua), offered again on purpose.
			heldRetry = {
				type = "execute",
				name = L["Offer held-back buffs again"],
				desc = L["A buff the game refused on somebody (A more powerful spell is already active, too low a level, or refused twice running with nothing changed) is not offered to them for ten minutes. This offers every such buff again now."],
				order = 56,
				disabled = function() return not ns.AnyHeldOff() end,
				func = function() ns.OfferHeldAgain() end,
			},
		},
	}
	AddBuffToggles(who.args)
	AddOwnControls(who.args)
	-- Last, over everything above and the per-spell switches alike.
	ForOthersOnly(who.args)
	-- Asking for buffs, added after it: a class with nothing for anybody else
	-- is the one it is for above all.
	Page.AddAskControls(who.args)
	-- And the resurrection's two switches: a class with nothing else for others
	-- has one too.
	Page.AddResControls(who.args)
	-- After it: the cures are for a class with nothing else for others too.
	AddCureControls(who.args)
	-- And a hunter's pet, whose page is Myself alone.
	Page.AddBeastControls(who.args)
	-- And the spells of your own added under Myself (OwnSpells.lua), every class's.
	Page.AddOwnSpellControls(who.args)
	return who
end

-- Add a spell of my own (OwnSpells.lua), under Myself, after ForOthersOnly: a
-- hunter's own buffs are all his page has. The line under Mana Shield and the
-- wards (Buffs.lua, brief) is here too.
function Page.AddOwnSpellControls(args)
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
