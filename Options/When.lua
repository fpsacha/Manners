-- Manners -- options: the When to offer tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local F, fGet, fSet = Page.F, Page.fGet, Page.fSet
local HasClassBuffs, HasPrompt, OffersSelf, TAB = Page.HasClassBuffs, Page.HasPrompt, Page.OffersSelf, Page.TAB
local Ref = Page.Ref

-- When to offer, and when the prompt holds back. The favour, timing and
-- targeting controls are defined in Advanced.lua; the options window draws
-- them on this page, under these sections (Options/Window/Layout.lua).
function Page.BuildWhenTab()
	-- A class with no mana bar has nothing to keep: the floor and the line
	-- under it go together. An unknown class (before the probe) shows both.
	-- The floor keeps mana back from other people, and the favours are other
	-- people's too: neither means anything to a class with nothing for them
	-- (a hunter, a shaman), whose prompt is for its own buffs alone.
	local function noManaBar()
		local class = ns.caps and ns.caps.class
		return (class ~= nil and ns.MANA_CLASSES[class] ~= true) or not HasClassBuffs()
	end
	return {
		type = "group",
		name = TAB.when,
		order = 3,
		-- A hunter's prompt too, for his own buffs: the mount is still where
		-- it is hidden (the launcher and a press on a hidden prompt send him
		-- here), and a shaman's Lightning Shield is topped up from here.
		hidden = function() return not HasPrompt() end,
		args = {
			-- Who the prompt is on right now (Shared.lua).
			rightNow = Page.RightNowNote(0.5),
			-- About other people, which a class with nothing for them (a
			-- hunter) has none of: its choice there is about its own buffs.
			buffedHeader = {
				type = "header",
				name = function() return HasClassBuffs() and L["Other people already buffed"] or L["Already buffed"] end,
				order = 1,
			},
			whenBuffed = {
				type = "select",
				name = L["If they already have it"],
				-- The favour exception is said here because none of the
				-- three choices touches it: BuildQueue offers a debt
				-- regardless of this setting. For a class with nothing for
				-- anybody else, what the choice does to its own buffs.
				desc = function()
					if not HasClassBuffs() then
						return L["Your own buffs are offered when none is up; with Offer a top-up when it runs low, also when one is running out (never an aura or an aspect)."]
					end
					return L["Someone who buffed you is always offered a buff back; Diagnostics shows which buffs Manners can see on others."]
				end,
				order = 2,
				width = "full",
				values = {
					skip = L["Skip them (default)"],
					refresh = L["Offer a top-up when it runs low"],
					always = L["Always offer (costs a lot of mana)"],
				},
				-- Least to most mana, rather than the alphabet's order.
				sorting = { "skip", "refresh", "always" },
				get = fGet,
				set = fSet,
			},
			refreshUnder = {
				type = "range",
				name = L["Top up at most this many minutes early"],
				-- How the moment is worked out, then the favour exception:
				-- a timer that cannot be read holds back a top-up, never a
				-- buff owed.
				desc = L["The moment is worked out from how long the buff lasts: about a tenth of it, so ten minutes means one minute before it ends and an hour five. This is the most it will ever take."]
					.. " " .. L["Someone whose time left cannot be read is not offered a top-up, unless they buffed you."],
				order = 3,
				min = 1,
				max = 60,
				step = 1,
				hidden = function() return F().whenBuffed ~= "refresh" end,
				get = fGet,
				set = fSet,
			},
			refreshRaid = {
				type = "range",
				name = L["In a raid or dungeon, top up this many times earlier"],
				desc = L["A fight and the drinking after it take minutes, so in a raid or a dungeon a top-up is offered this many times earlier. Your own buffs are offered half as early again, and people outside your group only in the last half minute."],
				order = 3.5,
				min = 1,
				max = 4,
				step = 0.5,
				hidden = function() return F().whenBuffed ~= "refresh" end,
				get = fGet,
				set = fSet,
			},
			-- Yours are topped up whatever the choice above says for other
			-- people (ns.SelfWhenBuffed), so these two are never hidden by it,
			-- and sit under a heading of their own.
			selfHeader = { type = "header", name = L["My own buffs"], order = 6 },
			selfTopUp = {
				type = "toggle",
				name = L["Top up my own buffs before they run out"],
				desc = L["Your own buffs, and the ones you put on yourself, are offered again shortly before they end, whatever If they already have it says for other people."],
				order = 6.1,
				width = "full",
				get = fGet,
				set = fSet,
			},
			selfLead = {
				type = "range",
				name = L["Remind me this many minutes early"],
				desc = L["0 works it out from how long the buff lasts: a little more than a tenth of it, and twice that in a dungeon or raid. Set a time to be reminded exactly that long before your own buffs end, in a dungeon or raid too: 0.5 is half a minute. Never more than half the buff's length."],
				order = 6.2,
				min = 0,
				max = 10,
				step = 0.5,
				disabled = function() return not F().selfTopUp and F().whenBuffed ~= "refresh" end,
				get = fGet,
				set = fSet,
			},
			-- What the slider's 0 means, under it while it is there.
			selfLeadNote = {
				type = "description",
				order = 6.3,
				hidden = function() return (tonumber(F().selfLead) or 0) ~= 0 end,
				name = "|cff888888" .. L["0: worked out from how long each buff lasts."] .. "|r",
			},
			alwaysNote = {
				type = "description",
				order = 4,
				-- About offers to other people, which a hunter makes none of.
				hidden = function() return F().whenBuffed ~= "always" or not HasClassBuffs() end,
				-- The second sentence is a setting on another tab going
				-- quiet. A target is promoted only on a reading that they
				-- lack the buff, and this mode takes no readings.
				name = function()
					return "|cffff8080"
						.. L["Everyone you offer to is offered again and again, even with a fresh buff."]
						.. "|r\n\n|cff888888"
						.. L["%s does nothing in this mode."]:format(Ref(L["My target first"], TAB.who))
						.. "|r"
				end,
			},
			-- Somebody whose buffs the client will not show is offered
			-- "unverified" (Queue.lua, UNVERIFIED_SECONDS); this offers them
			-- never. Always offer reads nothing, so nothing is refused there,
			-- and a class with nothing for anybody else is only offered its
			-- own buffs, which are always read.
			verifiedOnly = {
				type = "toggle",
				name = L["Don't offer when the game hides their buffs (fights)"],
				desc = L["In a fight, and sometimes just after, the game hides other players' buffs: Manners cannot tell then whether they already have yours, and offers it marked \"unverified\". Tick this to never offer it then. Someone who buffed you or asked for a buff is still offered."],
				order = 5,
				width = "full",
				hidden = function() return F().whenBuffed == "always" or not HasClassBuffs() end,
				get = fGet,
				set = fSet,
			},

			-- Only the mount has a switch: dead, a taxi and a vehicle are
			-- places nothing can be cast from, while a cast from a mount
			-- works and costs you the mount, a trade some players want.
			wayHeader = { type = "header", name = L["Hold back"], order = 10 },
			hideMounted = {
				type = "toggle",
				name = L["Hide the prompt while I'm mounted"],
				desc = L["Casting would dismount you; it is always hidden while dead, on a flight path or in a vehicle."],
				order = 11,
				width = "full",
				get = fGet,
				set = fSet,
			},
			manaFloor = {
				type = "range",
				name = L["Save mana: stop below (% mana)"],
				-- What is still offered under it, by the choice below it
				-- (ns.ManaFloorKept): the two kinds that asked, and your own
				-- buff (Queue.lua, SelfEntry) wherever "Myself" is on; your own
				-- buff alone; or nothing.
				desc = function()
					local kept = ns.ManaFloorKept()
					if kept == "askedself" then
						return L["Below this, only your own buff and people who buffed you or asked are offered."]
					elseif kept == "asked" then
						return L["Below this, only people who buffed you or asked are offered."]
					elseif kept == "self" then
						return L["Below this, only your own buff is offered."]
					end
					return L["Below this, nothing is offered."]
				end,
				order = 13,
				min = 0,
				max = 90,
				step = 5,
				hidden = noManaBar,
				get = fGet,
				set = fSet,
			},
			-- What the floor still lets through (asked for on CurseForge: on
			-- WoW Forever most offers are favours, so a floor that kept them
			-- cast the mana away all the same). Read by BuildQueue
			-- (ns.ManaFloorKeeps); a favour held back stays owed and waits.
			-- Greyed while the floor is off, as Where is under its switch.
			manaFloorKeeps = {
				type = "select",
				name = L["Below it, still offer"],
				desc = L["Who is still offered while you are under the floor. Someone who buffed you and is held back stays owed, and is offered once your mana is back."],
				order = 13.2,
				values = {
					asked = L["People who buffed me or asked"],
					self = L["Only my own buff"],
					none = L["Nothing"],
				},
				sorting = { "asked", "self", "none" },
				hidden = noManaBar,
				disabled = function() return not ((tonumber(F().manaFloor) or 0) > 0) end,
				get = fGet,
				set = fSet,
			},
			-- What the floor does at its current value, said under it: off
			-- at 0, otherwise where it stops, what it still offers (the
			-- choice above, ns.ManaFloorKept) and where the rest resume
			-- (SavingMana lets go 5 points above the floor).
			manaNote = {
				type = "description",
				order = 13.5,
				hidden = noManaBar,
				name = function()
					local floor = tonumber(F().manaFloor) or 0
					local kept = ns.ManaFloorKept()
					local text
					if floor <= 0 then
						text = L["Off: buffs are offered at any mana."]
					elseif kept == "askedself" then
						-- Your own buff is kept as well (see the slider's desc).
						text = L["Below %d%% only favours, requests and your own buff are offered; the rest come back at %d%%."]
							:format(floor, floor + 5)
					elseif kept == "asked" then
						text = L["Below %d%% only favours and requests are offered; the rest come back at %d%%."]
							:format(floor, floor + 5)
					elseif kept == "self" then
						text = L["Below %d%% only your own buff is offered; the rest come back at %d%%."]
							:format(floor, floor + 5)
					else
						text = L["Below %d%% nothing is offered; it all comes back at %d%%."]
							:format(floor, floor + 5)
					end
					return "|cff888888" .. text .. "|r"
				end,
			},
		},
	}
end
