-- Manners -- one combat prompt. It uses the normal Manners prompt's place and
-- changes to the most urgent action the fight has made relevant.
-- What each waits for is data (Prompt/MomentsData.lua); what is true of the
-- situation is read by Prompt/MomentsSense.lua; this file is the buttons.
--
-- ONE PROMPT = MANY SECURE ACTION SLOTS, ONLY ONE ROUTED TO THE TOP
--
-- A lit action is the prompt in the player's own look: the look's picture,
-- the spell's icon, its name and the reason ("you are stunned") written over it, in
-- the look's own fonts and colours (Prompt/MomentsCard.lua, Looks/CardArt.lua).
-- A look keeps its regions on the one secure prompt, so the card is the look's
-- picture, not a live second copy of it; its motion is a pulse of that picture.
--
--   button   an internal MannersMoment<slot>, a SecureActionButtonTemplate with the macro,
--            shown and hidden by one state driver ("[combat] fight; peace"),
--            never written in a fight. It has NO region of its own and its own
--            alpha is never changed. Place sizes it to the card and sets its point.
--   face     a plain frame over it, alpha 0 at rest. Lua fades it (0.2 s), or sets
--            it at once for a fast row: the plain gate, never handed a hidden value.
--   hint     on face, dim, under inner: Lua's dim card, the picture, icon and name
--            for the first of two clicks, the icon alone for the drink out of a
--            fight while only the game knows, so an armed button is never invisible.
--   inner    on face. THE GAME paints its alpha from a hidden value
--            (SetAlphaFromBoolean, a curve evaluated by UnitHealthPercent): where
--            the client hides a value from Lua in a fight the button still lights
--            from it. The card, the flare, the hover and the key are regions of
--            inner, so what shows is face x inner.
--   mark     on face above inner, Lua's own: the ring of the first of two clicks
--            and the PREVIEW tag, which the game never paints away.
--   cover    an unprotected, mouse-enabled frame over the button. While the
--            button is dark it swallows the click, so a click casts only while
--            the button is lit. A frame that is not protected can be shown and
--            hidden in a fight. Where only the game knows whether the button is
--            lit (a hidden health or mana) the cover is down and one click casts,
--            as on a lit one: the owner found the two clicks this once took (the
--            first only opened it) read as a button that does nothing.
--
-- Every action has a place of its own, in a row from the anchor (just above the
-- normal prompt by default), the most urgent first. A card shows only while it
-- is needed, where it sits. Nothing is stacked: the client refuses to raise a
-- protected button over another in a fight (SetFrameLevel, patch 11.1.7), so a
-- shared spot only ever clicks what was on top at the pull. A secure action,
-- point, size, level or mouse setting never changes in a fight.
--
-- THE DRINK is the one row that works out of a fight only (row.calm): lit while
-- your mana is under Mana below, you stand still and a drink is in your bags. The
-- driver hides it at the pull and the pull clears its macro, so a press in a
-- fight does nothing; out of a fight Lua writes its macro whenever the bags change
-- and shows and hides the button itself. Where the game alone knows the mana
-- (Forever hides it even out of a fight) one click casts, and a dim icon from
-- Lua shows that a button sits there.
--
-- The normal prompt binding retains its normal buffing job. The combat prompt is
-- deliberately clicked, and no learned action adds a binding to Key Bindings.
--
-- WHAT LUA MAY DO IN A FIGHT: paint regions and the alpha of the unprotected
-- children, show and hide the cover. Never Show, Hide, SetPoint, SetSize,
-- EnableMouse or SetAttribute on a button under the lockdown (Refresh and the
-- pull, before it, write those). Hidden values follow the raw naming rule at the
-- top of Prompt/MomentsSense.lua.

local ns = assert(MannersAPI and MannersAPI:ModuleContext("combat"), "Manners module API is missing")
local L = ns.L
local Prompt = ns.Prompt
local R = Prompt.regions
local Sense = ns.Sense
local Card = ns.MomentCard
local plain, caps = ns.plain, ns.caps
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

local Moments = {}
ns.Moments = Moments
-- Every client's rows, for what holds them to the rules.
Moments.Sets = ns.MOMENT_SETS

local MAX = 64
local STATE = "mannersmoments"
local DRIVER = "[combat] fight; peace"
local FADE = 0.2
local FLUSH = 0.1
local RECHECK = 0.25
local PRESS_WINDOW = 1
local SILENT_SECONDS = 1.2
local TRAIL_GAP = 2
local TRAIL_MAX = 12
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The keys whose signals are built: a row not listed here is skipped by Learn,
-- so it has no button, no switch and no binding name of a spell (a class's new
-- row stays out of sight until its signals are written).
local BUILT = { counterspell = true, iceblock = true, blink = true, evocation = true, managem = true,
	slowfall = true, coldsnap = true, spellsteal = true, fireward = true, frostward = true, drink = true,
	purge = true, dispel = true, tranq = true, shieldslam = true }
for key in pairs(ns.MOMENT_DEFAULTS) do BUILT[key] = true end

local TARGET_CAST = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_EMPOWER_START",
	"UNIT_SPELLCAST_EMPOWER_STOP" }
local CAST_START = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_EMPOWER_START = true }
local CAST_STOP = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_EMPOWER_STOP = true,
	UNIT_SPELLCAST_INTERRUPTED = true }
-- Every name the module may register, probed once.
local ALL_EVENTS = { "PLAYER_TARGET_CHANGED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
	"LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "SPELL_UPDATE_COOLDOWN", "PLAYER_CONTROL_LOST",
	"PLAYER_CONTROL_GAINED", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING",
	"BAG_UPDATE_DELAYED", "UNIT_COMBAT", "UNIT_AURA", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
	"PLAYER_LEVEL_UP", "GROUP_ROSTER_UPDATE" }
for _, name in ipairs(TARGET_CAST) do ALL_EVENTS[#ALL_EVENTS + 1] = name end

-- Made slots by number, the ones armed now, and what the last Refresh settled.
local slots, byId = {}, {}
local header, ev, fader, anchor, anchorLabel
local Priority, SELECTED_LEVEL = nil, 500
-- The layer the preview is drawn on: over the options window it is opened from
-- (the drag frame is on TOOLTIP, over this).
local PREVIEW_STRATA = "FULLSCREEN_DIALOG"
-- The sound a newly lit combat prompt plays, when its switch is on.
local ALERT_SOUND = 888
local dirtyRefresh, settledEnabled, settledCaps, settledOn = true, nil, nil, {}
local lastLearned
-- What Wanted compares: the prompt's shape (Panel.lua's styleSerial) and the card size.
local placedSerial, placedSize
local previewing, previewSerial = false, 0
-- The preview is the move (the settings put away for it, the bar over the
-- prompt), not a look being tried; and whether the settings were open, to open
-- them again on the Combat page when it ends.
local moving, reopenOptions = false, false
local fightEvents, peaceEvents = {}, {}
local controlOn, ownCastOn, moveOn, fallOn = false, false, false, false
-- Clocks kept for a spell no armed button of its own holds (Ice Block for Cold
-- Snap when its switch is off), the watch of a fall, and whether you move.
local shadows = {}
local watch, watchWait, watchHold = nil, 0, 0
local WATCH_STEP, WATCH_HOLD = 0.2, 3
local flushDue, recheckDue, peaceDue = false, false, false
local told = false
local lastFight = {}

local function Profile() return ns.db and ns.db.profile end
local function Active()
	return ns.ModuleActive and ns.ModuleActive("combat") == true
end

local function NewTally()
	return { lit = 0, game = 0, pressedLit = 0, pressedGame = 0, pressedDark = 0, out = 0, silent = 0,
		cover = 0, opened = 0, leak = 0 }
end

---------------------------------------------------------------------------
-- what this character can offer: the probe's half, wrapped round
-- ns.ProbeCapabilities at the end of the file
---------------------------------------------------------------------------

-- A row of items (a mana gem): learned when a gem of the set is in the bags or a
-- spell that conjures one is known, and named by the client for the best gem
-- the character carries, else the best it can conjure. Setup path: the counts
-- here may use the older helpers; a count the client will not give is none.
local function LearnItem(row)
	local pick, byBags
	for i, item in ipairs(row.items) do
		local count = ns.ReagentCount and ns.ReagentCount(item)
		if type(count) == "number" and count > 0 then
			pick, byBags = i, true
			break
		end
	end
	if not pick then
		for i, make in ipairs(row.makes or {}) do
			if ns.SpellKnown(make) then
				pick = i
				break
			end
		end
	end
	if not pick then return nil end
	local item, make = row.items[pick], row.makes and row.makes[pick]
	local name = ns.ReagentName and ns.ReagentName(item)
	if (type(name) ~= "string" or name == "") and make and ns.SpellKnown(make) then name = ns.SpellNameFor(make) end
	if type(name) ~= "string" or name == "" then return nil end
	local icon = (C_Item and ns.safecall(C_Item.GetItemIconByID, item)) or ns.safecall(_G.GetItemIcon, item)
	if not icon and make then
		icon = ns.safecall(C_Spell and C_Spell.GetSpellTexture, make) or ns.safecall(_G.GetSpellTexture, make)
	end
	return { row = row, id = nil, name = name, icon = icon or FALLBACK_ICON, byBags = byBags }
end

-- Whether two learned lists name the same rows, spells, names and icons: a probe
-- that learned nothing new must not make the next scan refresh the buttons (a
-- refresh hides every button that is not lit and closes the first of two clicks).
local function SameList(a, b)
	if a.n ~= b.n then return false end
	for i, x in ipairs(a.list) do
		local y = b.list[i]
		if not y or x.row ~= y.row or x.id ~= y.id or x.name ~= y.name or x.icon ~= y.icon or x.byBags ~= y.byBags then
			return false
		end
	end
	return true
end

local function ActiveSpell(id)
	local known = ns.SpellKnown(id) == true
	if not known then
		local book = _G.C_SpellBook
		local pet = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Pet or 1
		known = type(book) == "table" and
			(ns.safecall(book.IsSpellKnown, id, pet) == true
				or ns.safecall(book.IsSpellInSpellBook, id, pet, false) == true)
		if not known then known = ns.safecall(_G.IsSpellKnown, id, true) == true end
	end
	if not known then return false end
	local passive = _G.C_Spell and _G.C_Spell.IsSpellPassive
	if type(passive) ~= "function" then passive = _G.IsPassiveSpell end
	if type(passive) == "function" and ns.safecall(passive, id) == true then return false end
	return true
end

