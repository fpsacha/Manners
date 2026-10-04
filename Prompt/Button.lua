-- Manners -- the prompt button's scripts other than the press (Press.lua): the
-- drag, the cursor coming onto the panel and leaving it, and the tooltip.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local RemainingText = lib.RemainingText
local OnPreClick, OnPostClick = lib.OnPreClick, lib.OnPostClick

-- Whether a drag actually started. The client delivers OnDragStop for every
-- drag gesture, including the ones OnDragStart refused (locked, in combat).
local dragging

-- Ends a move under way: the frame let go, where it landed saved, and the
-- prompt locked. Shared by the release and by a fight arriving mid-drag, which
-- must leave the prompt in the same place.
local function FinishDrag()
	dragging = nil
	R.button:StopMovingOrSizing()
	local point, _, relPoint, x, y = R.button:GetPoint()
	local p = ns.db.profile.prompt
	-- The client returns the offsets in the frame's scaled units; the profile
	-- keeps UIParent's. The frame's own scale is the one it was moved at, not
	-- p.scale, which can be ahead of the frame: a Scale slider moved in a fight
	-- waits for the fight to end before ApplyStyle applies it.
	local okScale, s = pcall(R.button.GetScale, R.button)
	if not okScale or type(s) ~= "number" or s <= 0 then s = p.scale end
	p.point, p.relPoint = point, relPoint
	p.x, p.y = math.floor(x * s + 0.5), math.floor(y * s + 0.5)

	-- Lock straight after a drag: an unlocked prompt cannot cast, and looks
	-- just like a working one with nobody to offer.
	p.locked = true
	Prompt:ApplyStyle()
	-- The options page is usually open for this; repaint it so its Locked box
	-- and position controls match.
	ns.RepaintOptions()
	ns.addon:Print(L["moved and locked."])
end

-- The tooltip's lines about one person: why they are offered, and what the
-- game would say about the buff on them.
local function PersonTooltipLines(entry)
	-- A top-up reads as one, and "missing it" only where it was read as
	-- missing; "Always offer" and unreadable auras get the plain reason.
	local left = RemainingText(entry.remaining)
	local why
	if entry.reason == "owed" then
		why = L["Buffed you -- return the favour."]
	elseif entry.reason == "self" then
		-- Offered to you only on a reading (Queue.lua): missing, or low.
		why = left and L["Your own buff, and yours is running out."]
			or L["Your own buff, and you are missing it."]
	elseif entry.reason == "asked" then
		why = L["Asked you for it in chat."]
	elseif left then
		why = entry.reason == "group" and L["In your group, and theirs is running out."]
			or entry.reason == "target" and L["Your target, and theirs is running out."]
			or L["Nearby, and theirs is running out."]
	elseif entry.known == false then
		why = entry.reason == "group" and L["In your group and missing it."]
			or entry.reason == "target" and L["Your target, and missing it."]
			or L["Nearby and missing it."]
	else
		why = entry.reason == "group" and L["In your group."]
			or entry.reason == "target" and L["Your target."]
			or L["Nearby."]
	end
	GameTooltip:AddLine(why, 0.7, 0.7, 0.7, true)
	-- Why they are ahead of the others like them, where Who comes first
	-- put them there. Only ever set for a group member or a passer-by.
	if entry.close == "friend" then
		GameTooltip:AddLine(L["On your friends list."], 0.7, 0.7, 0.7, true)
	elseif entry.close == "guild" then
		GameTooltip:AddLine(L["In your guild."], 0.7, 0.7, 0.7, true)
	end
	-- Why they are ahead of everybody but your target.
	if entry.sweep == "readycheck" then
		GameTooltip:AddLine(L["A ready check was called, so your party or raid comes first until the pull."], 0.7, 0.7, 0.7, true)
	elseif entry.sweep == "revived" then
		GameTooltip:AddLine(L["Just came back from the dead, which costs every buff."], 0.7, 0.7, 0.7, true)
	end
	if left then
		GameTooltip:AddLine(entry.reason == "self" and L["Yours expires in %s."]:format(left)
			or L["Theirs expires in %s."]:format(left), 0.7, 0.7, 0.7, true)
	end
	-- And why the rest of the group is missing from the queue, when it is.
	local kept, resume = ns.SavingMana()
	if kept then
		-- Your own buff among what is kept, where "Myself" is on: this line
		-- may be under your own entry.
		GameTooltip:AddLine((ns.OffersSelf()
			and L["Saving mana: until you are back to %d%% mana, only your own buff and people who buffed you or asked are offered."]
			or L["Saving mana: until you are back to %d%% mana, only people who buffed you or asked are offered."])
			:format(resume), 1, 0.82, 0, true)
	end
	if entry.checked and entry.known == nil then
		GameTooltip:AddLine(L["Buff state unreadable on this build -- they may already have it."],
			1, 0.5, 0.5, true)
	elseif not entry.checked then
		GameTooltip:AddLine(L["Not checking whether they have it -- set by your options."],
			0.7, 0.7, 0.7, true)
	end
