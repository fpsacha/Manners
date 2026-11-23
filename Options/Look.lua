-- Manners -- options: the Look tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local restyle, P, S, SND, pGet = Page.restyle, Page.P, Page.S, Page.SND, Page.pGet
local pSet, pGetColor, pSetColor, HasClassBuffs = Page.pSet, Page.pGetColor, Page.pSetColor, Page.HasClassBuffs
local HasPrompt, TAB = Page.HasPrompt, Page.TAB

local LSM = LibStub("LibSharedMedia-3.0")

-- Redraw the page once a run of slider ticks has stopped, for the Width and
-- Height sliders, which shrink the icon and so change the Icon size slider.
-- The dialog redraws on letting go of a drag, but a mouse wheel never lets go.
-- Held back because a redraw rebuilds the slider under the pointer; the token
-- is there because C_Timer.After cannot be cancelled.
local repaintToken = 0
local function RepaintSoon()
	repaintToken = repaintToken + 1
	local mine = repaintToken
	C_Timer.After(0.3, function()
		if mine == repaintToken and ns.RefreshOptionsDisplay then
			ns.Guard("icon repaint", ns.RefreshOptionsDisplay)
		end
	end)
end

-- Which of the two things that can carry the reason colour is actually on
-- screen (the bezel round the icon, the stripe). The bezel is drawn round the
-- icon, square or round, so hiding the icon takes it away; the stripe is on
-- every look drawn by Prompt/Panel.lua (the framed look's rim leaves it room).
local function AccentCarriers()
	local p = P()
	-- A look from Looks/ says where it carries the colour; nothing said is
	-- both.
	local look = ns.Looks.Get(p.style)
	if look then
		if not look.AccentCarriers then return true, true end
		local ring, stripe = look.AccentCarriers(p)
		return ring == true, stripe == true
	end
	local mode = p.accentMode or "icon"
	local ring = (mode == "icon" or mode == "both") and p.showIcon
	local stripe = (mode == "stripe" or mode == "both")
	return ring == true, stripe == true
end

-- Whether the marker colour has nowhere left to go: accentDead shows on it and
-- the page's red dot reads it. "Off" is excluded: that is somebody asking for
-- no accent, and a warning about getting what you asked for is noise.
local function AccentDead()
	if (P().accentMode or "icon") == "off" then return false end
	local ring, stripe = AccentCarriers()
	return not (ring or stripe)
end
Page.AccentDead = AccentDead

-- The icon's size on a look that sizes it itself (Toast, from the height), or
-- nil where the slider sets it.
local function LookIconSize()
	local p = P()
	local look = ns.Looks.Get(p.style)
	return look and look.IconSize and look.IconSize(p) or nil
end

-- How the prompt looks, where it sits and how it gets your attention.
function Page.BuildLookTab()
	local tab = {
		type = "group",
		name = TAB.appearance,
		order = 5,
		-- Who to buff, Who to skip and When to offer already go for a
		-- character with no prompt; a rogue has nothing here to look at or
		-- preview either. Someone styling a shared profile does it from a
		-- character that has one. The Will of the Forsaken and Mend Pet
		-- switches and their keys are the exception, kept below: a Forsaken
		-- rogue, or a hunter who knows Mend Pet, gets those buttons with no
		-- prompt, so their switches must be reachable.
		hidden = function()
			return not HasPrompt() and ns.caps.breakFree == nil
				and not (ns.Beast and ns.Beast.IsHunter() and ns.Beast.KnowsMend())
		end,
		args = {
			-- Everything on this tab is a secure attribute or a texture
			-- on a secure frame, and ApplyStyle returns at once in combat;
			-- the values are kept and flushed when the fight ends.
			combatNotice = {
				type = "description",
				order = 0.5,
				fontSize = "medium",
				hidden = function() return not InCombatLockdown() end,
				name = "|cffffd100" .. L["In combat: changes here show once the fight ends."] .. "|r\n",
			},
			-- The same line for In a fight (layout.lua counts a strip path as a
			-- placement, so the page needs an entry of its own). Only the
			-- window reads it, from the strip: the fallback dialog already has
			-- the line above, so this copy stays out of it.
			fightCombatNotice = {
				type = "description",
				order = 0.51,
				fontSize = "medium",
				hidden = function() return not InCombatLockdown() or not (ns.WindowUI and ns.WindowUI.Shown and ns.WindowUI.Shown()) end,
				name = "|cffffd100" .. L["In combat: changes here show once the fight ends."] .. "|r\n",
			},
			-- The preview is general.previewStart, which the options window
			-- draws in its header, so it is one press from every page.
			-- Moving the prompt leads the page as a button, the same one the
			-- header has (general.moveToggle); the window does not draw Lock
			-- position below it, since the button reads that state.
			move = Page.MoveControl(1),
			locked = {
				type = "toggle",
				name = L["Lock position"],
				desc = L["Unlock to drag the prompt; it will not cast until you lock it again."],
				order = 2,
				get = pGet,
				-- Its own setter, like /manners unlock: the prompt is hidden
				-- by `enabled` before `locked` is read, so unlocking while
				-- off leaves nothing on screen to drag.
				set = function(info, value)
					pSet(info, value)
					if not value and not ns.db.profile.enabled then
						ns.addon:Print(L["unlocked, but the addon is |cffff8080off|r so there is no prompt to drag -- switch it on first."])
					end
				end,
			},
			-- Edit Mode is where the game's own frames are moved, and where
			-- people look for the prompt's place (Prompt/Button.lua, "Edit
			-- Mode"). Not shown on a client without one.
			moveInEditMode = {
				type = "toggle",
				name = L["Move it in Edit Mode"],
				desc = L["While the game's Edit Mode is open the prompt is unlocked, so you can drag it there with everything else. It casts nothing meanwhile and locks again when Edit Mode closes."],
				order = 3.5,
				width = "full",
				hidden = function() return not ns.HasEditMode() end,
				get = pGet,
				set = pSet,
			},
			-- Moving the prompt otherwise means unlock, find it, drag it,
			-- lock it -- four steps and a mode you can forget you are in,
			-- because an unlocked prompt is also one that will not cast.
			-- The default place is on the list, so it doubles as the reset.
			-- The exact numbers are a fold on the same page, so the tooltip
			-- points nowhere.
			posPreset = {
				type = "select",
				name = L["Where it sits"],
				desc = L["Pick Above the action bars to put it back where it started."]
					.. " " .. L["Dragging the prompt afterwards sets this to Where I dragged it."],
				order = 3,
				-- "custom" only while the prompt is on none of the presets,
				-- so it can be shown but never picked.
				values = function()
					local out = {}
					for _, preset in ipairs(ns.POSITION_PRESETS) do
						out[preset.key] = preset.key == "bars"
							and L["Above the action bars (default)"] or preset.name
					end
					if not ns.CurrentPositionPreset() then out.custom = L["Where I dragged it"] end
					return out
				end,
				-- The list has a meaning order -- top of the screen to
				-- bottom -- and a dropdown sorted alphabetically loses it.
				sorting = function()
					local out = {}
					for i, preset in ipairs(ns.POSITION_PRESETS) do out[i] = preset.key end
					if not ns.CurrentPositionPreset() then out[#out + 1] = "custom" end
					return out
				end,
				get = function() return ns.CurrentPositionPreset() or "custom" end,
				set = function(_, value)
					if value ~= "custom" then ns.ApplyPositionPreset(value) end
				end,
			},

			posHeader = { type = "header", name = L["Size"], order = 10 },
			scale = { type = "range", name = L["Scale"], order = 11, min = 0.5, max = 3, step = 0.05, get = pGet, set = pSet },
			alpha = { type = "range", name = L["Opacity"], order = 12, min = 0.1, max = 1, step = 0.05, isPercent = true, get = pGet, set = pSet },
			width = {
				type = "range",
				name = L["Width"],
				order = 13,
				min = 80,
				max = 500,
				step = 1,
				get = pGet,
				-- The same setter the height has: the icon is bound by the
				-- width as well.
				set = function(info, value)
					local icon = P().iconSize
					pSet(info, value)
					ns.ClampSettings()
					restyle()
					if P().iconSize ~= icon then RepaintSoon() end
				end,
			},
			height = {
				type = "range",
				name = L["Height"],
				order = 14,
				min = 20,
				max = 120,
				step = 1,
				get = pGet,
				-- Its own setter because the icon's maximum is bound to
				-- this: ClampSettings shrinks the icon, and RepaintSoon
				-- redraws its slider.
				set = function(info, value)
					local icon = P().iconSize
					pSet(info, value)
					ns.ClampSettings()
					restyle()
					if P().iconSize ~= icon then RepaintSoon() end
				end,
			},

			styleHeader = { type = "header", name = L["Style"], order = 20 },
			-- Use my class's look on each character (Looks/Looks.lua, ONE LOOK A
			-- CLASS): drawn over the cards (Layout.lua, appearance.themes).
			classLook = {
				type = "toggle",
				name = L["Use my class's look on each character"],
				desc = L["Each character on this profile wears the look made for its class: a druid the Druid look, a paladin the Paladin look. Where a class has several, as a mage does, it wears the one you last clicked on that class, else the first. Any other look you click becomes this profile's own, which every character wears with this off."],
				order = 20.5,
				width = "full",
				get = pGet,
				set = function(_, value)
					ns.Looks.SetClassLook(P(), value == true)
					restyle()
				end,
			},
			style = {
				type = "select",
				name = L["Panel style"],
				-- The window draws this as a gallery of cards (Layout.lua,
				-- Options/Window/WidgetsTheme.lua), which shows no description of
				-- its own for the row (the cards carry each look's) and only
				-- searches this one; the dropdown is what the fallback dialog
				-- draws, and where this is read, so it speaks of a list.
				desc = L["Pick a theme for the prompt from the list. It switches at once."],
				order = 21,
				-- Every look, the three Prompt/Panel.lua draws and the ones in
				-- Looks/, from the registry, in its order; profiles holding
				-- framed's old name are carried across in ClampSettings.
				values = (ns.Looks.Choices()),
				sorting = select(2, ns.Looks.Choices()),
				get = pGet,
				-- With Use my class's look on each character on, a look of this
				-- class's is its pick and any other the profile's own (Looks.Pick).
				set = function(_, value)
					ns.Looks.Pick(P(), value)
					restyle()
				end,
			},
			-- The window's heading over the settings that go with the look
			-- chosen (Layout.lua, appearance.lookOwn), naming it: Earlier art,
			-- the key, the round icon, the gryphons and the reason's colours.
			lookHeader = {
				type = "header",
				name = function()
					return L["%s: its settings"]:format((ns.Looks.Card(P().style or "glass")))
				end,
				order = 21.2,
			},
			-- The looks repainted from a painting (Looks/Painted.lua) drawn with
			-- the art they had before, for whoever liked that better. Shown with a
			-- look that has such an art; it draws every one of them so.
			classicArt = {
				type = "toggle",
				name = L["Earlier art"],
				desc = L["Draws every look with the art it had before it was repainted. Off, a repainted look wears its new painted frame."],
				order = 21.5,
				width = "full",
				hidden = function() return not ns.Looks.HasEarlierArt(P().style) end,
				get = pGet,
				set = pSet,
			},
			-- What it does, in a line of its own under it: the tooltip alone was
			-- not found, and the switch changes every repainted look at once.
			classicArtNote = {
				type = "description",
				order = 21.55,
				fontSize = "small",
				hidden = function() return not ns.Looks.HasEarlierArt(P().style) end,
				name = L["Draws every look with the art it had before it was repainted. Off, a repainted look wears its new painted frame."],
			},
			-- The key bound to the prompt, on the painted keycap (and on a look's
			-- own key tag): as the look has it, or always, or never. With no key
			-- bound nothing is shown there whatever this says. Shown with a look
			-- that draws a key at all, its first choice saying what the look does.
			keycap = {
				type = "select",
				name = L["Show my key on the prompt"],
				desc = L["Whether the key you press for the prompt is shown on it. As the look has it: on the class and themed looks, not on the calmer ones. Nothing is shown while no key is bound."],
				order = 21.6,
				hidden = function() return not ns.Looks.DrawsKey(P().style) end,
				values = function()
					return {
						look = ns.Looks.KeyDefault(P().style) and L["As the look has it (shown)"] or L["As the look has it (hidden)"],
						show = L["Always"],
						hide = L["Never"],
					}
				end,
				sorting = { "look", "show", "hide" },
				get = pGet,
				set = pSet,
			},
			bgColor = {
				type = "color",
				name = L["Panel colour"],
				order = 22,
				hasAlpha = true,
				disabled = function() return P().style == "minimal" end,
				get = pGetColor,
				set = pSetColor,
			},
			accentByReason = {
				type = "toggle",
				name = L["Colour by why they are offered"],
				-- All five reasons, in the order the queue ranks them, in
				-- the chosen palette's colours.
				desc = function()
					local colours = P().reasonPalette == "colourblind"
						and L["Pale yellow for your own target, orange for a favour owed, deep pink for somebody who asked, sky blue for your group, violet for passers-by -- the order they are offered in."]
						or L["Pale blue for your own target, amber for a favour owed, pink for somebody who asked, deeper blue for your group, grey for passers-by -- the order they are offered in."]
					return L["A colour that shows why this person is on the prompt."] .. "\n\n" .. colours
				end,
				order = 23,
				width = "full",
				get = pGet,
				set = pSet,
			},
			-- Which colours, for somebody the standard set fails.
			-- Greyed out only where nothing is drawn in the reason
			-- colours: the list's bars, the glow and the wash of a press
			-- take the palette whatever the marker says.
			reasonPalette = {
				type = "select",
				name = L["Colour set"],
				-- Names no hues and counts none: Colour marker by reason
				-- names them. Every reason has a colour of its own in both
				-- sets, and hunt5-options.lua holds this sentence to that.
				desc = L["The colour-blind set keeps the reasons apart for red-green colour blindness, in colours that differ in lightness too."],
				order = 24,
				values = {
					standard = L["Standard"],
					colourblind = L["Colour-blind friendly"],
				},
				sorting = { "standard", "colourblind" },
				disabled = function()
					local p = P()
					return not p.accentByReason and not p.showQueue
				end,
				-- Whatever a hand-edited file holds, the dropdown shows
				-- the palette the prompt is actually drawn with.
				get = function() return P().reasonPalette == "colourblind" and "colourblind" or "standard" end,
				set = pSet,
			},
			-- Hidden rather than greyed out: with the colour by reason on,
			-- this picker has no say at all.
			accentColor = {
				type = "color",
				name = L["Colour to use otherwise"],
				desc = L["Used when Colour by why they are offered is off."],
				order = 25,
				hasAlpha = true,
				hidden = function() return P().accentByReason end,
				get = pGetColor,
				set = pSetColor,
			},
			accentMode = {
				type = "select",
				name = L["Put the colour on"],
				desc = L["Where the reason's colour is drawn."],
				order = 26,
				values = {
					icon = L["Ring around the icon"],
					stripe = L["Stripe on the left edge"],
					both = L["Both"],
					off = L["None"],
				},
				sorting = { "icon", "stripe", "both", "off" },
				get = pGet,
				set = pSet,
			},
			-- Shown only when the colour above has nowhere left to go.
			accentDead = {
				type = "description",
				order = 26.5,
				hidden = function() return not AccentDead() end,
				-- Only one thing can leave the colour with nowhere to go now:
				-- the icon switched off while the colour goes on the icon. Every
				-- look draws its stripe, and the bezel stays round a rounded
				-- icon. The setting is named as its label reads.
				name = function()
					local p = P()
					local mode = p.accentMode or "icon"
					if (mode == "icon" or mode == "both") and not p.showIcon then
						return "|cffffd100" .. L["There is nothing left to colour: %s puts it on the icon, which is switched off."]
							:format(L["Put the colour on"]) .. "|r"
					end
					-- Nothing was lost, so the notice is hidden and has
					-- nothing to say.
					return ""
				end,
			},

			-- The flash and the sound are one job, kept together so they
			-- agree about who is worth interrupting for.
			attentionHeader = { type = "header", name = L["Getting my attention"], order = 30 },
			flashStyle = {
				type = "select",
				name = L["Flash when someone buffs me"],
				desc = L["Needs the spell icon, the colour marker or Full animations."],
				order = 31,
				hidden = function() return not HasClassBuffs() end,
				-- The glow lives on the icon, the sweep on the stripe and
				-- the glint on arrival runs the panel's rules (Minimal's
				-- too); with none of them this does nothing, and a live
				-- control would read as broken.
				disabled = function()
					local _, stripe = AccentCarriers()
					return not P().showIcon and not stripe and P().effects == "calm"
				end,
				values = {
					pulse = L["Pulse until I buff them back"],
					once = L["Flash once"],
					off = L["None"],
				},
				sorting = { "pulse", "once", "off" },
				get = pGet,
				set = pSet,
			},
			-- How much the prompt moves to get your attention, so next to
			-- the flash.
			effects = {
				type = "select",
				name = L["Animations"],
				desc = L["Calm only fades in and out: no sweeps of light, rings, waves, cracks or shaking."],
				order = 32,
				values = {
					full = L["Full"],
					calm = L["Calm (less movement)"],
				},
				sorting = { "full", "calm" },
				get = pGet,
				set = pSet,
			},
			-- The prompt off the screen for a fight, the player's ask. Not a
			-- visibility driver alone: a hidden secure button still fires from
			-- its key binding and /click, and the bar macro casts by its own
			-- lines. Prompt/Fight.lua hides it from a secure snippet that first
			-- takes the macro off the prompt and its list, and only once the
			-- pull has left the bar macro holding no cast. Its own key: the
			-- old "hideInCombat" below means the flashes, and keeps meaning
			-- them for everybody who set it.
			hideInFight = {
				type = "toggle",
				name = L["Hide the prompt in a fight"],
				desc = function()
					local text = L["Off the screen for the whole fight, and nothing casts from it meanwhile: not its key, not a name in its list, not the Manners macro on your bar. It comes back when the fight ends. A change made in a fight counts from the next one."]
					if ns.FightKey and ns.FightKey.Chosen() then text = text .. " " .. L["While In a fight, my key casts names a spell, the prompt's key casts that spell in a fight instead."] end
					return text
				end,
				order = 32.4,
				width = "full",
				get = pGet,
				set = pSet,
			},
			-- The fight's rota (Prompt/Fight.lua): the prompt left up steps
			-- through the people the fight began with, a press each. Nothing to
			-- step with the prompt hidden for the fight.
			fightRota = {
				type = "toggle",
				name = L["In a fight, each press buffs the next person in line"],
				desc = function()
					local text = L["A fight locks the prompt, so Manners hands it everybody who still needed a buff as the fight began, and each press of the prompt or its key casts at the next of them in turn. Off, every press in a fight casts at the one person the prompt was on. The Manners macro on an action bar keeps to that one person either way."]
					if ns.FightKey and ns.FightKey.Chosen() then text = text .. " " .. L["While In a fight, my key casts names a spell, the prompt's key casts that spell in a fight instead."] end
					return text
				end,
				order = 32.45,
				width = "full",
				disabled = function() return P().hideInFight == true end,
				get = pGet,
				set = pSet,
			},
			-- The prompt's own key casting a spell of the player's choosing in a
			-- fight (Prompt/FightKey.lua): an override binding taken at the pull
			-- and given back at the end; nothing extra on the screen.
			fightKeySpell = {
				type = "select",
				name = L["In a fight, my key casts"],
				desc = function()
					local text = L["The prompt's key buffs out of a fight. Pick a spell here and the same key casts it in a fight instead, for as long as the fight lasts; nothing extra appears on screen. Clicking the prompt still buffs. Only spells you know are listed. It needs a key for the prompt, and the Manners macro on an action bar keeps to buffs. A change made in a fight counts from the next one."]
					if not ns.caps.conditionalTargeting then
						text = text .. " " .. L["A spell you can cast on others lands on your target when it is a friend, else on you."]
					end
					return text
				end,
				order = 32.455,
				width = "full",
				hidden = function() return #ns.FightKey.Choices() <= 1 end,
				values = function()
					local out = {}
					for _, entry in ipairs(ns.FightKey.Choices()) do
						out[entry.key] = entry.key == "none" and L["Nothing (keep to buffs)"] or entry.name
					end
					return out
				end,
				sorting = function()
					local out = {}
					for _, entry in ipairs(ns.FightKey.Choices()) do out[#out + 1] = entry.key end
					return out
				end,
				-- Kept per class: the profile is shared by every character.
				get = function() return ns.FightKey.Value() end,
				set = function(_, value)
					ns.FightKey.Set(nil, value)
					ns.Guard("fight key", ns.FightKey.Refresh, ns.FightKey)
				end,
			},
			fightKeyOn = {
				type = "select",
				name = L["Cast it on"],
				desc = L["For a spell you can cast on others. A spell only for yourself always lands on you."],
				order = 32.456,
				hidden = function()
					if not ns.caps.conditionalTargeting then return true end
					local row = ns.FightKey.Chosen()
					return row == nil or row.self == true
				end,
				values = {
					friend = L["Whoever is under my mouse, else my target, else me"],
					me = L["Me"],
				},
				sorting = { "friend", "me" },
				get = pGet,
				set = function(info, value)
					pSet(info, value)
					ns.Guard("fight key", ns.FightKey.Refresh, ns.FightKey)
				end,
			},
			-- Breaking free in a fight (Prompt/BreakFree.lua): a Forsaken's
			-- Will of the Forsaken on a button of its own beside the prompt,
			-- with a key of its own. Never shown to a character without the
			-- ability (the probe's caps.breakFree). Live whatever Hide the
			-- prompt in combat says: the button is not the prompt.
			breakFree = {
				type = "toggle",
				name = L["Show a Will of the Forsaken button when I am feared, charmed or asleep"],
				desc = L["A button of its own beside the prompt, with its own key. It shows while you are feared, charmed or asleep, and whenever you lose control of your character in a fight where the game will not say what took it: lit when the spell is ready, dim while it cools down. Show the fight buttons can keep it there, dim, all fight. A change made in a fight counts from the next one."],
				order = 32.46,
				width = "full",
				hidden = function() return ns.caps.breakFree == nil end,
				get = pGet,
				set = function(info, value)
					pSet(info, value)
					if ns.BreakFree then ns.Guard("break free", ns.BreakFree.Refresh, ns.BreakFree) end
				end,
			},
			-- Its key, the game's binding as the prompt's is (Options/Start.lua,
			-- Setup), saved with the binding set; under the switch.
			breakFreeKey = {
				type = "keybinding",
				name = L["Key for Will of the Forsaken"],
				desc = L["Saved with your game key bindings, so it works on every profile."],
				order = 32.47,
				hidden = function()
					return ns.caps.breakFree == nil or P().breakFree == false or not ns.Setup.CanBind()
				end,
				-- SetBinding is refused in a fight.
				disabled = function() return InCombatLockdown() end,
				get = function() return ns.Setup.Key(ns.BreakFree.COMMAND) or "" end,
				set = function(_, value)
					local spell = ns.caps.breakFree and ns.caps.breakFree.name or ""
					ns.Setup.SetKey(value, ns.BreakFree.COMMAND, function(key, was)
						return L["%s was bound to %s; it now casts %s."]:format(key, was, spell)
					end)
					if ns.BreakFree then ns.Guard("break free", ns.BreakFree.Refresh, ns.BreakFree) end
				end,
			},
			-- Mend Pet in a fight (Prompt/MendPet.lua): a hunter's button of
			-- its own, as Will of the Forsaken's is, with a key of its own.
			-- Shown to a hunter who knows Mend Pet; held by the master under
			-- Who to buff > Myself.
			mendInFight = {
				type = "toggle",
				name = L["Show a Mend Pet button in a fight when my pet is badly hurt"],
				desc = L["A button of its own beside the prompt, with its own key. It shows while your pet is under half health, in reach, and Mend Pet is ready. Where the game hides your pet's health in a fight, it shows only with Show the fight buttons set to All fight; its key works either way. A change made in a fight counts from the next one."],
				order = 32.48,
				width = "full",
				hidden = function() return not (ns.Beast and ns.Beast.IsHunter() and ns.Beast.KnowsMend()) end,
				disabled = function() return ns.db.profile.beast.all == false end,
				get = function() return ns.db.profile.beast.fightMend ~= false end,
				set = function(_, value)
					ns.db.profile.beast.fightMend = value == true
					if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
				end,
			},
			mendInFightKey = {
				type = "keybinding",
				name = L["Key for Mend Pet"],
				desc = L["Saved with your game key bindings, so it works on every profile."],
				order = 32.49,
				hidden = function()
					return not (ns.Beast and ns.Beast.IsHunter() and ns.Beast.KnowsMend())
						or ns.db.profile.beast.fightMend == false or not ns.Setup.CanBind()
				end,
				disabled = function() return InCombatLockdown() end,
				get = function() return ns.Setup.Key(ns.MendPet.COMMAND) or "" end,
				set = function(_, value)
					ns.Setup.SetKey(value, ns.MendPet.COMMAND, function(key, was)
						return L["%s was bound to %s; it now casts %s."]:format(key, was, ns.Beast.MendName() or "")
					end)
					if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
				end,
			},
			-- When the Will of the Forsaken and Mend Pet buttons show in a fight
			-- (Prompt/BreakFree.lua, Prompt/MendPet.lua): out of sight until
			-- there is a need, or dim for the whole fight. One setting for both;
			-- each switch above still decides whether its button exists at all.
			-- The cure button below keeps its own rule.
			fightButtons = {
				type = "select",
				name = L["Show the fight buttons"],
				desc = L["For the Will of the Forsaken and Mend Pet buttons. Only when needed: a button appears when you need it and fades after; its key casts it, and a click too when no key is set. All fight: it sits dim beside the prompt for the whole fight, lights up when needed and takes a click. Where the game hides your pet's health in a fight, only All fight shows the Mend Pet button."],
				order = 32.4905,
				values = { needed = L["Only when needed"], always = L["All fight, dim until needed"] },
				sorting = { "needed", "always" },
				hidden = function()
					return ns.caps.breakFree == nil and not (ns.Beast and ns.Beast.IsHunter() and ns.Beast.KnowsMend())
				end,
				disabled = function()
					local bf = ns.caps.breakFree ~= nil and P().breakFree ~= false
					local mp = ns.Beast and ns.Beast.IsHunter() and ns.Beast.KnowsMend()
						and ns.db.profile.beast.all ~= false and ns.db.profile.beast.fightMend ~= false
					return not (bf or mp)
				end,
				get = pGet,
				set = function(info, value)
					pSet(info, value)
					if ns.BreakFree then ns.Guard("break free", ns.BreakFree.Refresh, ns.BreakFree) end
					if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
				end,
			},
			-- Your cure in a fight (Prompt/CureFight.lua): a button of its own
			-- that is out of sight until Manners sees somebody near you it can
			-- cure, with a key of its own. Shown to a class with a cure.
			cureFight = {
				type = "toggle",
				name = L["Show my cure on a button in a fight, only while somebody needs it"],
				desc = function()
					if ns.caps.conditionalTargeting then
						return L["A button of its own, right of the prompt, that appears only while you, your target or somebody in your group carries a poison, disease, curse or harmful magic your class can remove, and says who. Its key is Key for my cure in a fight, below, also in the game's Key Bindings under Manners. A press cures whoever is under your mouse, else your target, else you. Where the game hides debuffs in a fight, it still appears when the game says you can remove one, without naming the kind. A change made in a fight counts from the next one."]
					end
					return L["A button of its own, right of the prompt, that appears only while you, your target or somebody in your group carries a poison, disease, curse or harmful magic your class can remove, and says who. Its key is Key for my cure in a fight, below, also in the game's Key Bindings under Manners. A press cures your target when it is a friend, else you. Where the game hides debuffs in a fight, it still appears when the game says you can remove one, without naming the kind. A change made in a fight counts from the next one."]
				end,
				order = 32.491,
				width = "full",
				hidden = function() return not (ns.ClassHasCures() and ns.CureLearned()) end,
				get = pGet,
				set = function(info, value)
					pSet(info, value)
					if ns.CureFight then ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight) end
				end,
			},
			-- A class with two cures: a button and a key for each
			-- (Prompt/CureFight.lua). Off: one button, Shift casts the second.
			cureFightEach = {
				type = "toggle",
				name = L["A button for each cure"],
				desc = L["For a class with two cures, such as a druid's Remove Curse and Cure Poison: each cure gets a button and a key of its own, and appears only for the debuff it removes. Off: one button, and Shift casts the second cure."],
				order = 32.4915,
				width = "full",
				hidden = function()
					if not (ns.ClassHasCures() and ns.CureLearned()) or P().cureFight ~= true then return true end
					local list = ns.CureFightSpells()
					return not (list and list[2])
				end,
				get = pGet,
				set = function(info, value)
					pSet(info, value)
					if ns.CureFight then ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight) end
				end,
			},
			cureFightKey = {
				type = "keybinding",
				name = L["Key for my cure in a fight"],
				desc = L["Saved with your game key bindings, so it works on every profile."],
				order = 32.492,
				hidden = function()
					return not (ns.ClassHasCures() and ns.CureLearned()) or P().cureFight ~= true or not ns.Setup.CanBind()
				end,
				disabled = function() return InCombatLockdown() end,
				get = function() return ns.Setup.Key(ns.CureFight.COMMAND) or "" end,
				set = function(_, value)
					local list = ns.CureFightSpells()
					ns.Setup.SetKey(value, ns.CureFight.COMMAND, function(key, was)
						local spell = list and list[1] and list[1].name
						-- No cure learned: the button casts nothing, so there is no
						-- line to say (an empty one is left unsaid by SetKey).
						if not spell then return "" end
						return L["%s was bound to %s; it now casts %s."]:format(key, was, spell)
					end)
					if ns.CureFight then ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight) end
				end,
			},
			cureFightKey2 = {
				type = "keybinding",
				name = L["Key for my second cure in a fight"],
				desc = L["Saved with your game key bindings, so it works on every profile."],
				order = 32.4925,
				hidden = function()
					local list = ns.CureFightSpells()
					return not (ns.ClassHasCures() and ns.CureLearned()) or P().cureFight ~= true
						or P().cureFightEach ~= true or not (list and list[2]) or not ns.Setup.CanBind()
				end,
				disabled = function() return InCombatLockdown() end,
				get = function() return ns.Setup.Key(ns.CureFight.COMMAND2) or "" end,
				set = function(_, value)
					local list = ns.CureFightSpells()
					ns.Setup.SetKey(value, ns.CureFight.COMMAND2, function(key, was)
						local spell = list and list[2] and list[2].name
						if not spell then return "" end
						return L["%s was bound to %s; it now casts %s."]:format(key, was, spell)
					end)
					if ns.CureFight then ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight) end
				end,
			},
			-- Next to Animations, because that is what it is: the flashes of
			-- a click in a fight, not whether anybody is offered.
			--
			-- The key keeps its old name, "hide in combat", but it hides
			-- nothing: with the switch above off the panel stays up in a
			-- fight, and this decides whether the confirmation flash of a
			-- click in one still shows. It writes the prompt's own table, so
			-- pGet/pSet (restyle).
			hideInCombat = {
				type = "toggle",
				name = L["No flashes in a fight"],
				desc = function()
					return L["The prompt stays up in a fight, its key binding still casting, unless %s is on; this stops only the flashes that say what a click did, red if it failed."]
						:format(L["Hide the prompt in a fight"])
				end,
				order = 32.5,
				width = "full",
				get = pGet,
				set = pSet,
			},
			-- The window fading while a look is changed (Window.lua, PeekTarget).
			peekOnChange = {
				type = "toggle",
				name = L["Fade this window while I change the look"],
				desc = L["On: after a change on Look, and while you drag a slider or pick a colour, this window fades for a moment so you can see the prompt behind it. Off: it stays as it is."],
				order = 35.7,
				width = "full",
				get = pGet,
				set = pSet,
			},
			dimInCombat = {
				type = "toggle",
				name = L["Dim the prompt in combat"],
				desc = L["In a fight the built-in looks are drawn at about half strength, so the prompt reads as held. Off, it stays at the opacity you set."],
				order = 32.6,
				width = "full",
				-- The looks from Looks/ draw a fight their own way (combatArtAlpha,
				-- Combat), so the setting only reaches Glass, Framed and Minimal.
				disabled = function() return ns.Looks.Get(P().style) ~= nil end,
				get = pGet,
				set = pSet,
			},
			soundEnabled = {
				type = "toggle",
				name = L["Play a sound"],
				desc = L["When a new person appears on the prompt."],
				order = 33,
				get = function() return SND().enabled end,
				set = function(_, v)
					SND().enabled = v
					-- Off stops whatever is still playing (Prompt.lua).
					if not v then ns.Guard("sound stop", ns.StopPromptSound) end
				end,
			},
			soundFile = {
				type = "select",
				name = L["Sound"],
				order = 34,
				disabled = function() return not SND().enabled end,
				-- HashTable maps key -> file, and AceConfig shows the
				-- value as the label, so the key is copied into both.
				-- "None" is left out: Play a sound is the off switch. It
				-- stays only while it is the stored value (an older
				-- profile, a paste), so the box never goes blank.
				values = function()
					local chosen = SND().file
					local list = {}
					for key in pairs(LSM:HashTable("sound")) do
						if key ~= "None" or chosen == "None" then list[key] = key end
					end
					-- The chosen sound, even when its pack has not
					-- registered it, so the box still says what was
					-- picked rather than going blank. It plays ours
					-- until the pack is there.
					if type(chosen) == "string" and not list[chosen] then
						list[chosen] = L["%s |cff808080(not loaded)|r"]:format(chosen)
					end
					return list
				end,
				get = function() return SND().file end,
				set = function(_, value)
					SND().file = value
					ns.Guard("sound preview", ns.PlayPromptSound, value)
				end,
			},
			soundOwedOnly = {
				-- The flash fires only for a favour owed; this lets the
				-- sound agree with it.
				type = "toggle",
				name = L["Only for people who buff me"],
				desc = L["Off, every new person makes a sound, passers-by included."],
				order = 35,
				hidden = function() return not HasClassBuffs() end,
				width = "full",
				-- Also off with "People who buff me": nobody is owed then, and
				-- the sound ignores this setting (Prompt/Refresh.lua), so the
				-- toggle would do nothing. Unset counts as on, as it does there.
				disabled = function() return not SND().enabled or S().owed == false end,
				get = function() return SND().owedOnly end,
				set = function(_, v) SND().owedOnly = v end,
			},
			noSound = {
				type = "description",
				order = 35.5,
				hidden = function() return not SND().enabled or SND().file ~= "None" end,
				-- "None" is the name the sound list shows, which is a
				-- LibSharedMedia key and never translated. It goes in as
				-- an argument so a translation cannot rename it to an
				-- entry the list does not have.
				name = "|cffff8080" .. L["%s is silent. Pick a sound above."]:format("None") .. "|r",
			},

			-- What hovering the prompt, or a name in its list, shows and where
			-- (Prompt/Button.lua). Plain accessors: nothing here needs a restyle,
			-- the next hover reads the setting.
			tooltipHeader = { type = "header", name = L["Tooltip"], order = 36 },
			tooltip = {
				type = "select",
				name = L["Tooltip on the prompt"],
				desc = L["What the prompt and the names in its list show when the cursor is on them. Short is the name, why they are offered and a hint; hold Shift for everything. The note about dragging that shows while the prompt is unlocked stays whatever you pick, since it explains the drag."],
				order = 37,
				values = {
					full = L["Full"],
					short = L["Short (hold Shift for more)"],
					shift = L["Only while holding Shift"],
					off = L["Off"],
				},
				sorting = { "short", "full", "shift", "off" },
				get = function() return P().tooltip end,
				set = function(_, value) P().tooltip = value end,
			},
			tooltipPosition = {
				type = "select",
				name = L["Tooltip position"],
				desc = L["Beside the prompt puts it above or below, on the side with more room on your screen, clear of the prompt and its list. Where the game shows tooltips uses your usual tooltip corner."],
				order = 38,
				values = {
					beside = L["Beside the prompt"],
					game = L["Where the game shows tooltips"],
				},
				sorting = { "beside", "game" },
				get = function() return P().tooltipPosition end,
				set = function(_, value) P().tooltipPosition = value end,
				disabled = function() return P().tooltip == "off" end,
			},
			textHeader = { type = "header", name = L["Text"], order = 40 },
			font = {
				type = "select",
				name = L["Font"],
				order = 41,
				-- Keys, not files, as in the sound list: AceConfig shows the
				-- value as the label.
				values = function()
					local list = {}
					for key in pairs(LSM:HashTable("font")) do list[key] = key end
					-- The chosen font even when unregistered, as in the sound
					-- list: koKR, zhCN and zhTW never register the default.
					local chosen = P().font
					if type(chosen) == "string" and not list[chosen] then
						list[chosen] = L["%s |cff808080(not loaded)|r"]:format(chosen)
					end
					return list
				end,
				get = pGet,
				set = pSet,
			},
			fontSize = { type = "range", name = L["Font size"], order = 42, min = 6, max = 32, step = 1, get = pGet, set = pSet },
			-- The prompt picks light or dark text for the panel colour
			-- only while this is left at its default, and the class
			-- colour on a name overrides it; both are said here so
			-- neither reads as the setting being ignored.
			fontColor = {
				type = "color",
				name = L["Text colour"],
				-- Named without its page: the switch is on this one.
				desc = L["White turns dark by itself on a light panel; any other colour is used as you pick it, except for names while this is on:"]
					.. " |cffffd100" .. L["Colour names by class"] .. "|r",
				order = 43,
				hasAlpha = true,
				get = pGetColor,
				set = pSetColor,
			},
			classColor = { type = "toggle", name = L["Colour names by class"], order = 44, width = "full", get = pGet, set = pSet },
			textShadow = {
				type = "toggle",
				name = L["Shadow and outline on the text"],
				desc = L["The shadow under the words, and the outline Minimal draws with no panel behind it, on Glass, Framed and Minimal. Off, the text is drawn flat."],
				order = 44.5,
				width = "full",
				disabled = function() return ns.Looks.Get(P().style) ~= nil end,
				get = pGet,
				set = pSet,
			},
			showSub = {
				type = "toggle",
				name = L["Show a second line"],
				-- Worked out from the font, by the same function ApplyStyle
				-- decides it with, never a constant: 39 at the default size.
				desc = function()
					return L["Needs a prompt at least %d pixels tall."]:format(ns.TwoLineHeight(P().fontSize))
				end,
				order = 45,
				width = "full",
				get = pGet,
				set = pSet,
			},
			-- Asked for on CurseForge: whose guild it is, to tell two people of
			-- one name apart or to see who to leave out.
			showGuild = {
				type = "toggle",
				name = L["Show their guild under the name"],
				desc = L["Adds <Guild> after the reason on the second line, and in the tooltip, for somebody who is in a guild. Needs the second line."],
				order = 45.5,
				width = "full",
				disabled = function() return P().showSub == false end,
				get = pGet,
				set = pSet,
			},

			iconHeader = { type = "header", name = L["Icon and waiting list"], order = 50 },
			showIcon = { type = "toggle", name = L["Show spell icon"], order = 51, get = pGet, set = pSet },
			-- The consumables button's own size (Prompt/Supplies.lua), shown
			-- while it is switched on (Who to buff, Myself).
			suppliesSize = {
				type = "range",
				name = L["Size of the consumables button"],
				desc = L["The button your consumables come up on, with Put consumables on a button of their own on. Unlock the prompt to drag it."],
				order = 52.6,
				min = 24,
				max = 80,
				step = 2,
				hidden = function() return not (ns.db.profile.ownBuffs and ns.db.profile.ownBuffs.apart == true) end,
				get = function() return ns.db.profile.supplies.size end,
				set = function(_, value)
					ns.db.profile.supplies.size = value
					if ns.Supplies then ns.Guard("consumables button", ns.Supplies.Refresh, ns.Supplies) end
				end,
			},
			iconSize = {
				type = "range",
				name = L["Icon size"],
				-- The icon must fit inside the panel, but the bound cannot
				-- live here: AceConfigRegistry types min and max as "number
				-- or nil" and rejects the whole options table if either is a
				-- function. ClampSettings enforces it instead.
				desc = L["The icon stays inside the prompt: make the prompt taller or wider for a bigger one."],
				order = 52,
				min = 12,
				max = 64,
				step = 1,
				-- Kept for the other looks, but the notice below says this
				-- one does not read it.
				disabled = function() return not P().showIcon or LookIconSize() ~= nil end,
				get = pGet,
				set = function(info, value)
					pSet(info, value)
					-- The bound, applied (see above), as the height slider
					-- applies it.
					ns.ClampSettings()
					restyle()
					-- Repainted only when the clamp actually moved it: a
					-- mouse wheel never lets go of the slider, and a repaint
					-- every time would rebuild it under a dragging finger.
					if P().iconSize ~= value and ns.RefreshOptionsDisplay then
						ns.Guard("icon repaint", ns.RefreshOptionsDisplay)
					end
				end,
			},
			iconSizeCapped = {
				type = "description",
				order = 52.5,
				hidden = function()
					local p = P()
					if LookIconSize() then return not p.showIcon end
					-- Shown only when the icon sits on the ceiling
					-- ClampSettings enforces, bound by width and height.
					return not p.showIcon or p.iconSize < ns.IconCeiling(p)
				end,
				name = function()
					local p = P()
					local own = LookIconSize()
					if own then
						return "|cffffd100" .. L["This look sizes the icon from the prompt's height: %d at %d high. Make the prompt taller for a bigger icon."]:format(own, p.height) .. "|r"
					end
					local byWidth = (p.width - 60) < (p.height - 8)
					local text
					if byWidth then
						text = L["The icon is held at %d to fit a prompt %d wide."]:format(p.iconSize, p.width)
					else
						text = L["The icon is held at %d to fit a prompt %d high."]:format(p.iconSize, p.height)
					end
					return "|cffffd100" .. text .. "|r"
				end,
			},
			-- The round mask keeps the bezel (it has a round twin), so rounding
			-- the icon never leaves the marker nowhere.
			roundIcon = {
				type = "toggle",
				name = L["Round the icon off"],
				desc = L["Masks the icon into a circle. Reads more like a portrait than a spell, so it is off by default."],
				order = 53,
				width = "full",
				-- Toast's, Ribbon's and Letter's icons sit in a medallion or a wax
				-- seal: always round, so the switch reads nothing there.
				disabled = function() return not P().showIcon or ns.Looks.RoundAlways(P().style) end,
				get = pGet,
				set = pSet,
			},
			-- The built-in looks only: the others draw their own frame and ink.
			iconFrame = {
				type = "toggle",
				name = L["Frame round the icon"],
				desc = L["The metal bezel round the spell icon, on Glass, Framed and Minimal. Off, the icon stands on its own."],
				order = 53.5,
				width = "full",
				disabled = function() return not P().showIcon or ns.Looks.Get(P().style) ~= nil end,
				get = pGet,
				set = pSet,
			},
			-- Glass only: the gryphon at each end (Looks/Glass.lua).
			gryphons = {
				type = "toggle",
				name = L["Gryphons at the ends"],
				desc = L["A gilt gryphon at each end of the Glass look, as on the game's old action bar. Off, the bar ends at its rails."],
				order = 53.6,
				width = "full",
				-- With Glass's own settings, so drawn only while Glass is chosen.
				hidden = function() return P().style ~= "glass" end,
				disabled = function() return P().style ~= "glass" end,
				get = pGet,
				set = pSet,
			},
			-- Greyed out with the icon hidden, since the sweep is drawn on
			-- it and there is then nothing for this to do.
			showCooldown = {
				type = "toggle",
				name = L["Show the global cooldown on the icon"],
				desc = L["Sweeps the spell icon while the global cooldown runs, like your action bars, so you can see when the next press will go through."]
					.. "\n\n|cff888888" .. L["Hidden in a fight while this is on:"] .. "|r "
					.. "|cffffd100" .. L["No flashes in a fight"] .. "|r",
				order = 54,
				width = "full",
				disabled = function() return not P().showIcon end,
				get = pGet,
				set = pSet,
			},
			showCount = { type = "toggle", name = L["Show how many are waiting"], order = 55, width = "full", get = pGet, set = pSet },
			showQueue = { type = "toggle", name = L["List the next few below"], order = 56, width = "full", get = pGet, set = pSet },
			queueRows = {
				type = "range",
				name = L["How many to list"],
				order = 57,
				min = 1,
				max = 5,
				step = 1,
				disabled = function() return not P().showQueue end,
				get = pGet,
				set = pSet,
			},
			-- Off, the list is only to read: no name in it is a button.
			clickRows = {
				type = "toggle",
				name = L["Click a name in the list to buff them"],
				desc = L["Turns each name in the list into a button: a left click buffs that person as if they were on the prompt. Right-click skips them for now, shift-right-click puts them on your never-offer list. Names cannot be clicked in a fight."],
				order = 58,
				width = "full",
				disabled = function() return not P().showQueue end,
				get = pGet,
				set = pSet,
			},
		},
	}
	-- With the group open for the one button's sake, every other control
	-- keeps the rule the group had: gone for a character with no prompt.
	local function NoPrompt() return not HasPrompt() end
	for key, def in pairs(tab.args) do
		if key ~= "breakFree" and key ~= "breakFreeKey" and key ~= "mendInFight" and key ~= "mendInFightKey" then
			local own = def.hidden
			if own == nil then
				def.hidden = NoPrompt
			elseif type(own) == "function" then
				def.hidden = function(...) return NoPrompt() or own(...) end
			end
		end
	end
	Page.AddMomentControls(tab.args)
	return tab