-- A name from the client, never typed. Rows whose first known rank has a name.
function Moments.Learn()
	-- The probe wipes caps first, so the last list is kept here.
	local before = lastLearned
	lastLearned = nil
	caps.moments = nil
	local set = ns.MOMENTS[caps.class]
	if not set then
		if before then dirtyRefresh = true end
		return
	end
	local out = { list = {}, byKey = {}, byName = {}, n = 0 }
	for _, row in ipairs(set) do
		if BUILT[row.key] and row.items and not out.byKey[row.key] then
			local entry = LearnItem(row)
			if entry then
				out.list[#out.list + 1] = entry
				out.byKey[row.key] = entry
				out.n = out.n + 1
			end
		elseif BUILT[row.key] and row.drink and not out.byKey[row.key] then
			-- The drink: named by the client's own "Drink" spell. No `items`, no id
			-- (the gem's paths and the spell lookup key on those).
			local name = ns.SpellNameFor(row.drink)
			if type(name) == "string" and name ~= "" then
				local icon = ns.safecall(C_Spell and C_Spell.GetSpellTexture, row.drink)
					or ns.safecall(_G.GetSpellTexture, row.drink) or "Interface\\Icons\\INV_Drink_07"
				local entry = { row = row, id = nil, name = name, icon = icon }
				out.list[#out.list + 1] = entry
				out.byKey[row.key] = entry
				out.n = out.n + 1
			end
		elseif BUILT[row.key] and row.ranks and not out.byKey[row.key] then
			for _, rank in ipairs(row.ranks) do
				if ActiveSpell(rank) then
					local name = ns.SpellNameFor(rank)
					if type(name) == "string" and name ~= "" then
						local icon = ns.safecall(C_Spell and C_Spell.GetSpellTexture, rank)
							or ns.safecall(_G.GetSpellTexture, rank) or FALLBACK_ICON
						local entry = { row = row, id = rank, name = name, icon = icon }
						if out.byName[name] then break end
						out.list[#out.list + 1] = entry
						out.byKey[row.key] = entry
						out.byName[name] = entry
						out.n = out.n + 1
						break
					end
				end
			end
		end
	end
	if out.n > 0 and before and SameList(before, out) then
		caps.moments, lastLearned = before, before
		return
	end
	if out.n > 0 then caps.moments, lastLearned = out, out end
	if out.n > 0 or before then dirtyRefresh = true end
end

-- Whether this character has a moment row learned (the options page asks).
function Moments.Has(key)
	local mine = caps.moments
	return mine ~= nil and mine.byKey[key] ~= nil
end

-- The name the client gives a row's spell, for the options page: the learned
-- one, or the client's name for the row's first rank (Ice Block, for the switch
-- of Cold Snap, which brings it back, whether or not Ice Block is known).
-- The icon of a row's spell, for the options page, as NameOf finds its name.
function Moments.IconOf(key)
	local mine = caps.moments
	local entry = mine and mine.byKey[key]
	if entry and entry.icon then return entry.icon end
	for _, row in ipairs(ns.MOMENTS[caps.class] or {}) do
		if row.key == key and row.ranks then
			return ns.safecall(_G.C_Spell and _G.C_Spell.GetSpellTexture, row.ranks[1])
		end
	end
	return nil
end

function Moments.NameOf(key)
	local mine = caps.moments
	local entry = mine and mine.byKey[key]
	if entry then return entry.name end
	for _, row in ipairs(ns.MOMENTS[caps.class] or {}) do
		if row.key == key and row.ranks then
			local name = ns.SpellNameFor(row.ranks[1])
			if type(name) == "string" and name ~= "" then return name end
		end
	end
	return nil
end

-- The name of the reagent a row's spell asks for, where the client has it loaded.
function Moments.ReagentName(key)
	for _, row in ipairs(ns.MOMENTS[caps.class] or {}) do
		if row.key == key and row.reagent then return ns.ReagentName and ns.ReagentName(row.reagent) end
	end
	return nil
end

-- Internal slots have no public binding. The one prompt is selected by context.
function Moments.Command(key)
	return nil
end

function Moments.Rows()
	local mine = caps.moments
	return mine and mine.list or {}
end

---------------------------------------------------------------------------
-- the trail
---------------------------------------------------------------------------

local function Trail(slot, text, always)
	local now = GetTime()
	if not always then
		if slot.trailAt and now - slot.trailAt < TRAIL_GAP then return end
		if (slot.trailCount or 0) >= TRAIL_MAX then return end
		slot.trailAt = now
		slot.trailCount = (slot.trailCount or 0) + 1
	end
	ns.Trail("fight", ("moment %s: %s"):format(slot.row.key, text))
end

-- What a lit button saw, in words (the tooltip and the trail).
local function Why(slot)
	local parts = {}
	for _, name in ipairs(slot.row.needs) do
		if name ~= "fight" then parts[#parts + 1] = Sense.WORDS[name] or name end
	end
	return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- the cover and what is painted
---------------------------------------------------------------------------

-- Whether the cover is up: while the button is dark, or while another card has the
-- top (a card left under it, or under the buff prompt, must not catch a click
-- round the edge). The card on top, lit or lit by the game, takes one click.
local function CoverWanted(slot)
	if not slot.mouseOn then return false end
	return slot.state == "dark" or slot.routed ~= true
end
Moments.CoverWanted = CoverWanted

-- The icon of a button, on the layer the game paints and on the dim one Lua owns.
local function SetIcon(slot, texture)
	Card.SetIcon(slot, texture)
end

-- The dim card: the whole of it for the first of two clicks, the icon alone for a
-- calm button the game paints, and nothing otherwise.
local function PaintHint(slot)
	local mode
	if slot.state == "game" then
		if slot.openUntil ~= nil then
			mode = "full"
		elseif slot.row.calm == true then
			mode = "icon"
		end
	end
	Card.Hint(slot, mode)
end

local function FadeTo(slot, to)
	local from = slot.face:GetAlpha()
	if from == to then
		slot.fading, slot.fadeTo = false, to
		return
	end
	slot.fadeFrom, slot.fadeTo, slot.fadeAt, slot.fading = from, to, GetTime(), true
	fader:Show()
end

local function FadeTick()
	local now, any = GetTime(), false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.fading then
			local t = (now - slot.fadeAt) / FADE
			if t >= 1 then
				slot.face:SetAlpha(slot.fadeTo)
				slot.fading = false
			else
				slot.face:SetAlpha(slot.fadeFrom + (slot.fadeTo - slot.fadeFrom) * t)
				any = true
			end
		end
	end
	if not any then fader:Hide() end
end

-- A card arriving: the fast rows (Blink, Counterspell, Ice Block, Cold Snap) are on
-- the screen in the same frame, the others fade in over a fifth of a second.
local function Appear(slot)
	if slot.row.fast then
		slot.face:SetAlpha(1)
		slot.fading, slot.fadeTo = false, 1
	else
		FadeTo(slot, 1)
	end
end

local function GlowOn(slot, on)
	Card.Pulse(slot, on)
end

-- Applies a verdict to the art and the cover only: regions and unprotected
-- frames, allowed in a fight. To dark the cover goes first and no client call is
-- made; to game the client's paint comes first and the state only after it
-- returned, so a throw leaves the previous, consistent state.
local function Apply(slot, state)
	local now = GetTime()
	local was = slot.state
	if state == "dark" then
		slot.state = "dark"
		slot.openUntil, slot.openFrom = nil, nil
		slot.cover:SetShown(CoverWanted(slot, now))
		GlowOn(slot, false)
		slot.ring:Hide()
		Card.Hint(slot, nil)
		if was == "game" then
			-- Lua does not know whether anything was visible: nothing may linger.
			slot.face:SetAlpha(0)
			slot.fading, slot.fadeTo = false, 0
		elseif was == "lit" then
			FadeTo(slot, 0)
		end
		return
	end
	if state == "lit" then
		slot.inner:SetAlpha(1)
		slot.state = "lit"
		Card.Hint(slot, nil)
		Appear(slot)
		GlowOn(slot, true)
		slot.cover:SetShown(CoverWanted(slot, now))
		return
	end
	local game = slot.game
	if not game then return Apply(slot, "dark") end
	local kind, rawA, rawList, count = game[1], game[2], game[3], game[4]
	if not Sense.Paint(slot.inner, kind, rawA, rawList, count) then
		slot.why = "the game refused the paint for " .. kind
		return Apply(slot, "dark")
	end
	slot.state = "game"
	Appear(slot)
	GlowOn(slot, true)
	PaintHint(slot)
	slot.cover:SetShown(CoverWanted(slot, now))
end

-- Whether a card and the buff prompt share any of the screen. A rect not on the
-- screen yet counts as shared: the combat prompt sits on Manners by default.
local function Edges(frame)
	local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	local scale = frame:GetEffectiveScale()
	if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number"
		or type(scale) ~= "number" or r <= l or t <= b then return nil end
	return l * scale, r * scale, t * scale, b * scale
end

local function OverPrompt(slot)
	if not R.button then return false end
	local al, ar, at, ab = Edges(slot.button)
	local bl, br, bt, bb = Edges(R.button)
	if not (al and bl) then return true end
	return al < br and bl < ar and ab < bt and bb < at
end
Moments.OverPrompt = OverPrompt

-- The buff prompt keeps its place while it offers somebody a buff, over a card
-- only the game can see (Lua cannot tell whether it shows, and an invisible card
-- on top would take the click meant for the buff) and over the drink out of a
-- fight. A card Lua knows is needed in a fight still takes the top.
local function GivesWay(slot, busy)
	if not busy then return false end
	if Sense.fighting and slot.state ~= "game" then return false end
	return OverPrompt(slot)
end
Moments.GivesWay = GivesWay

-- Every action has its own place (Place): a protected button cannot be raised
-- over another in a fight (SetFrameLevel is restricted since patch 11.1.7), so
-- the needed one is never brought to the top of a shared spot. Route only shows
-- the cards that are needed, each where it sits, and raises the cover of every
-- other: art and unprotected frames, allowed in a fight. `selected` is the most
-- urgent card shown, for the alert and the check-up.
local function Route()
	if previewing then return end
	local before = Moments.selected
	local best
	local busy = Prompt ~= nil and type(Prompt.Showing) == "function" and Prompt:Showing() ~= nil
	local yielded = false
	local show = {}
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and slot.state ~= "dark"
			and ((Sense.fighting and slot.row.calm ~= true) or (not Sense.fighting and slot.row.calm == true)) then
			if GivesWay(slot, busy) then
				yielded = true
			else
				show[slot] = true
				if not best or Priority(slot) < Priority(best)
					or (Priority(slot) == Priority(best) and slot.n < best.n) then
					best = slot
				end
			end
		end
	end
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.button then
			local shown = show[slot] == true
			slot.routed = shown
			slot.cover:SetShown(CoverWanted(slot))
			if shown then
				slot.face:SetAlpha(1)
				slot.fading = false
				Card.ShowReason(slot, slot.state)
				GlowOn(slot, true)
			else
				slot.face:SetAlpha(0)
				slot.fading = false
				GlowOn(slot, false)
				slot.ring:Hide()
			end
		end
	end
	Moments.selected, Moments.yielded = best, yielded
	local m = Profile() and Profile().moments
	if best and best ~= before and Sense.fighting and type(m) == "table" and m.alertSound == true
		and type(_G.PlaySound) == "function" then
		ns.Guard("combat alert sound", _G.PlaySound, ALERT_SOUND)
	end
end
Moments.Route = Route

-- A click a dark card swallowed.
local function CoverDown(slot, mouse)
	-- Only the left button counts: a right or middle press is the player's camera
	-- or a click on the world.
	if mouse ~= "LeftButton" then return end
	slot.tally.cover = slot.tally.cover + 1
	if slot.state == "dark" then
		Trail(slot, "the cover took a click (dark: " .. tostring(slot.why or "no need") .. ")")
	else
		Trail(slot, "the cover took a click (another card or the buff prompt has the top)")
	end
end

---------------------------------------------------------------------------
-- judging a slot
---------------------------------------------------------------------------

-- A button that works out of a fight too is on the screen out of one only while
-- it is lit: the driver leaves it alone at peace. Never under the lockdown.
local function PeaceShow(slot, state)
	local button = slot.button
	if state == "dark" then
		if button:IsShown() then button:Hide() end
	elseif not button:IsShown() then
		button:Show()
	end
end

-- Whether a dark slot is waiting on something that changes with no event: a
-- cooldown ending, a mob walking into range, a spell the game will call castable
-- in a moment.
local PENDING = { ["cooling down"] = true, ["out of range"] = true, ["not enough mana"] = true,
	["the game says it cannot be cast now"] = true }

local function Judge(slot, now)
	-- The preview shows every card lit with nothing armed: a verdict would take it down.
	if previewing then return end
	local state, why, note = Sense.Evaluate(slot, now)
	local was = slot.state
	slot.why, slot.note = why, note
	if state == "game" or state ~= was then
		Apply(slot, state)
		state = slot.state
		if state ~= was and slot.row.peace == true and not InCombatLockdown() then PeaceShow(slot, state) end
	end
	-- An urgent card held dark for a reason that passes by itself: one line for the
	-- episode, so a check-up says what it waited on (the global cooldown, a cooldown
	-- the game gave no flag for, a spell the game would not call castable).
	if slot.row.fast and state == "dark" and PENDING[why] and Sense.fighting then
		if slot.heldWhy ~= why then
			slot.heldWhy = why
			-- Not under the trail's gap of two seconds, which a held row that lights a
			-- moment later would hand to this line and take from its own lit line: one
			-- line a reason, and a count of its own.
			if (slot.heldCount or 0) < TRAIL_MAX then
				slot.heldCount = (slot.heldCount or 0) + 1
				Trail(slot, ("held dark: %s; global cooldown %s; onGCD %s"):format(tostring(why), Sense.GcdWord(),
					tostring(slot.onGCD)), true)
			end
		end
	else
		slot.heldWhy = nil
	end
	-- The words of a card that is lit or left to the game, written at every look: they
	-- stay true to the facts under them (Blink's kind of loss of control and a ward's
	-- route are read again each time, so a root that becomes a stun is said so), and
	-- only the text of a font string is written, when the words have changed
	-- (ShowReason), which a fight allows.
	if state ~= "dark" then Card.ShowReason(slot, state) end
	if state == was then return end
	if state == "lit" then
		slot.tally.lit = slot.tally.lit + 1
		Trail(slot, "lit (" .. Why(slot) .. (note and ("; passed over: " .. note) or "")
			.. (slot.lockFlag ~= nil and ("; the game's lock flag for it: " .. tostring(slot.lockFlag)) or "") .. ")")
	elseif state == "game" then
		slot.tally.game = slot.tally.game + 1
		Trail(slot, "left to the game (" .. tostring(why) .. "; the rest: " .. Why(slot) .. ")")
	end
end


local function Flush()
	flushDue = false
	if not Sense.fighting then return end
	local now, pending = GetTime(), false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			if slot.reread then slot.castOn, slot.reread = nil, false end
			Judge(slot, now)
			if slot.state ~= "dark" or PENDING[slot.why] then pending = true end
		end
	end
	Route()
	if pending and not recheckDue then
		local timer = _G.C_Timer
		if type(timer) == "table" and type(timer.After) == "function" then
			recheckDue = true
			timer.After(RECHECK, function()
				recheckDue = false
				ns.Guard("moments", Flush)
			end)
		end
	end
end

local function Schedule()
	if flushDue then return end
	local timer = _G.C_Timer
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	flushDue = true
	timer.After(FLUSH, function() ns.Guard("moments", Flush) end)
end

-- Read again and painted at once, for the events that begin a moment.
local function JudgeAll(only)
	local now = GetTime()
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and (only == nil or slot.needs[only]) then Judge(slot, now) end
	end
	Route()
end

-- Dark at once, with no read: the cast ended.
local function Darken(only, why)
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and slot.needs[only] then
			slot.why = why
			if slot.state ~= "dark" then Apply(slot, "dark") end
		end
	end
	Route()
end

---------------------------------------------------------------------------
-- the button
---------------------------------------------------------------------------

-- A press, by its key or a left click. The press the prompt filed is not this
-- one's, so it is let go. A click that reached the button while the cover stood
-- over it (and no key can have pressed it) is a leak: counted, told, never
-- hidden.
local function PreClick(slot, mouse)
	if mouse ~= "LeftButton" then return end
	local now = GetTime()
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then
		ns.ExpirePendingClick(pending, L["you cast %s instead"]:format(slot.name))
	end
	slot.waitUntil = now + PRESS_WINDOW
	slot.went = false
	local tally, state = slot.tally, slot.state
	if slot.keyLabel == nil and slot.cover:IsShown() then
		tally.leak = tally.leak + 1
		-- Counted for this session: a leak long ago is not this session's fault.
		slot.leakTotal = (slot.leakTotal or 0) + 1
		Trail(slot, "the cover let a click through", true)
	end
	-- One press of a drink is one press: the opening the first of two clicks made
	-- ends here and the cover goes back, so a third click inside the window cannot drink again.
	if slot.row.calm then
		slot.openUntil = nil
		slot.ring:Hide()
		PaintHint(slot)
		slot.cover:SetShown(CoverWanted(slot, now))
	end
	if state == "lit" then
		tally.pressedLit = tally.pressedLit + 1
		Trail(slot, "pressed: lit", true)
	elseif state == "game" then
		tally.pressedGame = tally.pressedGame + 1
		Trail(slot, "pressed: left to the game: " .. tostring(slot.why), true)
	else
		tally.pressedDark = tally.pressedDark + 1
		Trail(slot, "pressed: dark: " .. tostring(slot.why or "no need"), true)
	end
	if state ~= "dark" then
		slot.pressSerial = (slot.pressSerial or 0) + 1
		local serial = slot.pressSerial
		local timer = _G.C_Timer
		if type(timer) == "table" and type(timer.After) == "function" then
			timer.After(SILENT_SECONDS, function()
				if slot.pressSerial == serial and not slot.went then
					tally.silent = tally.silent + 1
					Trail(slot, "pressed lit, nothing went out", true)
				end
			end)
		end
	end
end

local function OnEnter(slot, self)
	if slot.state == "dark" then return end
	slot.hover:Show()
	if slot.state ~= "lit" then return end
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	local held
	for _, item in ipairs(slot.row.items or {}) do
		if slot.count and (slot.count[item] or 0) > 0 then
			held = item
			break
		end
	end
	if slot.row.drink and slot.drinkPick and type(tip.SetItemByID) == "function" then
		tip:SetItemByID(slot.drinkPick)
	elseif slot.id and type(tip.SetSpellByID) == "function" then
		tip:SetSpellByID(slot.id)
	elseif held and type(tip.SetItemByID) == "function" then
		tip:SetItemByID(held)
	else
		tip:AddLine(tostring(slot.name), 1, 1, 1)
	end
	tip:AddLine(Why(slot), 0.75, 0.75, 0.75, true)
	if slot.row.drink then
		tip:AddLine(L["Manners: left-click this combat prompt to cast it."], 0.75, 0.75, 0.75, true)
	else
		tip:AddLine(L["Manners: left-click this combat prompt to cast it."], 0.75, 0.75, 0.75, true)
	end
	local key = slot.row.key
	ns.AddSettingsLine(tip, "appearance.moment" .. key:sub(1, 1):upper() .. key:sub(2))
	slot.tipShown = true
	tip:Show()
end

local function OnLeave(slot)
	slot.hover:Hide()
	if slot.tipShown then
		slot.tipShown = false
		local tip = _G.GameTooltip
		if tip then tip:Hide() end
	end
end

-- Runs in the restricted environment: every armed button shown for the fight,
-- hidden after, except a button that keeps its own show out of a fight. A calm
-- button (the drink) is hidden for the fight too.
local SNIPPET = [=[
	for i = 1, 64 do
		local b = self:GetFrameRef("m" .. i)
		if b then
			local on = self:GetAttribute("manners-on-" .. i)
			if newstate == "fight" then
				if on and not self:GetAttribute("manners-calm-" .. i) then b:Show(true) else b:Hide(true) end
			elseif not (on and self:GetAttribute("manners-keep-" .. i)) then
				b:Hide(true)
			end
		end
	end
]=]

local function Create(n)
	if slots[n] or InCombatLockdown() then return slots[n] end
	local slot = { n = n, state = "dark", tally = NewTally(), needs = {} }
	local button = CreateFrame("Button", "MannersMoment" .. n, UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(false)
	button:RegisterForClicks("AnyDown")
	-- Only the left button casts; the others go through the button (and its cover)
	-- to the world, so the camera turns under an invisible one. Out of combat here.
	if type(button.SetPassThroughButtons) == "function" then
		button:SetPassThroughButtons("RightButton", "MiddleButton", "Button4", "Button5")
	end
	-- A key press is a down click (Prompt/Panel.lua explains).
	button:SetAttribute("pressAndHoldAction", true)
	button:EnableMouse(false)
	if type(button.SetHitRectInsets) == "function" then button:SetHitRectInsets(0, 0, 0, 0) end
	for i = 2, 31 do
		if i <= 5 then button:SetAttribute("type" .. i, "none") end
		button:SetAttribute("*type" .. i, "none")
	end
	local level = button:GetFrameLevel()
	local face = CreateFrame("Frame", nil, button)
	face:SetAllPoints(button)
	face:SetFrameLevel(level + 1)
	face:SetAlpha(0)
	-- Under inner: the dim card Lua shows where the game has painted inner away.
	local hint = CreateFrame("Frame", nil, face)
	hint:SetAllPoints(face)
	hint:SetFrameLevel(level + 2)
	hint:SetAlpha(0.4)
	hint:Hide()
	local inner = CreateFrame("Frame", nil, face)
	inner:SetAllPoints(face)
	inner:SetFrameLevel(level + 3)
	inner:SetAlpha(1)
	-- On a frame of Lua's own above inner, not on inner: where the game paints inner
	-- away the first of two clicks still shows, so the second is a choice the player sees.
	local mark = CreateFrame("Frame", nil, face)
	mark:SetAllPoints(face)
	mark:SetFrameLevel(level + 4)
	local cover = CreateFrame("Frame", nil, button)
	cover:SetAllPoints(button)
	cover:SetFrameLevel(level + 10)
	cover:EnableMouse(true)
	cover:SetScript("OnMouseDown", function(_, mouse) ns.Guard("moments", CoverDown, slot, mouse) end)
	-- The other buttons reach the world (the camera turns under the invisible
	-- cover); written here, out of combat, on an unprotected frame.
	if type(cover.SetPassThroughButtons) == "function" then
		cover:SetPassThroughButtons("RightButton", "MiddleButton", "Button4", "Button5")
	end
	cover:Hide()
	button:SetScript("PreClick", function(_, mouse) ns.Guard("moments", PreClick, slot, mouse) end)
	button:SetScript("OnEnter", function(self) OnEnter(slot, self) end)
	button:SetScript("OnLeave", function() OnLeave(slot) end)
	button:Hide()
	slot.button, slot.face, slot.hint, slot.inner, slot.mark, slot.cover = button, face, hint, inner, mark, cover
	-- The buff prompt coming and going out of a fight decides whether a card gives
	-- way to it (Route); a hook on its scripts, so the prompt's code is untouched.
	if not Moments.promptHooked and R.button and type(R.button.HookScript) == "function" then
		Moments.promptHooked = true
		local function Again() ns.Guard("combat prompt beside the buff prompt", Route) end
		R.button:HookScript("OnShow", Again)
		R.button:HookScript("OnHide", Again)
	end
	-- The card's regions (the picture, the icon, the lines, the flare, the ring) are on
	-- these frames, made out of a fight here.
	Card.Build(slot)
	slots[n] = slot
	if not fader then
		fader = CreateFrame("Frame")
		fader:Hide()
		fader:SetScript("OnUpdate", FadeTick)
		Sense.Probe(inner)
	end
	if not header and type(_G.RegisterStateDriver) == "function" then
		local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made) == "table" and type(made.SetFrameRef) == "function" then
			made:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made, STATE, DRIVER)
			header = made
		end
	end
	if not ev then
		ev = CreateFrame("Frame")
		Moments.frame = ev
		ev:SetScript("OnEvent", function(_, event, unit, ...)
			-- The busiest ones of a fight come first, outside the guard's closure.
			ns.Guard("moments", Moments.OnEvent, event, unit, ...)
		end)
		Sense.ProbeEvents(ev, ALL_EVENTS)
		ev:RegisterEvent("PLAYER_REGEN_DISABLED")
		ev:RegisterEvent("UPDATE_BINDINGS")
	end
	return slot
end

---------------------------------------------------------------------------
-- the macro, keys, mouse and place: out of combat only
---------------------------------------------------------------------------

-- A gem row: one /use line for each kind in the bags, best first; with none in
-- the bags, a line for every gem the mage can conjure, so a gem made in the
-- fight still serves. Slow Fall lands on you: [@player] where the client parses
-- a unit in a conditional, else the one self-cast shape known to work on Forever
-- (Prompt/Macro.lua, STRATEGIES.self: you targeted by name, the cast, your target
-- handed back). No bare cast, which a client with auto self-cast off answers by
-- asking for a target, and no /cleartarget, which would drop a friend for good.
local function MacroFor(slot)
	local row = slot.row
	-- The drink: one line (two would drink twice), the best drink in the bags,
	-- no conditional. Written out of a fight, so it is rewritten whenever the
	-- bags change.
	if row.drink then
		if not slot.drinkPick then return nil end
		return "/use item:" .. slot.drinkPick
	end
	if row.items then
		local lines, counts = {}, slot.count or {}
		for _, id in ipairs(row.items) do
			if (counts[id] or 0) > 0 then lines[#lines + 1] = "/use item:" .. id end
		end
		if #lines == 0 then
			for i, id in ipairs(row.items) do
				local make = row.makes and row.makes[i]
				if make and ns.SpellKnown(make) then lines[#lines + 1] = "/use item:" .. id end
			end
		end
		if #lines == 0 then return nil end
		-- A cast under way refuses an item's use: the press stops it first, as a spell's does.
		return (row.stop and "/stopcasting\n" or "") .. table.concat(lines, "\n")
	end
	if row.self then
		if caps.conditionalTargeting then
			slot.shape = "[@player]"
			return "/cast [@player] " .. slot.name
		end
		local line = Prompt.SelfTargetLine and Prompt.SelfTargetLine()
		if not line then
			slot.shape = "no name for you"
			return nil
		end
		slot.shape = "target yourself by name, cast, hand the target back"
		return line .. "\n/cast " .. slot.name .. "\n/targetlasttarget"
	end
	return (row.stop and "/stopcasting\n" or "") .. "/cast " .. slot.name
end

local function Disarm(slot)
	local button = slot.button
	if slot.armedMacro ~= nil or button:GetAttribute("macrotext1") ~= nil then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
	end
	slot.armedMacro = nil
end

local function Arm(slot)
	if InCombatLockdown() then return end
	local macro = MacroFor(slot)
	if macro == nil then
		Disarm(slot)
		slot.tooLong = false
		return
	end
	if #macro > ns.MACRO_LIMIT then
		Disarm(slot)
		slot.tooLong = true
		return
	end
	slot.tooLong = false
	local button = slot.button
	if macro == slot.armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	slot.armedMacro = macro
end

local function ReadKey(slot)
	slot.keyLabel = nil
	slot.keyText:SetText("")
end

-- A button takes a click only when no key is bound (then a click is the only way
-- to cast it): with a key, clicks reach the world and no cover is used. The
-- client refuses EnableMouse on a protected frame under the lockdown.
local function SetMouse(slot)
	if InCombatLockdown() then return end
	local on = slot.keyLabel == nil
	slot.button:EnableMouse(on)
	slot.mouseOn = on
end

local Place
local ROW_GAP = 6

-- A slot's button and the frames on it, at `level`: out of a fight only.
local function Levels(slot, level)
	if InCombatLockdown() then return end
	if slot.button:GetFrameLevel() == level and slot.routeLevel == level then return end
	slot.button:SetFrameLevel(level)
	slot.face:SetFrameLevel(level + 1)
	slot.hint:SetFrameLevel(level + 2)
	slot.inner:SetFrameLevel(level + 3)
	slot.mark:SetFrameLevel(level + 4)
	slot.cover:SetFrameLevel(level + 10)
	slot.routeLevel = level
end

-- Where the combat prompt sits by default: just above the buff prompt, so the
-- two never share a spot (each takes its own clicks).
local function DefaultY(h)
	local ph = R.button and R.button:GetHeight()
	if type(ph) ~= "number" or ph <= 0 then ph = 44 end
	return math.floor(ph / 2 + h / 2 + ROW_GAP + 0.5)
end

Priority = function(slot)
	local row, needs = slot.row, slot.needs or {}
	local category = row and row.category
	if category == "interrupt" or needs.casting or needs.interruptible then return 1 end
	if needs.stuck or row and row.key == "blink" then return 2 end
	if category == "self_heal" or category == "party_heal" or category == "target_heal" then return 3 end
	if category == "enemy_self_heal" or category == "self_defense" or needs.lowhealth then return 4 end
	if category == "enemy_dispel" or needs.removable or needs.stealable then return 5 end
	if category == "self_resource" or needs.lowmana or needs.lowpower or needs.itemready then return 6 end
	return row and row.calm == true and 90 or 50
end

-- A card is the normal prompt's size at 100%, each in its own place (Place).
function Moments.CardSize(p)
	local db = Profile()
	local percent = db and type(db.moments) == "table" and tonumber(db.moments.cardSize) or 150
	local scale = tonumber(p.scale) or 1
	local w = math.max(120, math.floor((tonumber(p.width) or 220) * percent / 100 * scale + 0.5))
	local h = math.max(24, math.floor((tonumber(p.height) or 44) * percent / 100 * scale + 0.5))
	return w, h, scale
end

local function SaveMove()
	local db, at = Profile(), R.button
	if InCombatLockdown() or not (db and anchor and at) then return end
	local ax, ay, px, py = anchor:GetCenter()
	if type(ax) ~= "number" or type(ay) ~= "number" then return end
	px, py = at:GetCenter()
	if type(px) ~= "number" or type(py) ~= "number" then return end
	db.moments.promptX, db.moments.promptY = ax - px, ay - py
	Place(db.prompt)
end

local function Anchor()
	if anchor then return anchor end
	anchor = CreateFrame("Frame", "MannersCombatPromptAnchor", UIParent)
	anchor:SetClampedToScreen(true)
	anchor:SetMovable(true)
	anchor:SetFrameStrata("TOOLTIP")
	anchor:RegisterForDrag("LeftButton")
	anchor:EnableMouse(false)
	anchor:SetScript("OnDragStart", function(self)
		if previewing and not InCombatLockdown() then self:StartMoving() end
	end)
	anchor:SetScript("OnDragStop", function(self)
		if InCombatLockdown() then return end
		self:StopMovingOrSizing()
		SaveMove()
	end)
	-- A right-click on the preview is the way out that needs no trip to the window.
	anchor:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and previewing and Moments.EndPreview then
			ns.Guard("moments", Moments.EndPreview)
		end
	end)
	-- The bar over the prompt while it is moved: what it is, how to move it, and
	-- the two ways out, on a plate of its own so it reads over anything.
	anchorLabel = CreateFrame("Frame", "MannersCombatPromptMover", anchor)
	anchorLabel:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
	anchorLabel:SetSize(300, 50)
	local plate = anchorLabel:CreateTexture(nil, "BACKGROUND")
	plate:SetAllPoints()
	plate:SetColorTexture(0.05, 0.04, 0.03, 0.92)
	local rim = anchorLabel:CreateTexture(nil, "BORDER")
	rim:SetPoint("TOPLEFT", anchorLabel, "TOPLEFT", 0, 0)
	rim:SetPoint("TOPRIGHT", anchorLabel, "TOPRIGHT", 0, 0)
	rim:SetHeight(2)
	rim:SetColorTexture(1, 0.82, 0, 0.9)
	local title = anchorLabel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", anchorLabel, "TOPLEFT", 10, -8)
	title:SetText(L["Combat prompt"])
	local how = anchorLabel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	how:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	how:SetText(L["Drag it to move it."])
	local done = CreateFrame("Button", nil, anchorLabel, "UIPanelButtonTemplate")
	done:SetSize(70, 22)
	done:SetPoint("RIGHT", anchorLabel, "RIGHT", -8, 0)
	done:SetText(L["Done"])
	done:SetScript("OnClick", function() ns.Guard("moments", Moments.EndPreview) end)
	local reset = CreateFrame("Button", nil, anchorLabel, "UIPanelButtonTemplate")
	reset:SetSize(70, 22)
	reset:SetPoint("RIGHT", done, "LEFT", -6, 0)
	reset:SetText(L["Reset"])
	reset:SetScript("OnClick", function()
		ns.Guard("moments", function()
			if Moments:ResetPosition() then Moments.Preview(true, true) end
		end)
	end)
	anchorLabel.done, anchorLabel.reset = done, reset
	anchorLabel:Hide()
	return anchor
end

local function CombatStyle(p)
	local db = Profile()
	-- A look under the pointer in the options' gallery, for as long as it is there.
	local tried = Moments.tried
	if tried and ns.Looks and ns.Looks.Allowed()[tried] then return tried end
	local look = db and db.moments and db.moments.look
	if look ~= nil and look ~= "same" and ns.Looks and ns.Looks.Allowed()[look] then return look end
	return p.style or "glass"
end

Place = function(p)
	local W, H = Moments.CardSize(p)
	local at = Anchor()
	local db = Profile()
	local moments = db and type(db.moments) == "table" and db.moments or {}
	at:ClearAllPoints()
	at:SetPoint("CENTER", R.button, "CENTER", tonumber(moments.promptX) or 0, tonumber(moments.promptY) or DefaultY(H))
	at:SetSize(W, H)
	at:EnableMouse(previewing == true)
	-- The bar only while the prompt is being moved, not while a look is tried.
	anchorLabel:SetShown(previewing == true and moving == true)
	-- A place each, in a row from the anchor, the most urgent first: the order is
	-- fixed out of a fight, so a card always appears where it appeared before.
	local order = {}
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then order[#order + 1] = slot end
	end
	table.sort(order, function(a, b)
		local pa, pb = Priority(a), Priority(b)
		if pa ~= pb then return pa < pb end
		return a.n < b.n
	end)
	local placedN = 0
	for i, slot in ipairs(order) do
		do
			local b = slot.button
			b:ClearAllPoints()
			b:SetPoint("CENTER", at, "CENTER", (i - 1) * (W + ROW_GAP), 0)
			b:SetSize(W, H)
			-- Over the buff prompt, under it: where the two share the screen the
			-- buff prompt takes the click (a level cannot change in a fight).
			Levels(slot, OverPrompt(slot) and 0 or SELECTED_LEVEL)
			placedN = placedN + 1
			local key = CombatStyle(p)
			local sig = Card.Signature(slot, key, W, H)
			if sig ~= slot.dressSig then
				Card.Dress(slot, key, W, H)
				slot.dressSig = sig
			end
		end
	end
	Moments.placed = { side = "prompt", w = W, h = H, cols = placedN, perCol = 1, n = placedN, rightwards = true }
	return "prompt"
end
Moments.Place = Place
Moments.Anchor = Anchor

function Moments:ResetPosition()
	local db = Profile()
	if InCombatLockdown() or not db or type(db.moments) ~= "table" then return false end
	db.moments.promptX, db.moments.promptY = nil, nil
	self:Refresh()
	return true
end

-- Where a cooldown already running before the pull is known from: plain start
-- and length say it, and Manners' own clock keeps it where the fight hides them.
local function Seed(slot, now)
	if not slot.id then return end
	local _, start, duration = Sense.Cool(slot.id)
	if type(start) == "number" and type(duration) == "number" and duration > 1.5 then
		local left = start + duration - now
		if left > 0 then slot.readyAt = now + left end
	end
end

-- The fall watch: no event says you are falling on any client, so a plain frame
-- asks IsFalling every 0.2 s, and only while it can matter: you move (the two
-- movement events), you are in a fight (a knock-back), you are falling, or for
-- three seconds after the last of those. Standing still out of a fight it is
-- hidden and costs nothing.
local function JudgeKeep(now)
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and slot.needs.falling then Judge(slot, now) end
	end
	Route()
end

local function WatchRead()
	local now = GetTime()
	local falling = Sense.ReadFall(now)
	if falling or Sense.moving or Sense.fighting then watchHold = now + WATCH_HOLD end
	JudgeKeep(now)
	if not (falling or Sense.moving or Sense.fighting or now < watchHold) then watch:Hide() end
end

local function WatchShow(now)
	if not watch or not fallOn then return end
	watchHold = now + WATCH_HOLD
	watchWait = WATCH_STEP
	watch:Show()
end

-- One event of the out-of-a-fight set, registered or dropped.
local function PeaceSet(name, want, unit)
	if want then
		if not peaceEvents[name] and Sense.accepted[name] then
			if unit then ev:RegisterUnitEvent(name, unit) else ev:RegisterEvent(name) end
			peaceEvents[name] = true
		end
	elseif peaceEvents[name] then
		ev:UnregisterEvent(name)
		peaceEvents[name] = nil
	end
end

local function SetRegistered(on)
	if ev == nil then return end
	-- Own casts, the control events and the movement events, kept while an armed
	-- row needs them.
	local wantOwn = false
	local wantControl = false
	local wantMove = false
	local wantStill, wantCalm, wantCalmMana = false, false, false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			wantOwn = true
			if slot.needs.stuck then wantControl = true end
			if slot.needs.falling then wantMove = true end
			if slot.row.calm then
				-- The drink hears the bags always; the mana, movement and death events only
				-- while a drink is in the bags (with none it is dark whatever they say).
				wantCalm = true
				if slot.drinkPick then
					wantCalmMana = true
					if slot.needs.still then wantStill = true end
				end
			end
		end
	end
	-- The fall watch is for a fall alone; the movement events also serve the drink.
	local wantFall = wantMove
	wantMove = wantMove or wantStill
	if wantFall then
		if not watch then
			watch = CreateFrame("Frame")
			watch:Hide()
			watch:SetScript("OnUpdate", function(_, elapsed)
				watchWait = watchWait + elapsed
				if watchWait < WATCH_STEP then return end
				watchWait = 0
				ns.Guard("moments", WatchRead)
			end)
		end
		fallOn = true
	elseif fallOn then
		fallOn = false
		Sense.fallSince, Sense.fallSecret = nil, false
		if watch then watch:Hide() end
	end
	if wantMove then
		if not moveOn then
			for _, name in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }) do
				if Sense.accepted[name] then ev:RegisterEvent(name) end
			end
			moveOn = true
			-- Moving already as the events begin to be heard.
			local speed = type(_G.GetUnitSpeed) == "function" and plain(_G.GetUnitSpeed("player")) or nil
			Sense.moving = type(speed) == "number" and speed > 0
		end
	elseif moveOn then
		ev:UnregisterEvent("PLAYER_STARTED_MOVING")
		ev:UnregisterEvent("PLAYER_STOPPED_MOVING")
		moveOn, Sense.moving = false, false
	end
	if wantOwn and not ownCastOn and Sense.accepted.UNIT_SPELLCAST_SUCCEEDED then
		ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
		ownCastOn = true
	elseif ownCastOn and not wantOwn then
		ev:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		ownCastOn = false
	end
	if wantControl and not controlOn then
		for _, name in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }) do
			if Sense.accepted[name] then ev:RegisterEvent(name) end
		end
		controlOn = true
	elseif controlOn and not wantControl then
		ev:UnregisterEvent("PLAYER_CONTROL_LOST")
		ev:UnregisterEvent("PLAYER_CONTROL_GAINED")
		controlOn = false
		Sense.lostAt, Sense.locAt = nil, nil
	end
	-- The out-of-a-fight set: never in a fight (the pull drops it).
	local peace = not Sense.fighting
	PeaceSet("BAG_UPDATE_DELAYED", wantCalm and peace)
	local mana = wantCalmMana and peace
	PeaceSet("UNIT_POWER_UPDATE", mana, "player")
	PeaceSet("UNIT_MAXPOWER", mana, "player")
	PeaceSet("PLAYER_DEAD", mana)
	-- The pick's own inputs: your level and being alive (an item the game calls
	-- unusable while you are dead). Heard with no pick too, so a level-up or a
	-- rising lights a drink the bags already hold.
	local pickInputs = wantCalm and peace
	PeaceSet("PLAYER_ALIVE", pickInputs)
	PeaceSet("PLAYER_UNGHOST", pickInputs)
	PeaceSet("PLAYER_LEVEL_UP", pickInputs)
end

-- The out-of-a-fight pass, coalesced like the fight's flush: the bags recounted
-- if a bag event came (a new pick re-arms the macro, the icon and the events),
-- then every calm button judged. Never in a fight, never under the lockdown.
local function PeaceFlush()
	peaceDue = false
	if Sense.fighting or InCombatLockdown() or previewing then return end
	local now = GetTime()
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and slot.row.calm then
			if slot.bagsDirty then
				slot.bagsDirty = false
				if Sense.CountDrinks(slot) then
					Arm(slot)
					if slot.drinkIcon then SetIcon(slot, slot.drinkIcon) end
					SetRegistered()
				end
			end
			Judge(slot, now)
		end
	end
	Route()
end

local function SchedulePeace()
	if peaceDue then return end
	local timer = _G.C_Timer
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	peaceDue = true
	timer.After(FLUSH, function() ns.Guard("moments", PeaceFlush) end)
end

-- From a scan (Core.lua's TickBody) when Wanted says something changed, and as
-- a fight ends (Release). Out of combat only.
local function ClosePreview()
	if not previewing then return end
	previewing, moving = false, false
	previewSerial = previewSerial + 1
	if anchor then
		anchor:EnableMouse(false)
		if anchorLabel then anchorLabel:Hide() end
	end
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.tag then
			Card.Tag(slot, false)
			Card.Pulse(slot, false)
		end
		if slot and not InCombatLockdown() then slot.button:SetFrameStrata("MEDIUM") end
	end
end

function Moments:Refresh(keepLit)
	if InCombatLockdown() then return end
	local db = Profile()
	if not db then return end
	-- A refresh re-arms every macro and darkens every card: it ends a preview.
	ClosePreview()
	local mine = caps.moments
	local switches = type(db.moments) == "table" and db.moments or {}
	local wanted = {}
	local on = Active() and db.enabled == true
	if mine and on then
		for _, entry in ipairs(mine.list) do
			if switches[entry.row.key] == true then
				wanted[entry.row.slot] = entry
				if not slots[entry.row.slot] then Create(entry.row.slot) end
				-- The wards' route to a cast's school is tried once, with the first ward.
				if entry.row.school and not Sense.castRoute.probed then Sense.ProbeSchool() end
			end
		end
	end
	wipe(byId)
	wipe(settledOn)
	if mine then
		for _, entry in ipairs(mine.list) do settledOn[entry.row.key] = switches[entry.row.key] == true end
	end
	local now = GetTime()
	for n = 1, MAX do
		local slot = slots[n]
		if slot then
			local entry = wanted[n]
			if entry and slot.button then
				slot.row, slot.id, slot.name, slot.entry = entry.row, entry.id, entry.name, entry
				slot.needs = Sense.NeedSet(entry.row)
				slot.armed = true
				SetIcon(slot, entry.icon)
				if entry.id then byId[entry.id] = slot end
				ReadKey(slot)
				SetMouse(slot)
				if entry.row.items then Sense.CountItems(slot) end
				if entry.row.drink then
					Sense.CountDrinks(slot)
					if slot.drinkIcon then SetIcon(slot, slot.drinkIcon) end
				end
				Arm(slot)
				Seed(slot, now)
				if header then
					header:SetFrameRef("m" .. n, slot.button)
					header:SetAttribute("manners-on-" .. n, true)
					header:SetAttribute("manners-keep-" .. n, entry.row.peace == true)
					header:SetAttribute("manners-calm-" .. n, entry.row.calm == true)
				end
			else
				slot.armed = false
				Disarm(slot)
				if header then
					header:SetAttribute("manners-on-" .. n, false)
					header:SetAttribute("manners-calm-" .. n, false)
				end
				if slot.button:IsShown() then slot.button:Hide() end
			end
		end
	end
	local any = false
	for n = 1, MAX do
		if slots[n] and slots[n].armed then any = true end
	end
	-- The spell a row brings back (Cold Snap's Ice Block): its own button's clock
	-- where that button is armed, else a clock kept just for it.
	local kept = {}
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			slot.partner = nil
			local key = slot.row.partner
			if key then
				local holder
				for m = 1, MAX do
					if slots[m] and slots[m].armed and slots[m].row.key == key then holder = slots[m] end
				end
				local entry = mine and mine.byKey[key]
				if not holder and entry and entry.id then
					holder = shadows[key]
					if not holder or holder.id ~= entry.id then holder = { row = entry.row, id = entry.id, shadow = true } end
					kept[key] = holder
					byId[entry.id] = holder
					Seed(holder, now)
				end
				slot.partner = holder
			end
		end
	end
	wipe(shadows)
	for key, holder in pairs(kept) do shadows[key] = holder end
	if any then
		Place(db.prompt)
		Sense.ReadScale()
	end
	-- What Wanted compares against, kept even with nothing armed so an idle scan
	-- sees no change.
	placedSerial = Prompt.state and Prompt.state.styleSerial
	placedSize = type(db.moments) == "table" and db.moments.cardSize or nil
	if header and header:GetAttribute("state-" .. STATE) ~= "peace" then
		header:SetAttribute("state-" .. STATE, "peace")
	end
	for n = 1, MAX do
		local slot = slots[n]
		if slot then
			-- A button for a fall that a fight ended in the middle of stays up, lit.
			local stays = keepLit and slot.armed and slot.row.peace == true and slot.state == "lit"
			if not stays then
				slot.state, slot.why = "dark", (slot.row and slot.row.peace == true) and "no need yet" or "not in a fight"
				slot.face:SetAlpha(0)
				slot.fading, slot.fadeTo, slot.openUntil = false, 0, nil
				slot.cover:Hide()
				slot.ring:Hide()
				Card.Hint(slot, nil)
				Card.Tag(slot, false)
				slot.hover:Hide()
				GlowOn(slot, false)
				-- The driver hides what it showed for a fight but leaves a keep button to
				-- Lua: every armed button that is not lit goes down here.
				if slot.armed and slot.button:IsShown() then slot.button:Hide() end
			end
		end
	end
	SetRegistered()
	Route()
	settledEnabled, settledCaps, dirtyRefresh = on, mine, false
	-- A drink lights at once after a fight, a reload or a change in the options,
	-- without waiting for a mana tick.
	for n = 1, MAX do
		if slots[n] and slots[n].armed and slots[n].row.calm then
			SchedulePeace()
			break
		end
	end
end

-- Whether a scan has anything to do here. With nothing learned and nothing ever
-- made: one field read and no question to the client. Once made, plain fields
-- are compared and the lockdown is asked only when one changed.
function Moments:Wanted()
	local mine = caps.moments
	if (mine == nil or mine.n == 0) and next(slots) == nil then return false end
	local db = Profile()
	if not db then return false end
	local changed = dirtyRefresh
	if not changed then
		if (Active() and db.enabled == true) ~= (settledEnabled == true) or mine ~= settledCaps then
			changed = true
		else
			local m = db.moments
			-- The prompt's shape (a drag, a look, the font, the scale, the list: all end
			-- in ApplyStyle, which moves the serial) and the card size.
			if (Prompt.state and Prompt.state.styleSerial) ~= placedSerial
				or (type(m) == "table" and m.cardSize or nil) ~= placedSize then
				changed = true
			elseif mine and type(m) == "table" then
				for _, entry in ipairs(mine.list) do
					if (m[entry.row.key] == true) ~= (settledOn[entry.row.key] == true) then
						changed = true
						break
					end
				end
			end
		end
	end
	return changed and not InCombatLockdown()
end

function Moments:Resume()
	dirtyRefresh = true
	if ev then
		ev:RegisterEvent("PLAYER_REGEN_DISABLED")
		ev:RegisterEvent("UPDATE_BINDINGS")
	end
	SetRegistered()
	return self:Refresh()
end

---------------------------------------------------------------------------
-- the preview: where the buttons sit, shown out of a fight
---------------------------------------------------------------------------

local PREVIEW_SECONDS = 120

local function Say(text)
	if ns.addon and ns.addon.Print then ns.addon:Print(text) end
end

-- The armed slots, calm ones (the drink) or fight ones.
local function ArmedGroup(calm)
	local out = {}
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and (slot.row.calm == true) == calm then out[#out + 1] = slot end
	end
	return out
end

-- Whether any button for the moment is armed (the launcher and the options ask).
function Moments.AnyArmed()
	for n = 1, MAX do
		if slots[n] and slots[n].armed then return true end
	end
	return false
end

function Moments.Previewing()
	return previewing == true
end

-- The bar over the prompt while it is moved (made with the drag frame).
function Moments.Mover()
	return anchorLabel
end

-- Every card of the group in its own place, marked and pulsing, so the player
-- sees where each will appear; the other secure slots hidden.
local function PreviewShow(group)
	local inGroup = {}
	for _, slot in ipairs(group) do inGroup[slot] = true end
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			local shown = inGroup[slot] == true
			slot.routed = shown
			if shown then
				-- Over the options window it was opened from, for as long as it is shown.
				slot.button:SetFrameStrata(PREVIEW_STRATA)
				slot.button:Show()
				slot.inner:SetAlpha(1)
				slot.face:SetAlpha(1)
				slot.fading, slot.fadeTo = false, 1
				Card.ShowReason(slot, "lit")
				Card.Tag(slot, true)
				Card.Pulse(slot, true)
			else
				if slot.button:IsShown() then slot.button:Hide() end
				slot.face:SetAlpha(0)
				Card.Tag(slot, false)
				Card.Pulse(slot, false)
			end
		end
	end
end

local function EndPreview()
	if not previewing then return end
	ClosePreview()
	-- Every macro armed again, every card dark and out of sight, the drink judged.
	Moments:Refresh()
	-- The settings back where the move was started from.
	if reopenOptions and ns.OpenOptions and not InCombatLockdown() then
		reopenOptions = false
		ns.Guard("options reopen", ns.OpenOptions, "combat")
	end
	reopenOptions = false
	if ns.RefreshOptionsDisplay then ns.Guard("options repaint", ns.RefreshOptionsDisplay) end
end
Moments.EndPreview = EndPreview

-- Lights the combat prompt, marked as a preview, so the player sees where it
-- sits and can drag it. It stays until they say they are done (the button
-- again, a right-click on it), a fight starts, or PREVIEW_SECONDS pass. Nothing
-- casts from it: every macro is taken off the buttons and every cover is up,
-- whatever the mouse says. Out of a fight only; a fight that begins ends it
-- before the lockdown (Take). `quiet`: a restyle showing it again says nothing.
function Moments.Preview(quiet, move)
	if InCombatLockdown() or Sense.fighting then
		if not quiet then Say(L["|cffff8080not during a fight|r -- the preview can be shown once it ends."]) end
		return false
	end
	if previewing then ClosePreview() end
	if Moments:Wanted() then Moments:Refresh() end
	local fightCards, calmCards = ArmedGroup(false), ArmedGroup(true)
	if #fightCards + #calmCards == 0 then
		if not quiet then Say(L["No combat actions are enabled for this character."]) end
		return false
	end
	if not quiet then
		Say(L["Showing the combat prompt. Drag it to move it, and right-click it or press Done moving when you are finished. Nothing casts from the preview."])
	end
	-- A move puts the settings away, so nothing covers the prompt, and the bar
	-- over it says how to finish.
	if move then
		if ns.OptionsOpen and ns.OptionsOpen() then
			reopenOptions = true
			if ns.CloseOptions then ns.Guard("options close", ns.CloseOptions) end
		end
	end
	moving = move == true
	previewing = true
	previewSerial = previewSerial + 1
	local serial = previewSerial
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			Disarm(slot)
			slot.cover:Show()
		end
	end
	Place(Profile().prompt)
	PreviewShow(#fightCards > 0 and fightCards or calmCards)
	if ns.RefreshOptionsDisplay then ns.Guard("options repaint", ns.RefreshOptionsDisplay) end
	local timer = _G.C_Timer
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return true end
	timer.After(PREVIEW_SECONDS, function()
		if serial == previewSerial and previewing then ns.Guard("moments", EndPreview) end
	end)
	return true
end

-- The options window's one button: show the preview, or finish it.
function Moments.TogglePreview()
	if previewing then
		EndPreview()
		return false
	end
	return Moments.Preview(nil, true)
end

-- A setting that changes how the prompt looks: applied at once, and shown on
-- the preview, which comes up for it (quietly) so each change is seen as it is
-- made, and stays until the player is done with it.
function Moments.Restyle()
	if InCombatLockdown() or Sense.fighting then return false end
	Moments:Refresh()
	Moments.Preview(true)
	return true
end

-- The options' gallery trying a look on the combat prompt (nil: the chosen one
-- back). Shown on the preview, which comes up for it.
function Moments.TryLook(key)
	if InCombatLockdown() or Sense.fighting then return false end
	Moments.tried = key
	return Moments.Restyle()
end

-- The sound the combat prompt plays, once, so the switch is heard as it is set.
function Moments.SampleSound()
	if type(_G.PlaySound) == "function" then ns.Guard("combat alert sound", _G.PlaySound, ALERT_SOUND) end
end

---------------------------------------------------------------------------
-- the fight: events registered at the pull, dropped at the release
---------------------------------------------------------------------------

local function Register(name, unit)
	if not Sense.accepted[name] or fightEvents[name] then return end
	if unit then ev:RegisterUnitEvent(name, unit) else ev:RegisterEvent(name) end
	fightEvents[name] = true
end

local function RegisterFight()
	local health, groupHealth = false, false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			health = health or slot.needs.lowhealth or slot.needs.friendlowhealth
			groupHealth = groupHealth or slot.needs.partylowhealth
		end
	end
	if groupHealth then
		Register("UNIT_HEALTH")
		Register("UNIT_MAXHEALTH")
		Register("GROUP_ROSTER_UPDATE")
	elseif health then
		Register("UNIT_HEALTH")
		Register("UNIT_MAXHEALTH")
	end
	for n = 1, MAX do
		local slot = slots[n]
		-- A calm button (the drink) is dark in a fight and wants nothing from it.
		if slot and slot.armed and not slot.row.calm then
			local needs = slot.needs
			if needs.casting or needs.interruptible then
				for _, name in ipairs(TARGET_CAST) do Register(name, "target") end
			end
			if needs.casting or needs.enemy or needs.inrange or needs.stealable or needs.removable then
				Register("PLAYER_TARGET_CHANGED")
			end
			if needs.lowmana or needs.lowpower then
				Register("UNIT_POWER_UPDATE", "player")
				Register("UNIT_MAXPOWER", "player")
			end
			if needs.missingown then Register("UNIT_AURA", "player") end
			if needs.stuck and type(_G.C_LossOfControl) == "table" then
				Register("LOSS_OF_CONTROL_ADDED")
				Register("LOSS_OF_CONTROL_UPDATE")
			end
			if needs.ready or needs.itemready then Register("SPELL_UPDATE_COOLDOWN") end
			if needs.itemready then Register("BAG_UPDATE_DELAYED") end
			if needs.schoolhit then Register("UNIT_COMBAT", "player") end
			-- A ward lights on the target's cast too, once the fight has shown its school.
			if needs.schoolhit then
				for _, name in ipairs(TARGET_CAST) do Register(name, "target") end
			end
			if needs.stealable or needs.removable then Register("UNIT_AURA", "target") end
		end
	end
end

-- The pull as the addon's own handler gets it (Core.lua), while the lockdown is
-- not yet on: what a secure button may only be given out of a fight. Keys and
-- the mouse as bound now, and the gems counted once, the macro of the gem button
-- listing the kinds in the bags at this moment; a flush never counts.
function Moments:Take()
	if InCombatLockdown() then return end
	-- A look under the pointer in the options is not the one the fight wears.
	if Moments.tried then
		Moments.tried = nil
		Moments:Refresh()
	end
	-- A fight starting in the middle of a preview: every macro is armed again and every
	-- card dark before the lockdown, which would leave them as the preview left them.
	if previewing then Moments:Refresh() end
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			ReadKey(slot)
			SetMouse(slot)
			if slot.row.items then
				Sense.CountItems(slot)
				Arm(slot)
			end
			-- A calm button has no macro in a fight, so a key bound to it does nothing.
			if slot.row.calm then Disarm(slot) end
		end
	end
end

-- The pull, as the frame gets it: keys, mouse, clocks, the fight's events, every
-- armed button dark with its cover up, and ONE look at the situation at once, so
-- a stun, a cast or a low bar that began before the pull is seen without waiting
-- for an event.
local function Pull()
	local now = GetTime()
	local any = false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			any = true
			ReadKey(slot)
			SetMouse(slot)
			slot.tally = NewTally()
			slot.trailAt, slot.trailCount, slot.heldCount = nil, 0, 0
			slot.onGCD, slot.flip, slot.castOn, slot.castInfo = nil, nil, nil, nil
			slot.state, slot.why, slot.openUntil, slot.heldWhy = "dark", nil, nil, nil
			slot.ring:Hide()
			Card.Hint(slot, nil)
			Seed(slot, now)
			slot.cover:SetShown(slot.mouseOn == true)
		end
	end
	if not any then return end
	for _, holder in pairs(shadows) do
		holder.onGCD = nil
		Seed(holder, now)
	end
	wipe(Sense.lastHit)
	Sense.fighting = true
	-- The out-of-a-fight events are dropped for the fight.
	for name in pairs(peaceEvents) do ev:UnregisterEvent(name) end
	wipe(peaceEvents)
	RegisterFight()
	if moveOn then WatchShow(now) end
	JudgeAll()
	Schedule()
end

-- PLAYER_REGEN_ENABLED, out of the lockdown: the fight's events dropped, every
-- cover down, and the buttons armed again.
function Moments:Release()
	if next(slots) == nil then return end
	Sense.fighting = false
	Sense.locAt = nil
	local keepLit = false
	for name in pairs(fightEvents) do
		if ev then ev:UnregisterEvent(name) end
		fightEvents[name] = nil
	end
	wipe(lastFight)
	for n = 1, MAX do
		local slot = slots[n]
		if slot then
			lastFight[n] = { key = slot.row and slot.row.key, tally = slot.tally, why = slot.why, state = slot.state, armed = slot.armed }
			slot.cover:Hide()
			slot.ring:Hide()
			Card.Hint(slot, nil)
			slot.openUntil = nil
			if slot.armed and slot.row.peace == true and slot.state == "lit" then
				-- A fight ending mid-fall: the button stays up until a read says you landed.
				keepLit = true
			else
				if slot.state ~= "dark" then Apply(slot, "dark") end
				slot.face:SetAlpha(0)
				slot.fading = false
			end
		end
	end
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and slot.tally.leak > 0 and not told then
			told = true
			ns.Trail("fight", "a click reached an out-of-sight combat action")
		end
	end
	dirtyRefresh = true
	self:Refresh(keepLit)
	if watch and moveOn then WatchShow(GetTime()) end
end

-- Your own cast went out: Manners' own clock for it, the clocks it starts or
-- clears in the other rows, and the answer to a press.
-- What a cast of one row does to another's clock: a ward starts its twin's, Cold
-- Snap clears the clocks of the spells it brings back.
local function Cross(slot, other)
	if slot.row.shares == other.row.key then other.readyAt = slot.readyAt end
	for _, key in ipairs(slot.row.resets or {}) do
		if other.row.key == key then other.readyAt = nil end
	end
end

local function Went(slot)
	if slot.waitUntil and GetTime() <= slot.waitUntil then
		slot.waitUntil = nil
		slot.went = true
		slot.tally.out = slot.tally.out + 1
		Trail(slot, "went out", true)
		return true
	end
	return false
end

local function OwnCast(spellId)
	local id = plain(spellId)
	if type(id) ~= "number" then return end
	local now = GetTime()
	local slot = byId[id]
	if slot then
		local _, start, duration = Sense.Cool(id)
		local left = (type(start) == "number" and type(duration) == "number" and duration > 1.5) and (start + duration - now) or nil
		slot.readyAt = now + ((left and left > 1.5) and left or (slot.row.cooldown or 0))
		slot.castAt = now
		for n = 1, MAX do
			local other = slots[n]
			if other and other.armed and other ~= slot then Cross(slot, other) end
		end
		for _, holder in pairs(shadows) do
			if holder ~= slot then Cross(slot, holder) end
		end
		if not slot.shadow then Went(slot) end
	end
	-- A gem's use casts a spell of its own: any own cast inside the press window
	-- answers a press of the gem, and its own clock begins.
	for n = 1, MAX do
		local gem = slots[n]
		if gem and gem.armed and gem.row.items and gem ~= slot and Went(gem) then
			gem.readyAt = now + (gem.row.cooldown or 0)
		end
	end
	if Sense.fighting then Schedule() end
	if slot and slot.row.peace == true then
		Judge(slot, now)
		Route()
	end
	-- A drink's own clock begins with a cast of the drink spell, or with any cast
	-- inside the window of a press (which also covers a "Refreshment").
	for n = 1, MAX do
		local calm = slots[n]
		if calm and calm.armed and calm.row.drink then
			local went = Went(calm)
			if went or Sense.DrinkSpell(calm, id) then
				-- The clock begins; the aura of this drink is not yet seen, and its
				-- spell is read by id too (a conjured refreshment is no "Drink").
				calm.castAt, calm.drinkCast, calm.auraSeen = now, id, nil
			end
		end
	end
	-- Mounting and shapeshifting are own casts too: the calm buttons look again.
	if not Sense.fighting then JudgeAll("calm") end
end

function Moments.OnEvent(event, unit, a, b, c, d)
	if event == "PLAYER_REGEN_DISABLED" then return Pull() end
	if event == "UPDATE_BINDINGS" then
		if not InCombatLockdown() then dirtyRefresh = true end
		return
	end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then return OwnCast(b) end
	if event == "PLAYER_STARTED_MOVING" then
		Sense.moving = true
		-- Moving stands you up: a drink's own clock ends.
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed and slot.row.calm then slot.castAt = nil end
		end
		JudgeAll("still")
		return WatchShow(GetTime())
	elseif event == "PLAYER_STOPPED_MOVING" then
		Sense.moving = false
		watchHold = GetTime() + WATCH_HOLD
		return JudgeAll("still")
	end
	if event == "PLAYER_CONTROL_LOST" then
		Sense.lostAt = GetTime()
		JudgeAll("stuck")
		return Schedule()
	elseif event == "PLAYER_CONTROL_GAINED" then
		Sense.lostAt, Sense.locAt = nil, nil
		JudgeAll("stuck")
		return Schedule()
	end
	if not Sense.fighting then
		-- Out of a fight: the calm buttons' events, each only a nudge to the flush.
		if event == "BAG_UPDATE_DELAYED" then
			for n = 1, MAX do
				local slot = slots[n]
				if slot and slot.armed and slot.row.calm then slot.bagsDirty = true end
			end
			return SchedulePeace()
		end
		if event == "UNIT_POWER_UPDATE" then
			local kind = plain(a)
			if type(kind) == "string" and kind ~= "MANA" then return end
			return SchedulePeace()
		end
		if event == "PLAYER_LEVEL_UP" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
			-- Level and life are inputs of the pick: the bags are counted again.
			for n = 1, MAX do
				local slot = slots[n]
				if slot and slot.armed and slot.row.calm then slot.bagsDirty = true end
			end
			return SchedulePeace()
		end
		if event == "UNIT_MAXPOWER" or event == "PLAYER_DEAD" then
			return SchedulePeace()
		end
		return
	end
	if event == "UNIT_AURA" then return Schedule() end
	if event == "GROUP_ROSTER_UPDATE" then return Schedule() end
	if event == "UNIT_COMBAT" then
		-- UNIT_COMBAT: unit, action, flag, amount, school.
		Sense.Hit(a, d, GetTime())
		return Schedule()
	end
	if event == "BAG_UPDATE_DELAYED" then
		-- The gems, counted on the bag event and never per flush.
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed and slot.row.items then Sense.CountItems(slot) end
		end
		return Schedule()
	end
	if event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
		-- Only your own: the client may tell of another unit's loss of control.
		local who = plain(unit)
		if type(who) == "string" and who ~= "player" then return end
		-- A fresh report of a loss of control the game would not name starts the guess at
		-- once (the control events may come late or not at all), as the break-free button's
		-- does; and the read is repeated, not left to the next event.
		if event == "LOSS_OF_CONTROL_ADDED" then Sense.locAt = GetTime() end
		JudgeAll("stuck")
		return Schedule()
	end
	if event == "PLAYER_TARGET_CHANGED" then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed then slot.castOn, slot.flip = nil, nil end
		end
		JudgeAll()
		-- A caster out of range or a spell cooling down is waited on by the flush.
		return Schedule()
	end
	if event == "SPELL_UPDATE_COOLDOWN" then
		-- The only place isOnGCD is read: the game says not to trust it anywhere else.
		local api = _G.C_Spell
		if type(api) == "table" and type(api.GetSpellCooldown) == "function" then
			for n = 1, MAX do
				local slot = slots[n]
				if slot and slot.armed and slot.id then
					local rec = plain(api.GetSpellCooldown(slot.id))
					-- (not `and ... or nil`: a plain false is the answer that matters)
					local flag
					if type(rec) == "table" then flag = plain(rec.isOnGCD) end
					slot.onGCD = flag
				end
			end
			-- The spell a row brings back keeps its flag too, though it has no button.
			for _, holder in pairs(shadows) do
				local rec = plain(api.GetSpellCooldown(holder.id))
				local flag
				if type(rec) == "table" then flag = plain(rec.isOnGCD) end
				holder.onGCD = flag
			end
		end
		return Schedule()
	end
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
		return Schedule()
	end
	-- The target's cast events: the handler running for "target" is itself the
	-- plain signal; the payload is never read.
	if unit ~= "target" then return end
	if CAST_START[event] then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed then slot.castOn, slot.flip = nil, nil end
		end
		JudgeAll("schoolhit")
		JudgeAll("casting")
		return Schedule()
	elseif CAST_STOP[event] then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed and slot.needs.casting then slot.castOn, slot.flip, slot.reread = false, nil, true end
		end
		Darken("casting", "your target is not casting")
		return Schedule()
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed then slot.flip = event == "UNIT_SPELLCAST_INTERRUPTIBLE" end
		end
		return JudgeAll("interruptible")
	elseif event == "UNIT_SPELLCAST_FAILED" then
		return JudgeAll("casting")
	end
end

---------------------------------------------------------------------------
-- for the fight summary, the mark, /manners debug and the self-test
---------------------------------------------------------------------------

local function Armed()
	local out = {}
	for n = 1, MAX do
		if slots[n] and slots[n].armed then out[#out + 1] = slots[n] end
	end
	return out
end

local function TallyWords(slot, tally)
	if tally.lit + tally.game + tally.pressedLit + tally.pressedGame + tally.pressedDark + tally.cover == 0 then
		return ("%s dark (%s)"):format(slot.row.key, tostring(slot.why or "no need"))
	end
	return ("%s lit %d, game %d, pressed %d, out %d, cover %d"):format(slot.row.key, tally.lit, tally.game,
		tally.pressedLit + tally.pressedGame + tally.pressedDark, tally.out, tally.cover)
end

-- The second line of a fight's summary: what each button saw. Nothing armed,
-- nothing to say.
function Moments.FightWords()
	local armed = Armed()
	if #armed == 0 then return nil end
	local parts = {}
	-- A calm button is dark in every fight: it would only say so.
	for _, slot in ipairs(armed) do
		if not slot.row.calm then parts[#parts + 1] = TallyWords(slot, slot.tally) end
	end
	if #parts == 0 then return nil end
	return table.concat(parts, "; ")
end

-- One line each, for Mark this moment: the verdict now, and what is on the screen.
function Moments.MarkWords()
	local armed = Armed()
	if #armed == 0 then return { "moments: none armed" } end
	local out = {}
	for _, slot in ipairs(armed) do
		local verdict = slot.state == "lit" and "lit" or (slot.state == "game" and ("left to the game: " .. tostring(slot.why)))
			or ("dark: " .. tostring(slot.why or "no need"))
		out[#out + 1] = ("moment %s %s, shown %s, cover %s, key %s%s%s"):format(slot.row.key, verdict,
			slot.button:IsShown() and "yes" or "no", slot.cover:IsShown() and "up" or "down", tostring(slot.keyLabel or "none"),
			slot.state ~= "dark" and (", says: " .. tostring(slot.reasonText)) or "",
			slot.heldWhy and (", held dark: " .. slot.heldWhy) or "")
	end
	return out
end

local function Yes(v) return v and "yes" or "no" end

function ns.MomentLines()
	local out = {}
	local rows = ns.MOMENTS[caps.class]
	if not rows then return out end
	local mine = caps.moments
	local can = Sense.can
	local db = Profile()
	local m = db and db.moments or {}
	local leaks = 0
	for n = 1, MAX do
		if slots[n] then leaks = leaks + (slots[n].leakTotal or 0) end
	end
	local refused = {}
	for kind, why in pairs(Sense.refused) do refused[#refused + 1] = kind .. " (" .. tostring(why) .. ")" end
	table.sort(refused)
	out[1] = ("moments: class %s, %d rows here, %d learned; the game's calls: alpha from a boolean %s, evaluate %s, curves %s, health percent %s, power percent %s; percent scale %s; refused calls: %s; events this client lacks: %s; lock flag proven: %s; the cover let a click through: %s")
		:format(tostring(caps.class), #rows, mine and mine.n or 0, Yes(can.bool), Yes(can.eval), Yes(can.curve),
			Yes(can.health), Yes(can.power), tostring(Sense.scale), #refused > 0 and table.concat(refused, ", ") or "none",
			#Sense.lacking > 0 and table.concat(Sense.lacking, ", ") or "none", Yes(Sense.lockProven),
			leaks > 0 and (leaks .. " times this session (or a macro of yours clicked it)") or "not this session")
	-- Where the cards sit and what they wear, and whether the global cooldown can be read.
	do
		local placed = Moments.placed
		local lookKey, picture
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed and slot.cardLook then
				lookKey, picture = slot.cardLook, slot.picture
				break
			end
		end
		out[1] = out[1] .. ("; cards: %s of the prompt, %sx%s, %s placed, %s columns, look %s (picture: %s); global cooldown: %s")
			:format(placed and placed.side or "none", tostring(placed and placed.w), tostring(placed and placed.h),
				tostring(placed and placed.n or 0), tostring(placed and placed.cols or 0), tostring(lookKey or "none"),
				tostring(picture or "none"), Sense.GcdWord())
	end
	-- The wards' route to the school of a cast (Sense.CastSchool).
	local route, routeWhy = Sense.SchoolRoute()
	out[#out + 1] = ("moments: cast school: %s (%s)"):format(route, routeWhy)
	for _, row in ipairs(rows) do
		local entry = mine and mine.byKey[row.key]
		local slot = slots[row.slot]
		local tally = slot and slot.tally or NewTally()
		if not BUILT[row.key] then
			out[#out + 1] = ("moment %s: not built yet"):format(row.key)
		elseif not entry then
			out[#out + 1] = ("moment %s: not learned"):format(row.key)
		else
			local armed = slot and slot.armed and slot.armedMacro
			-- Pasted into public issues: the self-cast line holds the character's name.
			if armed then armed = tostring(armed):gsub("^/target [^\n]*", "/target <you>") end
			local what = entry.id and "spell" or "items"
			local ident = tostring(entry.id or table.concat(row.items or {}, "/"))
			if row.drink then
				what = "drink"
				ident = slot and slot.drinkPick and ("item:" .. slot.drinkPick) or "no drink in your bags"
			end
			local shape = slot and slot.armed and slot.shape and (" [" .. slot.shape .. "]") or ""
			out[#out + 1] = ("moment %s: %s %s %s, learned yes, switch %s, %s, key %s, slot %d, %s, now %s; last fight lit %d, game %d, pressed %d, out %d, silent %d"):format(
				row.key, what, ident, tostring(entry.name),
				m[row.key] == true and "on" or "off",
				armed and ("armed (" .. tostring(armed):gsub("\n", " | ") .. ")" .. shape) or (slot and slot.tooLong and "macro too long, not armed" or "not armed"),
				tostring(slot and slot.keyLabel or (type(GetBindingKey) == "function" and (GetBindingKey("CLICK MannersMoment" .. row.slot .. ":LeftButton")) or "none")),
				row.slot, (slot and slot.state ~= "dark" and Moments.selected ~= slot and Moments.yielded)
					and "one click, under the buff prompt while it offers a buff" or "one click",
				slot and (slot.state == "dark" and ("dark: " .. tostring(slot.why or "no need")) or slot.state) or "dark",
				tally.lit, tally.game, tally.pressedLit + tally.pressedGame + tally.pressedDark, tally.out, tally.silent)
		end
	end
	return out
end

-- For the self-test (Selftest.lua, group fight): one { warn, text } per row of
-- this client's set, and the counts the page's lines hang on. A fact about the
-- client is a PASS; a switched-on button that was never made, a header that is
-- not at peace, a macro that did not fit or a cover that let a click through is
-- a WARN.
function Moments.SelfRows()
	local out = {}
	local rows = ns.MOMENTS[caps.class]
	if not rows then return out end
	local mine = caps.moments
	local db = Profile()
	local m = db and db.moments or {}
	for _, row in ipairs(rows) do
		local entry = mine and mine.byKey[row.key]
		local slot = slots[row.slot]
		local text, warn
		if not BUILT[row.key] then
			text = "not built yet"
		elseif not entry then
			text = "not learned"
		elseif not (Active() and db and db.enabled == true and m[row.key] == true) then
			text = "switched off"
		elseif not (slot and slot.button) then
			text, warn = "switched on, but the button was never made", true
		elseif slot.tooLong then
			text, warn = "the armed macro does not fit in 255 characters", true
		elseif row.drink and not slot.armedMacro and not slot.drinkPick then
			text = "switched on; no drink in your bags"
		elseif row.drink and not slot.armedMacro and (Sense.fighting or InCombatLockdown()) then
			text = "switched on; a fight clears its macro until the fight ends"
		elseif not slot.armedMacro then
			text, warn = "the button has no macro armed", true
		else
			local state = header and header:GetAttribute("state-" .. STATE)
			local key = slot.keyLabel and ("key " .. slot.keyLabel) or "no key: a click on it casts while it is lit"
			if state ~= "peace" and not (state == "fight" and Sense.fighting) then
				text, warn = ("button made, but its header says %s, not peace"):format(tostring(state)), true
			else
				text = ("button made, header %s, %s"):format(tostring(state), key)
			end
			-- This session's, on the row that leaked: a leak long ago says nothing of now.
			local leaks = slot.leakTotal or 0
			if leaks > 0 then
				text = text .. ("; the cover let a click through %d times this session (or a macro of yours clicked it)"):format(leaks)
				warn = true
			end
		end
		out[#out + 1] = { warn = warn, text = row.key .. ": " .. text, key = row.key, command = Moments.Command(row.key),
			armed = slot and slot.armed and entry ~= nil and BUILT[row.key] }
	end
	return out
end

function Moments:Button(n) return slots[n] and slots[n].button end
-- The fall watch, and the clock kept for a spell with no button of its own.
function Moments:Watch() return watch end
function Moments:Shadow(key) return shadows[key] end
-- What a button shows: its art and where it is fading to (face is the plain
-- gate, inner the layer the game paints).
function Moments:Look(n)
	local slot = slots[n]
	if not slot then return nil end
	return { icon = slot.card.icon, glow = slot.flare, key = slot.keyText, face = slot.face, inner = slot.inner,
		ring = slot.ring, hint = slot.hint, alpha = slot.fadeTo, fader = fader, card = slot.card,
		hintCard = slot.hintCard, flare = slot.flare, tag = slot.tag, mark = slot.mark, hover = slot.hover,
		reason = slot.card.lines.reason, name = slot.card.lines.name, w = slot.cardW, h = slot.cardH }
end
function Moments:Slot(n) return slots[n] end
function Moments:Header() return header end
function Moments:Frame() return ev end
function Moments:Fader() return fader end

-- The probe, and what it learns of a mage's moments, before anything asks.
do
	local probe = ns.ProbeCapabilities
	function ns.ProbeCapabilities(...)
		local result = probe(...)
		Moments.Learn()
		return result
	end
end