end

-- The tooltip's lines about a group cast (GroupBuffs.lua): who it is for, any
-- favour it returns on the way, and the reagent it eats, counted now.
local function GroupTooltipLines(entry, group)
	local single = ns.BuffName(entry.buff)
	local missing, low = group.missing or 0, group.low or 0
	-- Missing and running out apart: "missing" after a wipe means something
	-- different from a top-up before a pull.
	local count
	if group.class then
		count = missing > 0 and L["%d of that class in your party or raid are missing %s."]:format(missing, single)
			or L["%d of that class in your party or raid are running out of %s."]:format(low, single)
	else
		count = missing > 0 and L["%d in %s are missing %s."]:format(missing, group.label or "?", single)
			or L["%d in %s are running out of %s."]:format(low, group.label or "?", single)
	end
	GameTooltip:AddLine(count, 0.7, 0.7, 0.7, true)
	if missing > 0 and low > 0 then
		GameTooltip:AddLine(L["%d more are running out."]:format(low), 0.7, 0.7, 0.7, true)
	end
	GameTooltip:AddLine(group.class
		and L["One cast gives it to %s in your party or raid."]:format(group.label or "?")
		or L["One cast gives it to everybody in %s."]:format(group.label or "?"), 0.7, 0.7, 0.7, true)
	-- Whoever of them buffed you: this cast returns their favour too.
	local now, owedNames = GetTime(), {}
	local function Note(name)
		local debt = name and ns.owed and ns.owed[name]
		if debt and ns.DebtExpiry(debt) > now then owedNames[#owedNames + 1] = ns.ShortName(name) end
	end
	Note(entry.name)
	for _, name in ipairs(group.members) do Note(name) end
	if #owedNames > 0 then
		GameTooltip:AddLine(L["It returns the favour to %s as well."]:format(table.concat(owedNames, ", ")),
			1, 0.78, 0.3, true)
	end
	-- Forever's Reagent Economy: the cast uses none (GroupBuffs.lua).
	if group.reagentWaived then
		GameTooltip:AddLine(L["No reagent needed."], 0.7, 0.7, 0.7, true)
		return
	end
	local have = ns.ReagentCount(group.reagent) or group.reagents
	local item = ns.ReagentName(group.reagent)
	if item then
		GameTooltip:AddLine(L["Uses one %s -- you have %d."]:format(item, have), 0.7, 0.7, 0.7, true)
	else
		GameTooltip:AddLine(L["Uses one reagent -- you have %d."]:format(have), 0.7, 0.7, 0.7, true)
	end
end

-- The button's other scripts, and the list Create() sets them from. A do
-- block, so their names cost the main chunk one local rather than five.
local BUTTON_SCRIPTS
do
	local function OnDragStart(self)
		if ns.db.profile.prompt.locked or InCombatLockdown() then return end
		self:StartMoving()
		dragging = true
	end

	-- Only a drag that started has anything to end: the release arrives for the
	-- refused ones too. A drag still held when a fight starts was ended then
	-- (FinishDragForFight), so one released in combat only forgets itself.
	local function OnDragStop()
		if not dragging then return end
		if InCombatLockdown() then
			dragging = nil
			return
		end
		FinishDrag()
	end

	local function OnEnter(self)
		-- First, whatever the tooltip does: the cursor is on the panel, and
		-- the hold and the fuse wait for it (see hovering). OnUpdate calls
		-- this again only while the tooltip is ours, so still hovering.
		S.hovering = true
		if S.activeLook then S.activeLook:Hover(true) end
		-- Nothing armed is nothing to describe, and a tooltip left from the
		-- last person goes with it.
		if not S.current or not S.current.buff then
			if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
			return
		end
		-- In combat the macro is frozen at whoever it held when the fight
		-- started, and a detailed tooltip about somebody stale is worse than
		-- none.
		if InCombatLockdown() then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Manners")
		GameTooltip:AddDoubleLine(S.current.display or S.current.short or S.current.name,
			ns.EntrySpellName(S.current), 1, 1, 1, 0.8, 0.8, 0.8)
		-- One cast for many says who it covers and what it costs; the one
		-- person's reading is not the story there.
		if S.current.groupCast then
			GroupTooltipLines(S.current, S.current.groupCast)
		else
			PersonTooltipLines(S.current)
		end
		GameTooltip:AddLine(" ")
		-- Plain English first; the raw macro only with /manners clicks, below.
		-- ClickSummary quotes the settled roll.
		for _, line in ipairs(Prompt:ClickSummary(S.current)) do
			GameTooltip:AddLine(line, 0.62, 0.78, 0.62, true)
		end
		GameTooltip:AddLine(" ")
		-- The raw macro is a debugging tool and reads like one, so it goes
		-- where the other debugging tools are. /manners clicks turns it back
		-- on.
		if ns.db.profile.debugClicks and ns.lastMacro then
			GameTooltip:AddLine(L["Will run:"], 0.5, 0.5, 0.5)
			for line in ns.lastMacro:gmatch("[^\r\n]+") do
				GameTooltip:AddLine("  " .. line, 0.4, 0.8, 0.4)
			end
			GameTooltip:AddLine(" ")
		end
		-- The command goes in as an argument, as it does in PreClick's lines:
		-- it is typed in English whatever the client's language.
		GameTooltip:AddLine(L["Click to cast. %s for options."]:format("|cffffd100/manners|r"),
			0.5, 0.5, 0.5)
		-- A gesture nobody can discover is not a feature.
		-- A group cast is skipped whole, and "never" lists only the person it
		-- is aimed at (OnPostClick), which the lines say rather than leave to
		-- a guess.
		local group = S.current.groupCast
		GameTooltip:AddLine(group and L["Right-click to skip this group buff for now."]
			or L["Right-click to skip this one."], 0.5, 0.5, 0.5)
		-- Somebody already on the list is only here because they are owed, and
		-- for them the same press lets that favour go. You never are: your
		-- own name on the list takes your own buff off (Queue.lua).
		if ns.IsNeverOffered and ns.IsNeverOffered(S.current.name) then
			GameTooltip:AddLine(L["Shift-right-click to let this favour go."], 0.5, 0.5, 0.5)
		elseif group then
			GameTooltip:AddLine(L["Shift-right-click to put %s on your never-offer list."]
				:format(S.current.short or S.current.name or "?"), 0.5, 0.5, 0.5)
		elseif S.current.reason == "self" then
			-- The switch, since the list is of other people (StopOfferingSelf).
			GameTooltip:AddLine(L["Shift-right-click to stop offering you your own buff."], 0.5, 0.5, 0.5)
		else
			GameTooltip:AddLine(L["Shift-right-click to put them on your never-offer list."], 0.5, 0.5, 0.5)
		end
		GameTooltip:Show()
	end

	local function OnLeave()
		GameTooltip:Hide()
		if S.activeLook then S.activeLook:Hover(false) end
		-- The hold and the fuse kept their clocks while the cursor was on the
		-- panel, so whatever ran out meanwhile is put right now rather than at
		-- the next scan. Next frame rather than here: the client sends this
		-- as a repaint hides the button, from inside that repaint.
		if not S.hovering then return end
		S.hovering = nil
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function() ns.Guard("leave repaint", Prompt.Refresh, Prompt) end)
		end
	end

	-- Keep the tooltip honest if the entry changes while it is open, checked a
	-- few times a second.
	local function OnUpdate(self, elapsed)
		self.sinceCheck = (self.sinceCheck or 0) + elapsed
		if self.sinceCheck < 0.2 then return end
		self.sinceCheck = 0
		if not GameTooltip:IsOwned(self) then return end
		if not (S.current and S.current.buff) then
			self.tooltipFor = nil
			GameTooltip:Hide()
			return
		end
		-- Keyed on everything the tooltip says, not the name alone: the same
		-- person can move to another buff, become owed, or get a re-rolled
		-- line.
		local shown = table.concat({ S.current.name, S.current.buff.key, tostring(S.current.reason),
			tostring(S.phraseText), tostring(S.appliedKey) }, "\1")
		-- And whether a ready check or a death put them first, and whether
		-- mana is being saved: both come and go while the same person stays
		-- on the panel, since the owed and the asked are never held back.
		shown = shown .. "\1" .. tostring(S.current.sweep) .. "\1" .. tostring((ns.SavingMana()))
		if self.tooltipFor ~= shown then
			self.tooltipFor = shown
			local onEnter = self:GetScript("OnEnter")
			if onEnter then onEnter(self) end
		end
	end

	-- In the order Create() always set them.
	BUTTON_SCRIPTS = {
		{ "OnDragStart", OnDragStart },
		{ "OnDragStop", OnDragStop },
		{ "PreClick", OnPreClick },
		{ "PostClick", OnPostClick },
		{ "OnEnter", OnEnter },
		{ "OnLeave", OnLeave },
		{ "OnUpdate", OnUpdate },
	}
end

-- A drag still held when a fight starts is ended here, from
-- PLAYER_REGEN_DISABLED just before the lockdown: the release will come in the
-- fight, where the move can be neither stopped nor saved.
function Prompt:FinishDragForFight()
	if not dragging or not R.button or InCombatLockdown() then return end
	FinishDrag()
end

lib.BUTTON_SCRIPTS = BUTTON_SCRIPTS