end

-- The buttons for the moment (Prompt/Moments.lua): a switch and a key for each
-- button a character has learned, and the two shares under which the health and
-- mana buttons light. Added AFTER the loop above, so none of them inherits "gone
-- for a character with no prompt": a class with a moment row and no prompt still
-- sees its switch and key. %s is always the name the client gives the spell.
function Page.AddMomentControls(args)
	local tail = L["Its key is the box under this switch, also in the game's Key Bindings under Manners. With no key set, a click on the lit button casts it. A change made in a fight counts from the next one."]
	local twice = L["Where the game keeps that from addons in a fight, the game itself lights the button, and it then takes two quick clicks, so one stray click never casts it."]
	local function Has(key) return ns.Moments ~= nil and ns.Moments.Has(key) end
	-- The name the client gives the spell: the learned one, or for a spell this
	-- character may not know yet (Ice Block, which Cold Snap brings back) the
	-- client's name for the row's first rank.
	local function Spell(key)
		return ns.Moments and ns.Moments.NameOf(key) or ""
	end
	local function On(key) return ns.db.profile.moments[key] == true end
	local function Refresh() if ns.Moments then ns.Guard("moments", ns.Moments.Refresh, ns.Moments) end end
	local function Cap(key) return key:sub(1, 1):upper() .. key:sub(2) end
	args.momentsNote = {
		type = "description",
		name = L["Small buttons left of the prompt that stay out of sight until their moment comes, then light up. Each has a switch here and a key of its own."],
		order = 32.493,
		fontSize = "medium",
		hidden = function() return not (ns.caps.moments and ns.caps.moments.n > 0) end,
	}
	-- Each switch with its words; the order is the page's. The slider for the
	-- share of health comes after Cold Snap, the one for mana after the gem.
	local rows = {
		{ key = "counterspell",
			name = function() return L["Show %s when my target starts a cast"]:format(Spell("counterspell")) end,
			desc = function() return L["Lights while a hostile target within reach is casting or channelling something you can interrupt, and goes dark the moment the cast ends. A press stops your own cast first, so it fires at once. Out of sight while it cools down."] .. " " .. tail end },
		{ key = "spellsteal",
			name = function() return L["Show %s when my target has a buff I can steal"]:format(Spell("spellsteal")) end,
			desc = function() return L["Lights while a hostile target within reach carries a buff the game marks as stealable. Out of sight while it cools down."] .. " " .. tail end },
		{ key = "blink",
			name = function() return L["Show %s when I am stunned or rooted"]:format(Spell("blink")) end,
			desc = function() return L["Lights while you are stunned or rooted and the spell is ready. Where the game does not say what took control of your character, it lights for any loss of control."] .. " " .. tail end },
		{ key = "iceblock",
			name = function() return L["Show %s when my health is low"]:format(Spell("iceblock")) end,
			desc = function() return L["Lights in a fight while your health is under Health below and the spell is ready."] .. " " .. twice .. " " .. tail end },
		{ key = "coldsnap", after = "health",
			name = function() return L["Show %s when I need %s and it is cooling down"]:format(Spell("coldsnap"), Spell("iceblock")) end,
			desc = function()
				return L["Lights in a fight while your health is under Health below and %s is still on cooldown. It brings that spell back: press it next."]:format(Spell("iceblock"))
					.. " " .. twice .. " " .. tail
			end },
		{ key = "evocation",
			name = function() return L["Show %s when my mana is low in a fight"]:format(Spell("evocation")) end,
			desc = function() return L["Lights in a fight while your mana is under Mana below and the spell is ready."] .. " " .. twice .. " " .. tail end },
		{ key = "managem", after = "mana",
			name = function() return L["Show my mana gem when my mana is low in a fight"] end,
			desc = function() return L["Lights in a fight while your mana is under Mana below and a mana gem in your bags is ready. A press uses the best one you carry."] .. " " .. twice .. " " .. tail end },
		{ key = "slowfall",
			name = function() return L["Show %s when I have been falling for a second"]:format(Spell("slowfall")) end,
			desc = function()
				local text = L["In a fight or out of one. Lights once you have been falling for a second, and goes dark when you land. It lands on you whoever you have targeted."]
				local reagent = ns.Moments and ns.Moments.ReagentName("slowfall")
				if reagent then text = text .. " " .. L["It needs a %s in your bags."]:format(reagent) end
				return text .. " " .. tail
			end },
		{ key = "fireward",
			name = function() return L["Show %s when my target hits me with fire"]:format(Spell("fireward")) end,
			desc = function() return L["Lights in a fight as soon as fire damage hits you while your target is hostile, for ten seconds or until you cast a ward. Once fire has hit you in a fight, it lights again whenever your target casts. The game does not show what a spell is before it lands, so the first fire hit has to land."] .. " " .. tail end },
		{ key = "frostward",
			name = function() return L["Show %s when my target hits me with frost"]:format(Spell("frostward")) end,
			desc = function() return L["Lights in a fight as soon as frost damage hits you while your target is hostile, for ten seconds or until you cast a ward. Once frost has hit you in a fight, it lights again whenever your target casts. The game does not show what a spell is before it lands, so the first frost hit has to land."] .. " " .. tail end },
	}
	local order = 32.4931
	local function Slider(field, name, desc, a, b)
		args["moment" .. Cap(field)] = {
			type = "range",
			name = name,
			desc = desc,
			order = order,
			min = 5, max = 50, step = 5,
			hidden = function() return not (Has(a) or Has(b)) end,
			disabled = function() return not (On(a) or On(b)) end,
			get = function() return ns.db.profile.moments[field] end,
			set = function(_, value) ns.db.profile.moments[field] = value end,
		}
		order = order + 0.0001
	end
	local function Share(after)
		if after == "health" then
			Slider("health", L["Health below"], L["The share of your health under which the health buttons light, in percent."],
				"iceblock", "coldsnap")
		else
			Slider("mana", L["Mana below"], L["The share of your mana under which the mana buttons light, in percent."],
				"evocation", "managem")
		end
	end
	for _, def in ipairs(rows) do
		local key = def.key
		args["moment" .. Cap(key)] = {
			type = "toggle",
			name = def.name,
			desc = def.desc,
			order = order,
			width = "full",
			hidden = function() return not Has(key) end,
			get = function() return On(key) end,
			set = function(_, value)
				ns.db.profile.moments[key] = value == true
				Refresh()
			end,
		}
		args["moment" .. Cap(key) .. "Key"] = {
			type = "keybinding",
			name = function() return L["Key for %s"]:format(Spell(key)) end,
			desc = L["Saved with your game key bindings, so it works on every profile."],
			order = order + 0.00005,
			hidden = function() return not Has(key) or not On(key) or not ns.Setup.CanBind() end,
			disabled = function() return InCombatLockdown() end,
			get = function() return ns.Setup.Key(ns.Moments.Command(key)) or "" end,
			set = function(_, value)
				ns.Setup.SetKey(value, ns.Moments.Command(key), function(bound, was)
					return L["%s was bound to %s; it now casts %s."]:format(bound, was, Spell(key))
				end)
				Refresh()
			end,
		}
		order = order + 0.0001
		if def.after then Share(def.after) end
	end
end
