-- Manners -- the on-screen prompt.
--
-- The button is a SecureActionButtonTemplate: Blizzard owns the click, and its
-- attributes, size, scale and position are protected in combat. Every visual
-- lives on `art`, an ordinary child frame, so animations never touch protected
-- state. Everything is drawn from one white texture plus gradients, alpha and
-- motion: a missing atlas or art file renders as a green placeholder, and a
-- solid texture cannot fail.

local _, ns = ...
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L

local LSM = LibStub("LibSharedMedia-3.0")
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Guarded because a library that changed its Register signature must not stop
-- the prompt being built; the addon is then silent, not broken.
ns.Guard("register sound", function()
	LSM:Register("sound", ns.SOUND_KEY, ns.SOUND_FILE)
end)

function ns.PlayPromptSound(file)
	if not file or file == "None" then return end
	-- noDefault: an uninstalled pack's entry would resolve to "None" and play
	-- nothing. A missing key falls back to our sound here, not in the saved
	-- setting: a pack loading after this addon has not registered yet.
	local data = LSM:Fetch("sound", file, true) or LSM:Fetch("sound", ns.SOUND_KEY, true)
	if not data then return end
	local willPlay = ns.plain(PlaySoundFile(data, "Master"))
	-- The client can refuse a file outright. A toggle that is on and silent is
	-- the whole complaint, so say which sound it was rather than nothing.
	if willPlay == false and ns.db and ns.db.profile.verbose then
		ns.addon:Print(L["|cffff8080%s did not play.|r Pick another sound."]:format(tostring(file)))
	end
end

local Prompt = {}
ns.Prompt = Prompt

local WHITE = "Interface\\Buttons\\WHITE8X8"

local button, art, textLayer
local panel, hairTop, hairBottom
-- The drop shadow: steps of falloff from a crisp dark rim out to almost
-- nothing, each a little lower, so the light reads as coming from above.
local shadows
local SHADOW_STEPS = {
	-- spread, alpha, drop
	{ 1, 0.50, 0 },
	{ 3, 0.16, 1 },
	{ 6, 0.09, 2 },
	{ 10, 0.05, 3 },
}
-- Light falling on the top half of the glass. The panel's own gradient darkens
-- towards the bottom; this is the other half of the same idea.
local sheen
-- The framed look's four edges, from the same white texture. A backdrop needs
-- BackdropTemplate and a border needs art or an atlas, either of which this
-- client may lack; four one-pixel rectangles cannot fail.
local edges
local accentTop, accentBottom, sweep, sweepFrame
local iconBack, icon, glowFrame, iconMask
-- A halo round the icon, starting at the ring so the icon stays readable at
-- every point of the pulse. glowFrame is a frame of its own so it can be
-- animated, and a child frame draws over its parent. See Halo.
local glowHalo
-- A dark line between the icon and its ring, and a shade over the icon's lower
-- half, so the ring reads as a frame rather than a flat square.
local iconEdge, iconShade
-- The global cooldown, swept over the icon. See SyncCooldown.
local cooldown
-- The confirmation a landed buff gets, and the light on a new favour: a ring
-- popping outward from the icon, and a band of light crossing the panel once.
-- Both play once and stop.
local burstFrame, burstHalo, shineFrame, shineLeft, shineRight
-- Whether the panel colour is dark enough for the reason line to carry a tint
-- of the reason colour. On a light panel a tinted grey loses its contrast.
local tintSub
-- What PaintAccent last painted, so a repaint in the same colour costs nothing.
local accentPainted
local nameText, subText, countChip, countText, queueRows
-- A flood of colour over the whole panel for the half-second after a click:
-- the panel is where the eye already is.
local resultFill
-- The queue list hangs outside the panel, so it needs its own background.
-- queueBars are the reason stripes down the left of each row.
local queueBack, queueHair, queueBars
local queueTextX = 0
-- The look drawn from a file of its own (Looks/), or nil for the three drawn
-- here. Looks/Looks.lua says what it is asked and when.
local activeLook
-- Goes into every click line, so a log says which build produced it.
ns.BUILD = "1.5.3"

local current, testMode, testExpiry, lastTop, appliedKey, lastClickAt, lastPreClickAt, lastSkipAt
-- Why the last painted person was on the panel, beside lastTop's who.
local lastTopReason
-- The newest favour stamp a repaint has seen, and how old a favour can be and
-- still count as just done; one first seen late is not news.
local seenDebtAt
local ARRIVAL_SECONDS = 3
-- Its own stamp rather than one of the three above: the refusal it rate-limits
-- happens on presses none of those are counting.
local lastStaleAt

-- What the last resolved press left on the button. The debounce may skip
-- re-resolving only while the button still holds this.
local pressKey
-- Whether the press being resolved is on somebody the fresh queue no longer
-- holds (the hold or the empty-queue fuse kept them). Their entry's range
-- reading is from a scan the latest one overruled, so it says nothing about
-- whether a shout reached them. Set in PreClick, read and cleared in PostClick.
local pressStale

-- Who the macro frozen for a fight is aimed at, kept when a disarm in that
-- fight (switched off, unlocked, a preview) could only clear `current`.
local frozenEntry

-- How many names this file has written into ns.lastGave since it was last
-- emptied; see OnPostClick.
local lastGaveCount = 0
local LAST_GAVE_CAP = 400

-- The moment of a press the cooldown turned away, stamped in PreClick and
-- consumed by PostClick in the same frame. Stamped ahead of the combat return:
-- in a fight only the bookkeeping can be refused.
local cooldownPressAt
-- ...and what the button held when the guard disarmed it, so PostClick can put
-- it back; left disarmed, a fight starting before the next scan froze the
-- prompt empty.
local guardedEntry
-- ...and the spoken line it carried, put back with it so the tooltip and the
-- next press quote the same roll.
local guardedPhraseKey, guardedPhraseText

---------------------------------------------------------------------------
-- hysteresis
--
-- The scan rebuilds the queue 2.5 times a second, and in a crowd its top
-- churns. Three floors -- who is on it, whether it is shown, the sound -- each
-- refuse a change for a short time and then allow it.
---------------------------------------------------------------------------

-- How long a freshly painted candidate is protected from one of equal or lower
-- priority. Somebody strictly better takes the panel at once.
local HOLD_SECONDS = 1.5

-- How long an empty queue is given to refill before the prompt comes down.
-- Shorter than the hold: "there is nobody" should be believed quickly.
local EMPTY_FUSE_SECONDS = 0.75

-- How long the cursor on the panel keeps somebody the queue no longer has,
-- from the last scan that had them (heldAt). Reaching the panel and reading it
-- takes a second or two, and a passer-by the cursor found is kept by the
-- queue itself for ten seconds after it leaves them (Queue.lua), so this only
-- has to cover the last stretch. Past it the cursor is resting on the panel,
-- not reaching for it, and whoever the panel names has been gone as long.
local HOVER_SECONDS = 10

-- The floor between two sounds. Without it the sound is tied to the name
-- changing, and the name changing is exactly what churns.
local SOUND_FLOOR_SECONDS = 3

-- How long a click's outcome sits over the panel.
local OUTCOME_SECONDS = 0.6

-- The entry last painted and when, which the hold is measured against. The
-- whole entry, because re-arming the macro needs the buff as well as the name
-- after the queue has dropped them. And the queue the last pick was made
-- from, which a shout's press reads for everybody else it reaches (PostClick);
-- in a fight, the pull's own.
local heldEntry, heldAt, pickedFrom
-- When the queue first came back empty, cleared the moment it refills.
local emptyAt
-- Whether the cursor is on the panel: set by OnEnter, cleared by OnLeave and
-- by ClearHold. While it is, the hold and the fuse keep their clocks but not
-- their verdicts: the player is reaching for what the panel names, and
-- neither an empty scan nor somebody no better may pull it out from under the
-- cursor. Somebody strictly better still takes it, and a retired entry still
-- goes (a right-press skip, the never-offer list, a press resolved). Only a
-- token lost is forgiven, and for HOVER_SECONDS: see CursorHolds.
local hovering
-- The name on the panel a scan turned down (see NoteVerdicts), which the
-- cursor then no longer holds. Kept rather than asked of each scan: the
-- verdict is written by the scan that reached it -- a token finding them
-- covered, the memory letting them go -- and the next scan, with no token to
-- them, has nothing to say about them. Cleared when the panel is painted from
-- the queue again, and by ClearHold.
local heldTurnedDown
local lastSoundAt
-- Whether the panel is dimmed for combat, so the alpha is written once per
-- transition.
local combatHeld
-- Whether a drag actually started. The client delivers OnDragStop for every
-- drag gesture, including the ones OnDragStart refused (locked, in combat).
local dragging

-- What the last click turned into: "cast", "sent" or "failed", who it was
-- about, and the game's own words where it had any.
local outcomeKind, outcomeAt, outcomeName, outcomeDetail
-- Who the name line is about while an outcome is over it: the outcome expires
-- on the clock but its words stay until a repaint, and a press follows the
-- words.
local outcomePainted
-- Which outcome the expiry timer was set for, so a timer left from an earlier
-- outcome is ignored.
local outcomeGen = 0

-- The spoken line settled for the candidate on the button, and its key, so the
-- tooltip quotes the roll the press will cast.
local phraseKey, phraseText
-- Whether that line is on the button now: it is kept but left out for somebody
-- out of reach or just refused (see ApplyTarget), and the tooltip must agree.
local phraseArmed

-- Which side of the panel the queue list hangs off. Decided in ApplyStyle,
-- because the only things that move the prompt come back through it.
local queueAbove

-- Everything the hysteresis holds, dropped whenever the prompt goes down for a
-- reason of its own (switched off, unlocked, nothing learned), so coming back
-- up is a fresh start. The cursor with it: a panel that comes back up under a
-- cursor that has not moved is held again only once OnEnter says so, which
-- errs towards the ordinary hysteresis rather than a hold nothing ends.
local function ClearHold()
	heldEntry, heldAt, emptyAt = nil, nil, nil
	hovering, heldTurnedDown = nil, nil
end

-- Lights the fuse on an empty queue, once, and asks for a repaint when it has
-- burnt out rather than waiting for the next scan.
local function LightFuse(now)
	if emptyAt then return end
	emptyAt = now
	if C_Timer and C_Timer.After then
		C_Timer.After(EMPTY_FUSE_SECONDS + 0.05, function()
			ns.Guard("fuse repaint", Prompt.Refresh, Prompt)
		end)
	end
end

-- On the never-offer list with no favour to return, asked as BuildQueue asks
-- it, so the hold and the fuse drop a name listed by any route.
local function ListedWithoutDebt(name, now)
	if not (name and ns.IsNeverOffered and ns.IsNeverOffered(name)) then return false end
	local db = ns.db and ns.db.profile
	local debt = ns.owed and ns.owed[name]
	local owed = db and db.sources and db.sources.owed and debt
		and ns.DebtExpiry(debt) > now
	return not owed
end

-- Whether this entry was deliberately retired: blocked (the retry cooldown a
-- click wrote, or a right-press refusal), on the never-offer list with
-- nothing owed, or held back for PvP -- flagged since the paint, or in a
-- party a group cast or a shout would land on (Queue.lua, HeldForPvP). The
-- repaint and the press both ask this and must agree: a press on an empty
-- queue otherwise casts at whoever the panel still names.
local function Retired(entry, now)
	if ns.HeldForPvP(entry) then return true end
	return entry ~= nil and entry.name ~= nil
		and (ns.IsBlocked(entry.name, entry.buff and entry.buff.key, now)
			or ListedWithoutDebt(entry.name, now))
end

-- Called with BuildQueue's second return by every pass that builds a queue to
-- pick from, before it picks: true when the scan refused the whole queue for
-- your own state (mounted with "Hide the prompt while I'm mounted", dead, on a
-- taxi), otherwise [name] = true for everybody it turned down (found dead,
-- covered, out of range, held back while you save mana, let go from memory).
-- A verdict on whoever the panel holds -- the entry last painted, which is
-- the one armed -- ends the cursor's hold on them. A stubbed queue hands back
-- nothing, which is no verdict.
local function NoteVerdicts(verdicts)
	local entry = heldEntry or current
	local name = entry and entry.name
	if not (name and verdicts) then return end
	if verdicts == true or (type(verdicts) == "table" and verdicts[name] == true) then
		heldTurnedDown = name
	end
end

-- The cursor's hold (see hovering), which lets the ordinary hold and the fuse
-- run past their time. It forgives a token lost -- the cursor leaving the
-- person it found, a target cleared -- for HOVER_SECONDS, and nothing else:
-- somebody a scan found dead must not stay on the panel, and the press cast at
-- them, because the cursor happened to be resting on it (see NoteVerdicts).
local function CursorHolds(entry, now)
	if not (hovering and entry and entry.name and heldAt) then return false end
	if heldTurnedDown == entry.name then return false end
	return now - heldAt < HOVER_SECONDS
end

-- The list and its background live outside the panel, so hiding the button
-- does not hide them. Every branch that takes the prompt down has to say so.
local function HideQueue()
	if not queueRows then return end
	for i, fs in ipairs(queueRows) do
		fs:SetText("")
		queueBars[i]:Hide()
	end
	queueBack:Hide()
	queueHair:Hide()
	if activeLook then activeLook:PaintQueue(nil, 0, queueAbove) end
end

-- Show and Hide are protected, and in combat the client refuses both silently.
-- `false` means the panel stayed where the fight found it.
local function SetPanelShown(want)
	if InCombatLockdown() then return false end
	if want then button:Show() else button:Hide() end
	return true
end

-- Ends a move under way: the frame let go, where it landed saved, and the
-- prompt locked. Shared by the release and by a fight arriving mid-drag, which
-- must leave the prompt in the same place.
local function FinishDrag()
	dragging = nil
	button:StopMovingOrSizing()
	local point, _, relPoint, x, y = button:GetPoint()
	local p = ns.db.profile.prompt
	-- The client returns the offsets in the frame's scaled units; the profile
	-- keeps UIParent's. The frame's own scale is the one it was moved at, not
	-- p.scale, which can be ahead of the frame: a Scale slider moved in a fight
	-- waits for the fight to end before ApplyStyle applies it.
	local okScale, s = pcall(button.GetScale, button)
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

-- Below the panel normally, above it when the prompt sits in the bottom third
-- of the screen. Every call is guarded (an unplaced frame has no centre), and
-- the centre is converted from the prompt's scaled units to UIParent's.
local function QueueGoesAbove()
	local okCentre, _, y = pcall(button.GetCenter, button)
	if not okCentre or type(y) ~= "number" then return false end
	local okHeight, screenHeight = pcall(UIParent.GetHeight, UIParent)
	if not okHeight or type(screenHeight) ~= "number" or screenHeight <= 0 then return false end
	local ratio = ns.db.profile.prompt.scale
	local okOwn, own = pcall(button.GetEffectiveScale, button)
	local okParent, parent = pcall(UIParent.GetEffectiveScale, UIParent)
	if okOwn and okParent and type(own) == "number" and type(parent) == "number"
		and parent > 0 then
		ratio = own / parent
	end
	if type(ratio) ~= "number" or ratio <= 0 then ratio = 1 end
	return y * ratio < screenHeight / 3
end

-- What the macro on the button is aimed at: { targeted, selfCast, aimedAt },
-- or nil. PostClick copies it onto the pending click, so the settle handler
-- judges the press by what actually went out. Set beside appliedKey. This
-- client does not name a cast's recipient, so a /target of ours aimed at this
-- person is the only thing tying a press to a person.
local armed

-- Amber for a favour returned, the case worth noticing; the others stay quiet.
-- Picked to survive the commonest colour blindness: target and group differ in
-- lightness, owed and target are amber against blue.
-- Rec.601 greys: target 0.83, owed 0.79, group 0.56, nearby 0.54.
local REASON_COLOR = {
	target = { 0.62, 0.90, 1.00 },
	owed = { 1.00, 0.78, 0.30 },
	group = { 0.34, 0.60, 0.96 },
	nearby = { 0.52, 0.54, 0.62 },
	-- Somebody who asked in chat: a warm pink, apart from the four in hue and
	-- between owed and group in grey (0.68).
	asked = { 0.96, 0.52, 0.80 },
}

local REASON_KEY = { target = "reasonTarget", owed = "reasonOwed",
	group = "reasonGroup", nearby = "reasonNearby", asked = "reasonAsked" }
-- Your own buff (Queue.lua, SelfEntry).
REASON_KEY.self = "reasonSelf"

-- For somebody the set above still fails: chosen by search so the closest pair
-- is furthest apart in CIE76 under normal sight, protanopia and deuteranopia
-- (Machado et al. 2009); tests/scenarios/look2.lua holds it to that. Opt-in
-- under Prompt > Style. Rec.601 greys: target 0.92, owed 0.57, group 0.70,
-- nearby 0.47, asked 0.37.
local REASON_COLOR_CVD = {
	target = { 0.98, 0.96, 0.56 },
	owed = { 0.92, 0.48, 0.08 },
	group = { 0.42, 0.78, 1.00 },
	nearby = { 0.80, 0.20, 1.00 },
	-- A deep pink, searched for the same way against the four above, and
	-- darker than the violet and the orange: lightness survives all three
	-- ways of seeing.
	asked = { 0.72, 0.20, 0.34 },
}
-- Your own buff wears your group's colour in both sets rather than a sixth of
-- its own: five already strain what colour-blind sight can tell apart, and the
-- words ("You") say which it is. It is also where you stand: in the group.
REASON_COLOR.self = REASON_COLOR.group
REASON_COLOR_CVD.self = REASON_COLOR_CVD.group
local REASON_PALETTES = { standard = REASON_COLOR, colourblind = REASON_COLOR_CVD }

-- The colour for a reason in the player's palette; anything unknown reads as
-- the standard set.
local function ReasonColor(reason)
	local p = ns.db and ns.db.profile.prompt
	local set = REASON_PALETTES[p and p.reasonPalette] or REASON_COLOR
	return set[reason or "nearby"] or set.nearby
end

-- Whole minutes, like the refresh threshold: a ticking countdown reads as
-- urgency. Seconds only under a minute.
local function RemainingText(seconds)
	if type(seconds) ~= "number" or seconds <= 0 then return nil end
	if seconds < 60 then return L["%ds"]:format(math.floor(seconds)) end
	return L["%dm"]:format(math.floor(seconds / 60))
end

---------------------------------------------------------------------------
-- capability-checked drawing helpers
---------------------------------------------------------------------------

-- SetGradient changed signature between client generations and SetGradientAlpha
-- was removed. Try both, and fall back to a flat colour that always works.
local function Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
	if tex.SetGradient and CreateColor then
		if pcall(tex.SetGradient, tex, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then
			return true
		end
	end
	if tex.SetGradientAlpha then
		if pcall(tex.SetGradientAlpha, tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2) then
			return true
		end
	end
	tex:SetVertexColor(r1, g1, b1, a1)
	return false
end

local function Solid(parent, layer, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(WHITE)
	return t
end

-- A method this client may not have, called if it is there. The effects use a
-- few calls nobody here has watched run; a missing one costs that detail,
-- never the prompt.
local function Try(obj, method, ...)
	local fn = obj and obj[method]
	if type(fn) ~= "function" then return false end
	return (pcall(fn, obj, ...))
end

-- The soft glows round the icon, drawn once by tools/make-glow.py: white, with
-- the shape in the alpha, so they take the reason colour from SetVertexColor.
local GLOW = "Interface\\AddOns\\Manners\\Textures\\Glow"
local GLOW_ROUND = "Interface\\AddOns\\Manners\\Textures\\GlowRound"
-- Where the rim of the round glow sits, as a fraction of the texture's
-- half-width: RING_AT in tools/make-glow.py, which must agree.
local GLOW_RING_AT = 0.70

-- Where each piece of the square halo is cut from Glow.tga (SetTexCoord's
-- left, right, top, bottom): quarters for corners and a thin middle line for
-- sides, so every join has matching brightness.
local MID0, MID1 = 0.49, 0.51
local HALO_CUTS = {
	{ MID0, MID1, 0, 0.5 }, -- top
	{ MID0, MID1, 0.5, 1 }, -- bottom
	{ 0, 0.5, MID0, MID1 }, -- left
	{ 0.5, 1, MID0, MID1 }, -- right
	{ 0, 0.5, 0, 0.5 },     -- top-left
	{ 0.5, 1, 0, 0.5 },     -- top-right
	{ 0, 0.5, 0.5, 1 },     -- bottom-left
	{ 0.5, 1, 0.5, 1 },     -- bottom-right
}

-- A halo round a box: the eight pieces of the square one, and the ring a
-- rounded icon wears instead. Additive, so it is light added to what is there.
local function Halo(parent, layer, sublevel)
	local halo = { strips = {} }
	for i, cut in ipairs(HALO_CUTS) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(GLOW)
		t:SetTexCoord(cut[1], cut[2], cut[3], cut[4])
		t:SetBlendMode("ADD")
		halo.strips[i] = t
	end
	halo.round = parent:CreateTexture(nil, layer, nil, sublevel)
	halo.round:SetTexture(GLOW_ROUND)
	halo.round:SetBlendMode("ADD")
	halo.round:Hide()
	return halo
end

-- Placed round `box`, outside an inset of `gap`: `sx` out to the sides and `sy`
-- above and below. With `round` (a round icon's size, passed because the box
-- may not be laid out yet) the ring instead, its rim on the icon's edge.
local function PlaceHalo(halo, box, sx, sy, gap, round)
	local strips = halo.strips
	local top, bottom, left, right = strips[1], strips[2], strips[3], strips[4]
	for _, t in ipairs(strips) do
		t:ClearAllPoints()
		t:SetShown(not round)
	end
	halo.round:ClearAllPoints()
	halo.round:SetShown(round and true or false)
	if round then
		local size = round / GLOW_RING_AT
		halo.round:SetPoint("CENTER", box, "CENTER", 0, 0)
		halo.round:SetSize(size, size)
		return
	end
	top:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -gap, gap)
	top:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", gap, gap)
	top:SetHeight(sy)
	bottom:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -gap, -gap)
	bottom:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", gap, -gap)
	bottom:SetHeight(sy)
	left:SetPoint("TOPRIGHT", box, "TOPLEFT", -gap, gap)
	left:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", -gap, -gap)
	left:SetWidth(sx)
	right:SetPoint("TOPLEFT", box, "TOPRIGHT", gap, gap)
	right:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", gap, -gap)
	right:SetWidth(sx)
	-- Top-left, top-right, bottom-left, bottom-right.
	for i, at in ipairs({
		{ "BOTTOMRIGHT", "TOPLEFT", -gap, gap },
		{ "BOTTOMLEFT", "TOPRIGHT", gap, gap },
		{ "TOPRIGHT", "BOTTOMLEFT", -gap, -gap },
		{ "TOPLEFT", "BOTTOMRIGHT", gap, -gap },
	}) do
		local corner = strips[4 + i]
		corner:SetPoint(at[1], box, at[2], at[3], at[4])
		corner:SetSize(sx, sy)
	end
end

-- The whole halo in one colour: the fade is in the texture, so a vertex colour
-- per piece is all it takes.
local function PaintHalo(halo, r, g, b, alpha)
	for _, t in ipairs(halo.strips) do t:SetVertexColor(r, g, b, alpha) end
	halo.round:SetVertexColor(r, g, b, alpha)
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

-- The one question the click path asks. Deliberately not Core's "is the addon
-- switched on", which governs bookkeeping; this governs whether the button in
-- front of somebody should fire.
local function PromptIsLive()
	local db = ns.db and ns.db.profile
	if not db or not db.enabled then return false end
	-- Unlocked is drag mode, and a prompt being dragged must not cast.
	if not db.prompt.locked then return false end
	if testMode then return false end
	-- Belt and braces: BuildQueue already returns nothing with nothing to
	-- cast, so no mutation of this line can go red. It keeps the click path
	-- stating the same condition the panel does.
	if not ns.CanCastAnything() then return false end
	return true
end

-- The button's scripts are written out here rather than inside
-- Prompt:Create(): Lua 5.1 allows a function 60 upvalues, a closure's count
-- against the function it sits in, and written inline they took Create() past
-- the limit, so Prompt.lua failed to load at all (beta.6).

-- Whether the person the macro is about to be aimed at is known to be out of
-- reach at this moment, for PreClick to leave the spoken line out. The scan
-- that armed the macro can be a tick old, and a macro runs every line even
-- when its /cast fails (beta.8: two thank-yous, no buff). Only a unit token
-- still naming them is asked; a recycled one says nothing about them, and an
-- unknown answer keeps the line, as the scan's does.
local function OutOfReachNow(entry)
	if not (entry and entry.unit and entry.buff and entry.name) then return false end
	if ns.UnitFullName(entry.unit) ~= entry.name then return false end
	return ns.ReachNow(entry.unit, entry.buff) == false
end

-- PreClick runs before the secure handler reads the attributes, so out of
-- combat the target is re-resolved at the last moment: a nameplate token may
-- since have been recycled to somebody else. Every mouse button
-- arrives ("AnyDown"); only the left one casts.
local function OnPreClick(self, mouseButton)
	if mouseButton and mouseButton ~= "LeftButton" then return end
	local now = GetTime()
	-- The macro's own /target and hand-back are not the player choosing
	-- anybody; Core's PLAYER_TARGET_CHANGED ignores changes this close to it.
	ns.pressAt = now

	-- Asked before the combat return: in combat the frozen macro still goes
	-- out, and the bookkeeping can still be refused where the macro cannot.
	local ready, left = ns.CastReady()
	-- In combat a press late in the cooldown is queued by the client, so it
	-- counts as ready. Out of combat the whole cooldown is held back: a queued
	-- /cast would fire after /targetlasttarget.
	if InCombatLockdown() and not ready and left <= ns.SpellQueueWindow() then
		ready = true
	end
	-- Then the combat return: in combat nothing below can change the macro,
	-- since the attributes are frozen, so neither the target nor the spoken
	-- line (range, a refusal) is looked at again until the fight ends.
	cooldownPressAt = (not ready) and now or nil
	if InCombatLockdown() then
		pressStale = nil
		return
	end

	-- Down and up both land here; one rebuild per press, but only while the
	-- button still holds what that rebuild armed (an error or a cooldown in
	-- between can change it).
	if lastPreClickAt and (now - lastPreClickAt) < 0.25 then
		if not ready then
			guardedEntry = current
			guardedPhraseKey, guardedPhraseText = phraseKey, phraseText
			Prompt:ApplyTarget(nil)
		elseif appliedKey ~= pressKey then
			Prompt:ApplyTarget(nil)
		end
		return
	end
	lastPreClickAt = now
	pressKey = nil
	pressStale = nil

	-- A keypress on an empty prompt says why it is empty, or it looks like a
	-- broken binding. Commands and option names go in as arguments: they are
	-- not translated.
	if not self:IsShown() then
		local db = ns.db and ns.db.profile
		if db and not db.enabled then
			ns.addon:Print(L["Manners is |cffff8080switched off|r -- %s to start again."]
				:format("|cffffd100/manners on|r"))
		elseif ns.SnoozeLeft(now) then
			ns.addon:Print(L["Manners is snoozed until %s -- %s brings the prompt back now."]
				:format(ns.SnoozeEndsAt(), "|cffffd100/manners snooze off|r"))
		elseif ns.HiddenWhileMounted() then
			ns.addon:Print(L["the prompt stays away while you are mounted -- get off, or switch off %s on the %s tab."]
				:format("|cffffd100" .. L["Hide the prompt while I'm mounted"] .. "|r", L["When to offer"]))
		elseif not ns.CanCastAnything() then
			local class = ns.caps.class
			if class and ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class] then
				ns.addon:Print(ns.NO_CLASS_BUFFS)
			else
				ns.addon:Print(L["nothing learned to cast yet."])
			end
		elseif ns.SavingMana() then
			-- The option goes in by its own key, so a translation names the
			-- label the window shows.
			local _, resume = ns.SavingMana()
			-- Your own buff is kept while saving (Queue.lua, SelfEntry), so the
			-- sentence names it wherever "Myself" is on.
			local line = ns.OffersSelf()
				and L["nobody to buff right now -- saving mana until you are back to %d%%, so only your own buff and people who buffed you or asked are offered. The floor is %s on the %s tab."]
				or L["nobody to buff right now -- saving mana until you are back to %d%%, so only people who buffed you or asked are offered. The floor is %s on the %s tab."]
			ns.addon:Print(line:format(resume, "|cffffd100" .. L["Save mana: stop below (% mana)"] .. "|r", L["When to offer"]))
		else
			ns.addon:Print(L["nobody to buff right now."])
		end
		Prompt:ApplyTarget(nil)
		return
	end

	-- PreClick is the last chance to stop an unlocked or disabled prompt
	-- casting.
	if not PromptIsLive() then
		Prompt:ApplyTarget(nil)
		return
	end

	-- Nor during the global cooldown: disarmed here, the press never reaches
	-- the server to be refused. Its stamp is taken back so the next press
	-- resolves.
	if not ready then
		lastPreClickAt = nil
		guardedEntry = current
		guardedPhraseKey, guardedPhraseText = phraseKey, phraseText
		Prompt:ApplyTarget(nil)
		Prompt:SayWaiting(left)
		return
	end

	local queue, verdicts = ns.BuildQueue(hovering)
	NoteVerdicts(verdicts)
	local top = Prompt:PickTop(queue, queue[1])
	pickedFrom = queue
	local named = Prompt:PanelName()
	-- An empty queue under a panel still naming somebody: the press agrees with
	-- the screen (at worst the game refuses the cast, in red) rather than
	-- silently doing nothing. Not for somebody retired, and not under a flash
	-- about somebody else: the press follows the words on the panel.
	if not top and current and not Retired(current, now) and named == current.name then
		LightFuse(now)
		pressStale = true
		-- Re-keyed rather than rebuilt: whether the macro hands your target back
		-- depends on who is targeted now, which can have changed since the
		-- repaint that armed it. Their range is asked again too: this entry's
		-- reading is the oldest there is.
		Prompt:ApplyTarget(current, OutOfReachNow(current))
		pressKey = appliedKey
		return
	end

	-- The press goes to whoever the panel names, not whoever the queue just
	-- promoted: PickTop hands the panel to somebody strictly better at once,
	-- which is right for the next repaint and wrong for a press made on this
	-- one.
	if top and named and top.name ~= named then
		local fresh
		for _, candidate in ipairs(queue) do
			if candidate.name == named then fresh = candidate break end
		end
		if not fresh then
			Prompt:MovedOn(top)
			return
		end
		top = fresh
	end

	-- A held entry is not in the queue it was just picked against.
	if top then
		pressStale = true
		for _, candidate in ipairs(queue) do
			if candidate.name == top.name then pressStale = nil break end
		end
	end

	appliedKey = nil
	-- A held entry's range reading is from an overruled scan, and even a fresh
	-- one is a tick old, so it is asked once more right before the macro runs.
	Prompt:ApplyTarget(top, OutOfReachNow(top))
	pressKey = appliedKey
end

local function OnPostClick(self, mouseButton, down)
	-- Bookkeeping only, and switched off, unlocked or previewing there is none:
	-- a CLICK binding reaches a hidden frame. In combat the frozen macro may
	-- still have cast; the debt stands and the line says so.
	local db = ns.db and ns.db.profile
	if not PromptIsLive() then
		local now = GetTime()
		-- Only a press that could have cast gets the warning: type2 to type5
		-- are "none", so the right button casts nothing. A keybinding arrives
		-- with no button and counts as a left press, as in the cast path below.
		local couldCast = mouseButton == nil or mouseButton == "LeftButton"
		if couldCast and db and db.verbose and InCombatLockdown() and self:GetAttribute("macrotext1")
			and not (lastStaleAt and (now - lastStaleAt) < 0.25) then
			lastStaleAt = now
			ns.addon:Print(L["|cffff8080that may still have cast|r -- the prompt cannot be disarmed in combat, and nothing was recorded for it."])
		end
		return
	end

	-- A right-press says "not this one": the debt stands, nothing is cast, and
	-- the offer is postponed. The block is on the person, not the buff.
	if mouseButton == "RightButton" then
		-- Its own stamp: sharing the cast path's would let a right-press
		-- swallow a real left click landing just after it.
		local now = GetTime()
		if lastSkipAt and (now - lastSkipAt) < 0.25 then return end
		lastSkipAt = now
		-- Whoever the panel names, as the left press follows: under a red flash
		-- that is the person the flash is about, not the next one armed
		-- underneath.
		local victim = Prompt:PanelName() or (current and current.name)
		if not victim then
			ns.addon:Print(L["nobody to skip right now."])
			return
		end
		local db = ns.db and ns.db.profile
		-- The retry cooldown, not the two seconds a failed cast writes:
		-- that would put them straight back on the prompt.
		ns.BlockPerson(victim)
		-- A group cast on the panel: the skip is of the whole party, or the
		-- cast re-forms around the next of them on the next scan.
		local group = current and current.name == victim and current.groupCast and current or nil
		if group and ns.SkipGroupCast then ns.SkipGroupCast(group) end
		-- Your own buff, by the name rather than the entry: under the flash
		-- of a press on yourself the entry armed may already be the next one.
		local own = ns.IsPlayerName(victim)
		Prompt:StopAttention()
		-- "Never" for yourself is the switch (StopOfferingSelf): the list is
		-- of other people, and every line it says is about somebody else.
		if IsShiftKeyDown and ns.plain(IsShiftKeyDown()) and own then
			ns.StopOfferingSelf()
			ns.Guard("own buff repaint", Prompt.Refresh, Prompt)
			return
		end
		-- Held shift makes it "never": onto the never-offer list. Nothing here
		-- touches the button (type2 is "none"), so it is as safe in a fight as
		-- the skip. The block above still matters: it takes them off the panel
		-- now, not after the hold and the fuse. The list itself reaches the
		-- queue at its next rebuild, which in a fight is when the fight ends.
		if IsShiftKeyDown and ns.plain(IsShiftKeyDown()) then
			-- The repaint comes with the listing: see the wrapper below
			-- Prompt:Refresh. Only the person the cast was aimed at is listed,
			-- which the listing's own line names; the rest are skipped.
			ns.PutOnNeverList(victim)
			if group and db and db.verbose then
				ns.addon:Print(L["The rest of %s is skipped for now."]:format(group.groupCast.label or "?"))
			end
			return
		end
		-- In a fight the macro stays frozen on `current` and the next press
		-- still casts at them, so a skip of that person says so, verbose or
		-- not, as the menu's skip does. Asked of `current`, not the panel: under
		-- a flash about somebody else the plain line is the true one. Not for
		-- your own buff: a held press there only casts it on you.
		local frozenOnThem = not own and InCombatLockdown() and current and current.name == victim
		if db and db.verbose and own then
			ns.addon:Print(L["skipping your own buff for now."])
		elseif frozenOnThem or (db and db.verbose) then
			local shown = (group and group.groupCast.label)
				or (current and current.name == victim and current.short)
				or (ns.ShortName and ns.ShortName(victim)) or victim
			ns.addon:Print((frozenOnThem
				and L["skipping |cffffffff%s|r for now -- but the prompt cannot move off them in a fight, and a press still casts at them."]
				or L["skipping |cffffffff%s|r for now."]):format(shown))
		end
		-- The panel moves on now rather than at the next scan, so a left press
		-- cannot cast at the person just declined. Refresh knows about the
		-- fight.
		ns.Guard("skip repaint", Prompt.Refresh, Prompt)
		return
	end
	if mouseButton and mouseButton ~= "LeftButton" then return end

	local now = GetTime()
	-- A press the cooldown turned away is not a press: nothing is filed. Out of
	-- combat this puts back what PreClick disarmed.
	if cooldownPressAt == now then
		cooldownPressAt = nil
		local found = guardedEntry
		guardedEntry = nil
		if found and not InCombatLockdown() then
			-- The line it carried goes back with it, so the macro keeps the
			-- roll the tooltip has been quoting.
			phraseKey, phraseText = guardedPhraseKey, guardedPhraseText
			Prompt:ApplyTarget(found)
		end
		guardedPhraseKey, guardedPhraseText = nil, nil
		if ns.db and ns.db.profile.debugClicks then
			ns.addon:Print("|cffffd100CLICK|r " .. L["held back -- the cooldown was still running"])
		end
		return
	end

	-- One press delivers both a down and an up; count and settle once.
	if lastClickAt and (now - lastClickAt) < 0.25 then return end
	lastClickAt = now

	-- Lets the error and cast handlers tell our own outcome apart from
	-- everything else the game is shouting about.
	ns.lastClickTime = now
	-- Only assembled when asked for: /manners clicks. The build stamp says
	-- which build produced the log.
	if ns.db and ns.db.profile.debugClicks then
		ns.addon:Print(("|cffffd100CLICK|r build=%s macro=%s"):format(
			tostring(ns.BUILD),
			tostring(button:GetAttribute("macrotext1") or "nil"):gsub("%s+", " ")))
	end
	if not (current and current.name) then return end

	-- Park the press rather than clearing the debt: the game says a moment
	-- later whether anything was cast. What the macro was aimed at and the old
	-- rotation pointer ride along. Anything already parked is abandoned first,
	-- since one slot cannot match two records to their events, and before
	-- ns.lastGave is read, because abandoning restores it. And it is read here,
	-- above the rotation write below, the last point it holds the old value.
	ns.AbandonPendingClick()
	-- A held or fused entry's range reading comes from a scan the latest one
	-- overruled, so it answers neither way: the settle keeps the debt as
	-- nothing being able to tell.
	local stale = pressStale
	pressStale = nil
	ns.pendingClick = { name = current.name, at = GetTime(),
		buffKey = current.buff and current.buff.key,
		selfCast = armed ~= nil and armed.selfCast == true,
		-- Your own buff: settled with nothing filed (Clicks.lua, SettleSelf).
		-- Read off the entry as well as the record: a /manners try macro arms
		-- no record, and the game naming you as the one it reached would
		-- otherwise file a gift to yourself in the ledger.
		onSelf = (armed ~= nil and armed.onSelf == true) or current.reason == "self",
		targeted = armed and armed.targeted,
		-- The spelling the macro aimed at, straight from the builder, for the
		-- settle path to compare against whoever the client says was hit.
		aimedAt = armed and armed.aimedAt,
		-- Whether the scan measured them inside a shout's reach: a selfCast
		-- press clears a debt only where this is true.
		withinShout = current.ranged == true and not stale,
		-- ...and outside it, so the line can say the answer was no rather than
		-- that nothing answered.
		outOfShout = (not stale and current.ranged == false) or nil,
		-- For the favour ledger only. The reason too: a buff somebody asked
		-- for in chat is listed as asked and left out of the day's gifts
		-- (Ledger.Settled), which it can only tell from the record.
		class = current.class,
		inGroup = current.inGroup,
		reason = current.reason,
		gave = ns.lastGave[current.name],
		-- A group cast (GroupBuffs.lua): the spell, and everybody else it
		-- covers, whom the settle repays and the ledger counts with this one.
		group = current.groupCast and {
			spell = current.groupCast.spell,
			members = current.groupCast.members,
			class = current.groupCast.class,
			-- Whether everybody it covers asked for it in chat (GroupBuffs.lua):
			-- the ledger files a group cast as asked only then, whatever
			-- `reason` the anchor carries.
			asked = current.groupCast.asked,
		} or nil }
	-- A shout lands on everybody in the party close enough to hear it, not
	-- only the one it was aimed at: whoever else the scan measured inside its
	-- reach for the same shout is settled with them (Clicks.lua,
	-- SettleShout). Never yourself, and nobody on an overruled reading.
	if armed and armed.selfCast and not stale and current.buff then
		local names
		for _, entry in ipairs(pickedFrom or {}) do
			if entry.name ~= current.name and entry.ranged == true and entry.reason ~= "self"
				and entry.buff and entry.buff.selfCast and entry.buff.key == current.buff.key then
				names = names or {}
				names[#names + 1] = entry.name
			end
		end
		ns.pendingClick.shoutMembers = names
	end
	-- Everybody the group cast covers waits out the same cooldown as the
	-- person it is aimed at, or they come straight back as single offers
	-- while their auras still read the buff as missing.
	if current.groupCast and current.buff then
		for _, name in ipairs(current.groupCast.members) do
			ns.MarkAttempted(name, current.buff.key)
		end
	end
	-- Per buff, so casting Fortitude does not stop the walk reaching
	-- Divine Spirit on the next click.
	if current.buff then
		ns.MarkAttempted(current.name, current.buff.key)
		-- Only where the walk will read it back: a paladin's blessings
		-- overwrite one another, so PickBuffFor never rotates them.
		if ns.RotatesBuffs() then
			-- Bounded like every other per-person table. It is only a rotation
			-- hint for people whose auras cannot be read, so losing an old
			-- pointer costs at most one repeated first buff.
			if ns.lastGave[current.name] == nil then
				if lastGaveCount >= LAST_GAVE_CAP then
					wipe(ns.lastGave)
					lastGaveCount = 0
				end
				lastGaveCount = lastGaveCount + 1
			end
			ns.lastGave[current.name] = current.buff.key
		end
	end
	Prompt:StopAttention()
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
		hovering = true
		if activeLook then activeLook:Hover(true) end
		-- Nothing armed is nothing to describe, and a tooltip left from the
		-- last person goes with it.
		if not current or not current.buff then
			if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
			return
		end
		-- In combat the macro is frozen at whoever it held when the fight
		-- started, and a detailed tooltip about somebody stale is worse than
		-- none.
		if InCombatLockdown() then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Manners")
		GameTooltip:AddDoubleLine(current.display or current.short or current.name,
			ns.EntrySpellName(current), 1, 1, 1, 0.8, 0.8, 0.8)
		-- One cast for many says who it covers and what it costs; the one
		-- person's reading is not the story there.
		if current.groupCast then
			GroupTooltipLines(current, current.groupCast)
		else
			PersonTooltipLines(current)
		end
		GameTooltip:AddLine(" ")
		-- Plain English first; the raw macro only with /manners clicks, below.
		-- ClickSummary quotes the settled roll.
		for _, line in ipairs(Prompt:ClickSummary(current)) do
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
		local group = current.groupCast
		GameTooltip:AddLine(group and L["Right-click to skip this group buff for now."]
			or L["Right-click to skip this one."], 0.5, 0.5, 0.5)
		-- Somebody already on the list is only here because they are owed, and
		-- for them the same press lets that favour go. You never are: your
		-- own name on the list takes your own buff off (Queue.lua).
		if ns.IsNeverOffered and ns.IsNeverOffered(current.name) then
			GameTooltip:AddLine(L["Shift-right-click to let this favour go."], 0.5, 0.5, 0.5)
		elseif group then
			GameTooltip:AddLine(L["Shift-right-click to put %s on your never-offer list."]
				:format(current.short or current.name or "?"), 0.5, 0.5, 0.5)
		elseif current.reason == "self" then
			-- The switch, since the list is of other people (StopOfferingSelf).
			GameTooltip:AddLine(L["Shift-right-click to stop offering you your own buff."], 0.5, 0.5, 0.5)
		else
			GameTooltip:AddLine(L["Shift-right-click to put them on your never-offer list."], 0.5, 0.5, 0.5)
		end
		GameTooltip:Show()
	end

	local function OnLeave()
		GameTooltip:Hide()
		if activeLook then activeLook:Hover(false) end
		-- The hold and the fuse kept their clocks while the cursor was on the
		-- panel, so whatever ran out meanwhile is put right now rather than at
		-- the next scan. Next frame rather than here: the client sends this
		-- as a repaint hides the button, from inside that repaint.
		if not hovering then return end
		hovering = nil
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
		if not (current and current.buff) then
			self.tooltipFor = nil
			GameTooltip:Hide()
			return
		end
		-- Keyed on everything the tooltip says, not the name alone: the same
		-- person can move to another buff, become owed, or get a re-rolled
		-- line.
		local shown = table.concat({ current.name, current.buff.key, tostring(current.reason),
			tostring(phraseText), tostring(appliedKey) }, "\1")
		-- And whether a ready check or a death put them first, and whether
		-- mana is being saved: both come and go while the same person stays
		-- on the panel, since the owed and the asked are never held back.
		shown = shown .. "\1" .. tostring(current.sweep) .. "\1" .. tostring((ns.SavingMana()))
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

function Prompt:Create()
	if button then return end

	button = CreateFrame("Button", "MannersPrompt", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	-- Copied from the secure buttons that work on this client (MountActions,
	-- GroupTools): "AnyDown" with pressAndHoldAction. Registering down without
	-- pressAndHoldAction delivers the click and casts nothing.
	button:RegisterForClicks("AnyDown")
	button:SetAttribute("pressAndHoldAction", true)
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:RegisterForDrag("LeftButton")

	art = CreateFrame("Frame", nil, button)
	art:SetAllPoints()

	-- Stacked black rectangles stand in for a soft drop shadow: four steps of
	-- falloff, each a pixel lower, with a crisp dark rim innermost to keep the
	-- edge clean over a bright floor.
	shadows = {}
	for i, step in ipairs(SHADOW_STEPS) do
		local spread, alpha, drop = step[1], step[2], step[3]
		-- Outermost first, so it sits underneath; sublevels -8 to -7 are all
		-- the layer has below the panel, and two share one where they must.
		local t = Solid(art, "BACKGROUND", i <= 2 and -7 or -8)
		t:SetPoint("TOPLEFT", -spread, spread - drop)
		t:SetPoint("BOTTOMRIGHT", spread, -spread - drop)
		t:SetVertexColor(0, 0, 0, alpha)
		shadows[i] = t
	end

	panel = Solid(art, "BACKGROUND", -6)
	panel:SetAllPoints()

	sheen = Solid(art, "BORDER", 0)
	sheen:SetPoint("TOPLEFT")
	sheen:SetPoint("TOPRIGHT")

	-- A hairline of light along the top and shade along the bottom: the
	-- cheapest bevel.
	hairTop = Solid(art, "BORDER", 1)
	hairTop:SetHeight(1)
	hairTop:SetPoint("TOPLEFT")
	hairTop:SetPoint("TOPRIGHT")

	hairBottom = Solid(art, "BORDER", 1)
	hairBottom:SetHeight(1)
	hairBottom:SetPoint("BOTTOMLEFT")
	hairBottom:SetPoint("BOTTOMRIGHT")
	hairBottom:SetVertexColor(0, 0, 0, 0.55)

	-- A line all the way round, for the framed look. Above the bevel and the
	-- stripe, which it replaces. Anchored corner to corner, so it follows a
	-- resize without ApplyStyle measuring it.
	edges = {}
	for _, at in ipairs({
		{ "TOPLEFT", "TOPRIGHT", height = 1 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", height = 1 },
		{ "TOPLEFT", "BOTTOMLEFT", width = 1 },
		{ "TOPRIGHT", "BOTTOMRIGHT", width = 1 },
	}) do
		local edge = Solid(art, "BORDER", 3)
		if at.height then edge:SetHeight(at.height) else edge:SetWidth(at.width) end
		edge:SetPoint(at[1])
		edge:SetPoint(at[2])
		edge:Hide()
		edges[#edges + 1] = edge
	end

	-- The accent stripe is two textures so it can fade out towards both ends
	-- instead of stopping dead. A gradient only has two stops.
	accentTop = Solid(art, "BORDER", 2)
	accentTop:SetWidth(3)
	accentTop:SetPoint("TOPLEFT")
	accentBottom = Solid(art, "BORDER", 2)
	accentBottom:SetWidth(3)
	accentBottom:SetPoint("BOTTOMLEFT")

	-- Only frames can own an animation group, so anything that moves or fades
	-- on its own gets a frame of its own to be animated through.
	sweepFrame = CreateFrame("Frame", nil, art)
	sweepFrame:SetWidth(3)
	sweepFrame:SetHeight(14)
	sweepFrame:SetPoint("TOPLEFT")
	sweepFrame:SetAlpha(0)
	sweep = Solid(sweepFrame, "ARTWORK", 3)
	sweep:SetAllPoints()
	sweep:SetBlendMode("ADD")

	-- Sized to the icon itself; the halo is drawn outside it, past the ring.
	glowFrame = CreateFrame("Frame", nil, art)
	glowFrame:SetAlpha(0)
	glowHalo = Halo(glowFrame, "BACKGROUND", -3)

	-- Doubles as the icon's border and the reason signal: a ring round the icon
	-- reads better than a stripe at the panel's edge.
	iconBack = Solid(art, "BACKGROUND", -2)
	iconBack:SetVertexColor(0, 0, 0, 0.85)
	iconEdge = Solid(art, "BACKGROUND", -1)
	iconEdge:SetVertexColor(0, 0, 0, 0.9)

	icon = art:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	iconShade = Solid(art, "ARTWORK", 1)

	-- The global cooldown swept over the icon. A Cooldown frame is not
	-- protected and animates itself; made in a pcall, as the template is not
	-- ours.
	local okCooldown, made = pcall(CreateFrame, "Cooldown", nil, art, "CooldownFrameTemplate")
	if okCooldown and made then
		cooldown = made
		Try(cooldown, "SetDrawEdge", false)
		Try(cooldown, "SetDrawBling", false)
		Try(cooldown, "SetHideCountdownNumbers", true)
		Try(cooldown, "SetSwipeColor", 0, 0, 0, 0.62)
		cooldown:Hide()
	end

	-- The ring that pops outward when a buff lands. Its own frame so it can
	-- grow; drawn from the same strips as the glow, bright at the inside edge.
	burstFrame = CreateFrame("Frame", nil, art)
	burstFrame:SetAlpha(0)
	burstHalo = Halo(burstFrame, "OVERLAY", 2)

	-- A band of light that crosses the panel once. Two halves, each fading
	-- towards its outer edge, so the band has a soft middle and no hard sides.
	shineFrame = CreateFrame("Frame", nil, art)
	shineFrame:SetAlpha(0)
	shineLeft = Solid(shineFrame, "OVERLAY", 1)
	shineLeft:SetBlendMode("ADD")
	shineLeft:SetPoint("TOPLEFT")
	shineLeft:SetPoint("BOTTOMRIGHT", shineFrame, "BOTTOM", 0, 0)
	shineRight = Solid(shineFrame, "OVERLAY", 1)
	shineRight:SetBlendMode("ADD")
	shineRight:SetPoint("TOPLEFT", shineFrame, "TOP", 0, 0)
	shineRight:SetPoint("BOTTOMRIGHT")

	-- Text sits on its own frame so a target change can cross-fade all of it
	-- at once rather than swapping strings mid-read.
	textLayer = CreateFrame("Frame", nil, art)
	textLayer:SetAllPoints()

	nameText = textLayer:CreateFontString(nil, "OVERLAY")
	nameText:SetJustifyH("LEFT")
	nameText:SetWordWrap(false)
	nameText:SetShadowColor(0, 0, 0, 0.9)
	nameText:SetShadowOffset(1, -1)

	subText = textLayer:CreateFontString(nil, "OVERLAY")
	subText:SetJustifyH("LEFT")
	subText:SetWordWrap(false)
	subText:SetShadowColor(0, 0, 0, 0.8)
	subText:SetShadowOffset(1, -1)

	countChip = Solid(art, "ARTWORK", 1)
	countText = textLayer:CreateFontString(nil, "OVERLAY")
	countText:SetJustifyH("CENTER")

	-- Above every other art layer and below textLayer (a frame, so drawn over
	-- all of them): the wash reads as light on the panel, not a box over the
	-- name.
	resultFill = Solid(art, "ARTWORK", 2)
	resultFill:SetAllPoints()
	resultFill:Hide()

	-- The highlight layer only reacts to the mouse on a Button, so it belongs
	-- to the button itself rather than to the art frame.
	button:SetHighlightTexture(WHITE, "ADD")
	local hl = button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.045) end

	-- The list of who is next hangs outside the panel, so it gets a background
	-- of its own -- the panel's at a lower alpha, divided by a hairline -- or
	-- the rows are text lying on the world.
	queueBack = Solid(art, "BACKGROUND", -6)
	queueBack:Hide()
	queueHair = Solid(art, "BORDER", 1)
	queueHair:Hide()

	queueRows = {}
	queueBars = {}
	for i = 1, 5 do
		local fs = art:CreateFontString(nil, "OVERLAY")
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs:SetShadowColor(0, 0, 0, 0.9)
		fs:SetShadowOffset(1, -1)
		queueRows[i] = fs
		-- Three pixels of the reason colour before each row: priority is the
		-- one thing about the list worth knowing at a glance.
		local bar = Solid(art, "ARTWORK", 1)
		bar:Hide()
		queueBars[i] = bar
	end

	self:BuildAnimations()

	-- Everything only the three looks drawn here use, which a look from
	-- Looks/ hides (ApplyLook) and ApplyStyle puts back.
	local parts = { panel, sheen, hairTop, hairBottom, accentTop, accentBottom, sweepFrame,
		glowFrame, iconBack, iconEdge, iconShade, burstFrame, shineFrame, countChip, resultFill,
		queueBack, queueHair }
	for _, list in ipairs({ shadows, edges, queueBars }) do
		for _, part in ipairs(list) do parts[#parts + 1] = part end
	end
	self.builtinParts = parts

	for _, script in ipairs(BUTTON_SCRIPTS) do
		button:SetScript(script[1], script[2])
	end

	button:Hide()
end

---------------------------------------------------------------------------
-- animation
---------------------------------------------------------------------------

function Prompt:BuildAnimations()
	-- Entrance: rise into place and fade in. A translation is undone when its
	-- group ends, so the drop comes first, instantly, and the rise ends exactly
	-- where the panel belongs, with no hop at the end.
	local intro = art:CreateAnimationGroup()
	local hold = intro:CreateAnimation("Alpha")
	hold:SetFromAlpha(0)
	hold:SetToAlpha(0)
	hold:SetDuration(0.01)
	hold:SetOrder(1)
	local drop = intro:CreateAnimation("Translation")
	drop:SetOffset(0, -6)
	drop:SetDuration(0.01)
	drop:SetOrder(1)
	local fade = intro:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.20)
	fade:SetOrder(2)
	if fade.SetSmoothing then fade:SetSmoothing("OUT") end
	local rise = intro:CreateAnimation("Translation")
	rise:SetOffset(0, 6)
	rise:SetDuration(0.20)
	rise:SetOrder(2)
	if rise.SetSmoothing then rise:SetSmoothing("OUT") end
	art.intro = intro

	-- Target change: dip the text rather than swapping it under the eye.
	local swap = textLayer:CreateAnimationGroup()
	local out = swap:CreateAnimation("Alpha")
	out:SetFromAlpha(1)
	out:SetToAlpha(0.15)
	out:SetDuration(0.07)
	out:SetOrder(1)
	local back = swap:CreateAnimation("Alpha")
	back:SetFromAlpha(0.15)
	back:SetToAlpha(1)
	back:SetDuration(0.13)
	back:SetOrder(2)
	if back.SetSmoothing then back:SetSmoothing("OUT") end
	textLayer.swap = swap

	-- Favour arrival: the stripe catches the light and the icon warms up.
	local sweepAnim = sweepFrame:CreateAnimationGroup()
	local sIn = sweepAnim:CreateAnimation("Alpha")
	sIn:SetFromAlpha(0)
	sIn:SetToAlpha(0.85)
	sIn:SetDuration(0.10)
	sIn:SetOrder(1)
	local sMove = sweepAnim:CreateAnimation("Translation")
	sMove:SetDuration(0.45)
	sMove:SetOrder(2)
	if sMove.SetSmoothing then sMove:SetSmoothing("IN_OUT") end
	local sOut = sweepAnim:CreateAnimation("Alpha")
	sOut:SetFromAlpha(0.85)
	sOut:SetToAlpha(0)
	sOut:SetDuration(0.45)
	sOut:SetOrder(2)
	sweepAnim.move = sMove
	-- An animation leaves the frame at its final value, so park it back at
	-- invisible or the stripe keeps a bright block stuck to it.
	sweepAnim:SetScript("OnFinished", function() sweepFrame:SetAlpha(0) end)
	sweepAnim:SetScript("OnStop", function() sweepFrame:SetAlpha(0) end)
	sweepFrame.anim = sweepAnim

	local glowAnim = glowFrame:CreateAnimationGroup()
	local gIn = glowAnim:CreateAnimation("Alpha")
	gIn:SetFromAlpha(0)
	gIn:SetToAlpha(0.55)
	gIn:SetDuration(0.12)
	gIn:SetOrder(1)
	local gOut = glowAnim:CreateAnimation("Alpha")
	gOut:SetFromAlpha(0.55)
	gOut:SetToAlpha(0)
	gOut:SetDuration(0.70)
	gOut:SetOrder(2)
	if gOut.SetSmoothing then gOut:SetSmoothing("OUT") end
	glowAnim:SetScript("OnFinished", function() glowFrame:SetAlpha(0) end)
	glowAnim:SetScript("OnStop", function() glowFrame:SetAlpha(0) end)
	glowFrame.anim = glowAnim

	-- Keeps breathing for as long as somebody is still owed, so it is not
	-- missed.
	local pulse = glowFrame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local breathe = pulse:CreateAnimation("Alpha")
	breathe:SetFromAlpha(0.12)
	breathe:SetToAlpha(0.60)
	breathe:SetDuration(0.85)
	if breathe.SetSmoothing then breathe:SetSmoothing("IN_OUT") end
	pulse:SetScript("OnStop", function() glowFrame:SetAlpha(0) end)
	glowFrame.pulse = pulse

	-- A buff that landed: the ring pops outward from the icon and fades as it
	-- goes. Short -- a confirmation, not a celebration.
	local burst = burstFrame:CreateAnimationGroup()
	local bIn = burst:CreateAnimation("Alpha")
	bIn:SetFromAlpha(0.95)
	bIn:SetToAlpha(0)
	bIn:SetDuration(0.42)
	if bIn.SetSmoothing then bIn:SetSmoothing("IN") end
	local grow = burst:CreateAnimation("Scale")
	Try(grow, "SetScaleFrom", 1, 1)
	Try(grow, "SetScaleTo", 1.35, 1.35)
	Try(grow, "SetOrigin", "CENTER", 0, 0)
	grow:SetDuration(0.42)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	burst:SetScript("OnFinished", function() burstFrame:SetAlpha(0) end)
	burst:SetScript("OnStop", function() burstFrame:SetAlpha(0) end)
	burstFrame.anim = burst

	-- Light crossing the panel once, left to right: in, across, out. The
	-- distance is the panel's width, which ApplyStyle knows and sets.
	local shine = shineFrame:CreateAnimationGroup()
	local shIn = shine:CreateAnimation("Alpha")
	shIn:SetFromAlpha(0)
	shIn:SetToAlpha(1)
	shIn:SetDuration(0.10)
	shIn:SetOrder(1)
	local shMove = shine:CreateAnimation("Translation")
	shMove:SetDuration(0.50)
	shMove:SetOrder(2)
	if shMove.SetSmoothing then shMove:SetSmoothing("IN_OUT") end
	local shOut = shine:CreateAnimation("Alpha")
	shOut:SetFromAlpha(1)
	shOut:SetToAlpha(0)
	shOut:SetDuration(0.50)
	shOut:SetOrder(2)
	if shOut.SetSmoothing then shOut:SetSmoothing("IN") end
	shine.move = shMove
	shine:SetScript("OnFinished", function() shineFrame:SetAlpha(0) end)
	shine:SetScript("OnStop", function() shineFrame:SetAlpha(0) end)
	shineFrame.anim = shine

	-- A refusal: the text shakes its head, two pixels either way.
	local shake = textLayer:CreateAnimationGroup()
	for i, dx in ipairs({ -2, 4, -4, 2 }) do
		local step = shake:CreateAnimation("Translation")
		step:SetOffset(dx, 0)
		step:SetDuration(0.06)
		step:SetOrder(i)
	end
	textLayer.shake = shake

	-- Leaving after the last buff: the panel fades over the second half of the
	-- confirmation. The button is still hidden when the confirmation runs out;
	-- art is parked invisible until then, and the next Refresh restores the
	-- alpha.
	local outro = art:CreateAnimationGroup()
	local oFade = outro:CreateAnimation("Alpha")
	oFade:SetFromAlpha(1)
	oFade:SetToAlpha(0)
	oFade:SetDuration(OUTCOME_SECONDS * 0.5)
	Try(oFade, "SetStartDelay", OUTCOME_SECONDS * 0.5)
	if oFade.SetSmoothing then oFade:SetSmoothing("IN") end
	outro:SetScript("OnFinished", function()
		art.faded = true
		art:SetAlpha(0)
	end)
	art.outro = outro

	-- A fade cancelled part-way, brought back to rest rather than snapped: when
	-- somebody arrives while the panel is fading out, or a fight starts (the
	-- button cannot be hidden in combat). From and to are set for each play.
	local comeback = art:CreateAnimationGroup()
	local cFade = comeback:CreateAnimation("Alpha")
	cFade:SetDuration(0.18)
	if cFade.SetSmoothing then cFade:SetSmoothing("OUT") end
	comeback.fade = cFade
	art.comeback = comeback
end

-- Whether the extra motion is wanted: the landing burst, the shine, the shake
-- and the outro. "Calm" drops those four; everything else (the fades, the rise
-- in, the text cross-fade, the stripe sweep, the favour glow) still plays.
local function FullEffects()
	local p = ns.db and ns.db.profile.prompt
	return p ~= nil and p.effects ~= "calm"
end

-- The alpha art rests at: dimmed for a fight, full otherwise. The outro leaves
-- art at zero, and every way back has to undo that.
local function RestArtAlpha()
	art.faded = nil
	art:SetAlpha(combatHeld and (activeLook and activeLook.combatArtAlpha or 0.55) or 1)
end

function Prompt:StopOutro()
	if art.outro and art.outro:IsPlaying() then art.outro:Stop() end
	if art.faded then RestArtAlpha() end
	art.outroFor = nil
end

-- How far the outro has taken art, worked out from when it started: what
-- GetAlpha answers mid-animation has not been seen to settle on this client.
-- Same shape as the fade: a wait, then an eased-in fall.
local function OutroAlpha()
	if art.faded then return 0 end
	if not (art.outro and art.outro:IsPlaying() and art.outroAt) then return nil end
	local wait = OUTCOME_SECONDS * 0.5
	local t = (GetTime() - art.outroAt - wait) / (OUTCOME_SECONDS * 0.5)
	if t <= 0 then return 1 end
	if t >= 1 then return 0 end
	return 1 - t * t
end

-- Restarted for each new outcome: a second one (a refusal just after a landed
-- buff) would otherwise paint onto a panel already faded, or be cut short.
function Prompt:PlayOutro(stamp)
	if art.outroFor == stamp then return end
	self:StopOutro()
	if art.comeback and art.comeback:IsPlaying() then art.comeback:Stop() end
	art.outroFor, art.outroAt = stamp, GetTime()
	art.outro:Play()
end

-- A fade a repaint just cancelled, taken back to rest over a moment; `from` is
-- nil when no fade was running.
function Prompt:ComeBack(from)
	self:StopOutro()
	local rest = combatHeld and (activeLook and activeLook.combatArtAlpha or 0.55) or 1
	if from == nil or math.abs(from - rest) < 0.02 then return end
	if not (art.comeback and button:IsShown()) then return end
	art.comeback:Stop()
	art.comeback.fade:SetFromAlpha(from)
	art.comeback.fade:SetToAlpha(rest)
	art.comeback:Play()
end

-- The once-only effects, stopped: what a repaint about somebody else does to a
-- flash that belonged to the last thing on the panel.
function Prompt:StopFlourishes()
	if burstFrame.anim and burstFrame.anim:IsPlaying() then burstFrame.anim:Stop() end
	if shineFrame.anim and shineFrame.anim:IsPlaying() then shineFrame.anim:Stop() end
	if textLayer.shake and textLayer.shake:IsPlaying() then textLayer.shake:Stop() end
	if activeLook then activeLook:StopFlourishes() end
end

-- The band of light across the panel, brighter for a landed buff than for an
-- arrival. Not on the Minimal look: additive light with no panel under it is a
-- white column sweeping over the world.
function Prompt:PlayShine(r, g, b, strength)
	if not shineFrame.anim then return end
	if ns.db and ns.db.profile.prompt.style == "minimal" then return end
	Gradient(shineLeft, "HORIZONTAL", r, g, b, 0, r, g, b, strength)
	Gradient(shineRight, "HORIZONTAL", r, g, b, strength, r, g, b, 0)
	shineFrame.anim:Stop()
	shineFrame.anim:Play()
end

-- The cooldown sweep, brought up to date when a cast goes out and when the
-- panel comes up; the Cooldown frame animates itself in between.
function Prompt:SyncCooldown()
	if not cooldown then return end
	local p = ns.db and ns.db.profile.prompt
	-- Not in a fight with "Stay quiet in combat" on, which promises a still
	-- panel. The Cooldown frame is not protected, so hiding it in combat is
	-- allowed; SetCombatHold asks again as the fight starts and ends.
	local quiet = p and p.hideInCombat and InCombatLockdown()
	if not (p and p.showCooldown and p.showIcon) or quiet then
		Try(cooldown, "Clear")
		cooldown:Hide()
		return
	end
	local start, duration
	local span = ns.GlobalCooldownSpan
	if span then start, duration = span(GetTime()) end
	if start and duration and duration > 0 and Try(cooldown, "SetCooldown", start, duration) then
		cooldown:Show()
	else
		Try(cooldown, "Clear")
		cooldown:Hide()
	end
end

function Prompt:StopAttention()
	if glowFrame.pulse and glowFrame.pulse:IsPlaying() then glowFrame.pulse:Stop() end
	glowFrame:SetAlpha(0)
	if activeLook then activeLook:StopAttention() end
end

-- `isNew`: somebody owed has just become the one on the panel (the flash and
-- the sweep). `arrived`: the favour itself was only just done (the light). See
-- Refresh.
function Prompt:StartAttention(isNew, arrived)
	local p = ns.db.profile.prompt
	local mode = p.flashStyle or "pulse"
	-- A look of its own answers all of it; the light only on a favour just
	-- done, never over an outcome.
	if activeLook then
		return activeLook:Attention(isNew, arrived and not self:OutcomeLive(), mode)
	end
	if mode == "off" then
		self:StopAttention()
		return
	end

	-- The stripe's sweep first, whatever the icon is doing: it has nothing to
	-- do with the icon.
	if isNew and sweepFrame.anim and sweepFrame:IsShown() then
		sweepFrame.anim:Stop()
		sweepFrame.anim.move:SetOffset(0, -(p.height - 14))
		sweepFrame.anim:Play()
	end

	-- And the panel catches the light once as the favour is done, in the reason
	-- colour (plain light with accents off). Never over an outcome or over
	-- light already crossing, so a press's own confirmation is not cut off.
	if arrived and FullEffects() and not self:OutcomeLive()
		and not (shineFrame.anim and shineFrame.anim:IsPlaying()) then
		local r, g, b = 1, 1, 1
		if (p.accentMode or "icon") ~= "off" then r, g, b = self:AccentColor("owed") end
		self:PlayShine(r, g, b, 0.20)
	end

	-- The glow is drawn around the icon, so it goes with it.
	if not p.showIcon then
		self:StopAttention()
		return
	end

	if mode == "pulse" then
		if glowFrame.pulse and not glowFrame.pulse:IsPlaying() then
			if glowFrame.anim then glowFrame.anim:Stop() end
			glowFrame.pulse:Play()
		end
	else
		-- Unconditionally, before anything else plays: the looping pulse is
		-- only stopped in the branch above, so switching away from Pulse left
		-- it running.
		if glowFrame.pulse then glowFrame.pulse:Stop() end
		if isNew and glowFrame.anim then
			glowFrame.anim:Stop()
			glowFrame.anim:Play()
		end
	end
end

---------------------------------------------------------------------------
-- styling
---------------------------------------------------------------------------

local function unpackColor(c, fallback)
	c = c or fallback
	return c[1] or 1, c[2] or 1, c[3] or 1, c[4] == nil and 1 or c[4]
end

---------------------------------------------------------------------------
-- legible text
---------------------------------------------------------------------------

-- What ApplyStyle worked out about the ground the text stands on. One table,
-- not a local apiece: the main chunk is near Lua 5.1's 200 locals.
--
--   light   the text wants to be light: a dark panel, or no panel at all
--   lo, hi  the luminance of the panel's gradient ends, over the world
--   codes   colour codes already made legible on this ground, by code
local ink = { light = true, lo = 0, hi = 0, codes = {} }

-- The world is not ours to read, so a see-through panel is judged over a
-- dusky grey: usually dark, but not black.
local WORLD_GREY = 0.15

-- Coloured text is held to 3:1 against the panel (WCAG large text), and taken
-- to 4.5:1 once it has to move at all; the plain lines are held to 4.5:1.
local CODE_CONTRAST, TEXT_CONTRAST = 3, 4.5

-- Relative luminance as the web's contrast rules define it (the sRGB curve
-- off, then weighted). Rec. 601 answers "is this panel light"; this answers
-- "can this be read on it".
local function Linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Luminance(r, g, b)
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

local function Ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- Against the worse of the panel's two ends: the name sits near the light top
-- and the reason line near the dark bottom.
local function Contrast(r, g, b)
	local l = Luminance(r, g, b)
	return math.min(Ratio(l, ink.lo), Ratio(l, ink.hi))
end

-- A colour moved `t` of the way towards white or black; towards black by
-- scaling, so a class colour keeps its hue.
local function Toward(r, g, b, t)
	if ink.light then
		return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
	end
	return r * (1 - t), g * (1 - t), b * (1 - t)
end

-- The colour itself if it already reads on this panel, otherwise the nearest
-- colour towards white or black that does, so class colours and the reason
-- tint survive.
local function Legible(r, g, b, minimum)
	r = math.max(0, math.min(1, r))
	g = math.max(0, math.min(1, g))
	b = math.max(0, math.min(1, b))
	if Contrast(r, g, b) >= minimum then return r, g, b end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		if Contrast(Toward(r, g, b, t)) >= minimum then hi = t else lo = t end
	end
	return Toward(r, g, b, hi)
end

-- One |cAARRGGBB code made legible, cached per code (ApplyStyle empties the
-- cache): the same dozen codes are rewritten on every repaint.
local function LegibleCode(a, r, g, b)
	local key = a .. r .. g .. b
	local hit = ink.codes[key]
	if hit then return hit end
	-- Left alone if it clears 3:1, taken all the way to 4.5:1 if it has to
	-- move: stopped at 3:1, white on cream came out fainter than the plain
	-- text.
	local fr, fg, fb = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
	local nr, ng, nb = fr, fg, fb
	if Contrast(fr, fg, fb) < CODE_CONTRAST then
		nr, ng, nb = Legible(fr, fg, fb, TEXT_CONTRAST)
	end
	hit = ("|c%s%02x%02x%02x"):format(a, math.floor(nr * 255 + 0.5),
		math.floor(ng * 255 + 0.5), math.floor(nb * 255 + 0.5))
	ink.codes[key] = hit
	return hit
end

-- Every colour code in a line of panel text, made legible: the lines carry
-- colours picked for the dark panel (class colours, white names, gold). A
-- secret string passes untouched: it cannot be read, and has no codes of ours.
local function LegibleText(text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return text end
	return (text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", LegibleCode))
end

-- How the name and reason line are laid out, kept by ApplyStyle for the
-- painters: fonts, current sizes, start, and the room kept at the right (more
-- while the count chip is up). `drawn` is each line's width at the size
-- FitLine left it, when FitLine measured it there, so a look need not measure
-- again.
local fit = { path = nil, flags = "", base = {}, size = {}, room = {}, drawn = {}, width = 0, textX = 0,
	chipRoom = 10, right = nil, twoLine = false }

-- The inset from the right-hand edge when nothing is beside the lines.
local EDGE_ROOM = 10

-- How wide a line's text is, or nil when the client will not say. Unbounded
-- where possible, since a bounded width always fits. Made plain: a secret name
-- makes a secret width, which throws on the comparison.
local function TextWidth(fs)
	local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
	if not measure then return nil end
	local ok, w = pcall(measure, fs)
	w = ok and ns.plain(w) or nil
	return type(w) == "number" and w or nil
end

-- A registered font file can still fail to load, and a font string left with
-- no font throws on SetText; the game's own font stands in. The saved choice
-- is left alone.
local function SafeFont(fs, path, size, flags)
	if not fs:SetFont(path, size, flags) or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
end

-- A line too long for its room is drawn up to a fifth smaller before the
-- client cuts it: German runs a third longer than English, and a list row
-- with a long name and a long spell name is longer still. A list row has a
-- width of its own; the panel's two lines end where PlaceLines put them.
local function FitLine(fs)
	local base = fit.base[fs]
	if not base or not fit.path then return end
	if fit.size[fs] ~= base then
		SafeFont(fs, fit.path, base, fit.flags)
		fit.size[fs] = base
	end
	local room = fit.room[fs] or (fit.width - fit.textX - (fit.right or EDGE_ROOM))
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	local size = base
	local w
	while size > least do
		w = TextWidth(fs)
		if not w or w <= room + 0.5 then break end
		size = size - 1
		SafeFont(fs, fit.path, size, fit.flags)
		w = nil
	end
	fit.size[fs] = size
	fit.drawn[fs] = w
	if activeLook then activeLook:Fitted(fs) end
end

-- The one way text goes onto the name and the reason line: its colours made
-- legible on this panel, and the line fitted to its room.
local function SetLine(fs, text)
	fs:SetText(LegibleText(text))
	FitLine(fs)
end

-- Where the name and reason line end on the right: clear of the count chip
-- while it is up, at the panel's inset while it is not (nearly always), so
-- longer translations get the room.
local function PlaceLines(chipUp)
	local right = chipUp and fit.chipRoom or EDGE_ROOM
	if fit.right == right then return end
	fit.right = right
	nameText:ClearAllPoints()
	subText:ClearAllPoints()
	if activeLook then
		activeLook:PlaceLines(right)
	elseif fit.twoLine then
		nameText:SetPoint("TOPLEFT", fit.textX, -8)
		nameText:SetPoint("RIGHT", -right, 0)
		subText:SetPoint("BOTTOMLEFT", fit.textX, 8)
		subText:SetPoint("RIGHT", -right, 0)
	else
		nameText:SetPoint("LEFT", fit.textX, 0)
		nameText:SetPoint("RIGHT", -right, 0)
	end
	FitLine(nameText)
	FitLine(subText)
end

-- The count chip up or down, and the lines beside it given their room.
local function ShowChip(on)
	on = on and true or false
	if activeLook then
		-- A look may refuse it for this paint, so the name keeps its room.
		on = activeLook:Chip(on) and true or false
	else
		countChip:SetShown(on)
	end
	PlaceLines(on)
end

-- Whether the player picked the text colour. AceDB strips a value equal to its
-- default on save, so white chosen and white untouched look the same, and only
-- the second can be meant: nobody picks white text for a cream panel.
local function ChosenTextColor(c)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor or { 1, 1, 1, 1 }
	if type(c) ~= "table" then return false end
	for i = 1, 3 do
		if math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return true end
	end
	return false
end

-- The shadow for a text colour: black under light text, none under dark text,
-- where a black one smudges the letters and a light one reads as a blurred
-- second copy.
local function ShadowFor(fs, r, g, b, strength)
	if Ratio(Luminance(r, g, b), 0) >= Ratio(Luminance(r, g, b), 1) then
		fs:SetShadowColor(0, 0, 0, strength)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowColor(0, 0, 0, 0)
		fs:SetShadowOffset(0, 0)
	end
end

function Prompt:AccentColor(reason)
	local p = ns.db.profile.prompt
	if not p.accentByReason then return unpackColor(p.accentColor, { 0.45, 0.4, 0.9, 1 }) end
	local c = ReasonColor(reason)
	return c[1], c[2], c[3], 1
end

-- How tall the prompt must be for a second line at this font size. Published
-- so the options page states the same figure.
function ns.TwoLineHeight(fontSize, style)
	-- The look's own figure, for the look given or the one in use.
	local look = ns.Looks.Get(style or (ns.db and ns.db.profile.prompt.style))
	if look and look.TwoLineHeight then return look.TwoLineHeight(fontSize) end
	return 16 + fontSize + math.max(7, fontSize - 3)
end

-- The greys under the name, for a panel and for none (brighter, carried by the
-- outline). `reason` is the list's dimmer grey, a colour code the row's text
-- colour cannot reach.
local GREYS = {
	panel = { sub = { 0.60, 0.61, 0.68 }, count = { 0.72, 0.73, 0.80 }, row = { 0.62, 0.63, 0.70 },
		reason = "|cff707078" },
	bare = { sub = { 0.86, 0.87, 0.92 }, count = { 0.92, 0.93, 0.96 }, row = { 0.86, 0.87, 0.92 },
		reason = "|cffbdbfd1" },
}

-- Everything about the text that depends on the ground: ink, fonts, colours,
-- shadows and where the lines stop. The ground is measured at both ends of the
-- panel's gradient. Out of ApplyStyle, for its upvalues.
local function StyleText(p, style, fontPath, textX, chipRoom, twoLine, countSize)
	local br, bg, bb, ba = unpackColor(p.bgColor, { 0.04, 0.04, 0.06, 0.88 })
	local bare = style == "minimal"
	if bare then
		local w = Luminance(WORLD_GREY, WORLD_GREY, WORLD_GREY)
		ink.lo, ink.hi = w, w
	else
		-- The same two stops the panel's gradient is drawn with.
		local function over(c, k) return c * k * ba + WORLD_GREY * (1 - ba) end
		ink.lo = Luminance(over(br, 0.62), over(bg, 0.62), over(bb, 0.72))
		ink.hi = Luminance(over(br, 1), over(bg, 1), over(bb, 1))
	end
	local onWhite = math.min(Ratio(1, ink.lo), Ratio(1, ink.hi))
	local onBlack = math.min(Ratio(0, ink.lo), Ratio(0, ink.hi))
	ink.light = onWhite >= onBlack
	ink.codes = {}
	-- A grey warmed towards the reason colour reads on a dark ground and loses
	-- the contrast the plain grey had on a light one.
	tintSub = ink.light

	local outline = bare and "OUTLINE" or ""
	local greys = bare and GREYS.bare or GREYS.panel
	local subSize = math.max(7, p.fontSize - 3)

	fit.path, fit.flags = fontPath, outline
	fit.width, fit.textX, fit.chipRoom, fit.twoLine = p.width, textX, chipRoom, twoLine
	fit.base[nameText], fit.base[subText] = p.fontSize, subSize
	fit.size = {}
	SafeFont(nameText, fontPath, p.fontSize, outline)
	SafeFont(subText, fontPath, subSize, outline)
	fit.size[nameText], fit.size[subText] = p.fontSize, subSize

	-- The name in the colour the player picked, as it is. Left at the default,
	-- white or near-black, whichever this ground wants.
	local r, g, b, a
	if ChosenTextColor(p.fontColor) then
		r, g, b, a = unpackColor(p.fontColor, { 1, 1, 1, 1 })
	else
		local _, _, _, alpha = unpackColor(p.fontColor, { 1, 1, 1, 1 })
		if ink.light then r, g, b = 1, 1, 1 else r, g, b = 0.08, 0.08, 0.10 end
		a = alpha
	end
	nameText:SetTextColor(r, g, b, a)

	local sr, sg, sb = Legible(greys.sub[1], greys.sub[2], greys.sub[3], TEXT_CONTRAST)
	ink.sub = { sr, sg, sb }
	subText:SetTextColor(sr, sg, sb, 1)
	local cr, cg, cb = Legible(greys.count[1], greys.count[2], greys.count[3], TEXT_CONTRAST)
	SafeFont(countText, fontPath, countSize, outline)
	countText:SetTextColor(cr, cg, cb, 1)
	local qr, qg, qb = Legible(greys.row[1], greys.row[2], greys.row[3], TEXT_CONTRAST)
	ink.rowReason = greys.reason
	for _, fs in ipairs(queueRows) do
		SafeFont(fs, fontPath, subSize, outline)
		fit.base[fs], fit.size[fs] = subSize, subSize
		fs:SetTextColor(qr, qg, qb, 1)
	end

	-- Shadows: with no panel, full black under the outline, as the game's own
	-- floating text does; on a panel, one that suits the text colour. The count
	-- has no shadow on its chip.
	if bare then
		for _, fs in ipairs({ nameText, subText, countText }) do
			fs:SetShadowColor(0, 0, 0, 1)
			fs:SetShadowOffset(1, -1)
		end
		for _, fs in ipairs(queueRows) do
			fs:SetShadowColor(0, 0, 0, 1)
			fs:SetShadowOffset(1, -1)
		end
	else
		ShadowFor(nameText, r, g, b, 0.9)
		ShadowFor(subText, sr, sg, sb, 0.8)
		countText:SetShadowOffset(0, 0)
		for _, fs in ipairs(queueRows) do ShadowFor(fs, qr, qg, qb, 0.9) end
	end

	subText:SetShown(twoLine and true or false)
	-- Placed afresh: the inset, the fonts or the second line may all have
	-- changed under the anchors the lines already had.
	fit.right = nil
	PlaceLines(countChip:IsShown())
end

function Prompt:ApplyStyle()
	if not button then return end
	if InCombatLockdown() then
		self.pendingStyle = true
		return
	end
	self.pendingStyle = nil

	local p = ns.db.profile.prompt
	local style = p.style or "glass"
	local glass = style == "glass"
	-- A look from Looks/, or nil for the three drawn here. The one it replaces
	-- takes down everything it drew and gives back what it borrowed.
	local look = ns.Looks.Get(style)
	if activeLook and activeLook ~= look then activeLook:Hide() end
	activeLook = look

	button:SetSize(p.width, p.height)
	button:SetScale(p.scale)
	button:SetAlpha(p.alpha)
	button:ClearAllPoints()
	-- Stored offsets are in UIParent's units and SetPoint reads the frame's own
	-- scaled ones, so they are divided by the scale. FinishDrag converts back.
	button:SetPoint(p.point, UIParent, p.relPoint, p.x / p.scale, p.y / p.scale)
	if look then return self:ApplyLook(p, look) end

	-- Put back what a look of its own hid: the three frames of light, and the
	-- button's square highlight, which it draws rounded itself.
	glowFrame:Show()
	burstFrame:Show()
	shineFrame:Show()
	local hl = button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.045) end

	local br, bg, bb, ba = unpackColor(p.bgColor, { 0.04, 0.04, 0.06, 0.88 })

	-- panel
	if style == "minimal" then
		panel:Hide()
		for _, t in ipairs(shadows) do t:Hide() end
		sheen:Hide()
		hairTop:Hide()
		hairBottom:Hide()
	else
		panel:Show()
		-- The framed look keeps its flat panel and its border, and gets only
		-- the dark rim of the shadow under it: the rest is the glass's depth.
		for i, t in ipairs(shadows) do t:SetShown(glass or i == 1) end
		-- Vertical gradients run bottom-to-top, so the darker stop goes first.
		Gradient(panel, "VERTICAL", br * 0.62, bg * 0.62, bb * 0.72, ba, br, bg, bb, ba)
		-- Scaled by the panel's own opacity, so a panel the player has made
		-- mostly see-through does not keep a bright band floating on its own.
		sheen:SetShown(glass)
		sheen:SetHeight(math.max(4, math.floor(p.height * 0.5)))
		Gradient(sheen, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.07 * ba)
		hairTop:SetShown(glass)
		hairTop:SetVertexColor(1, 1, 1, 0.12)
		hairBottom:SetShown(glass)
	end

	-- The border, on the framed look only: pushed away from the panel colour --
	-- lighter for a dark panel, darker for a light one -- so it shows on any.
	local framed = style == "framed"
	-- Rec. 601 weights: green carries most apparent brightness, so a flat
	-- average calls a saturated blue panel mid-grey.
	local lighten = (0.299 * br + 0.587 * bg + 0.114 * bb) <= 0.5
	local function edgeOf(c, amount)
		if lighten then return c + (1 - c) * amount end
		return c * (1 - amount)
	end
	-- Blue goes a little further towards light and less towards dark, so the
	-- edge lands slightly cooler than the panel either way: a dead-neutral
	-- border on a tinted panel reads as grey dirt.
	local er, eg, eb = edgeOf(br, 0.50), edgeOf(bg, 0.50),
		edgeOf(bb, lighten and 0.55 or 0.45)
	for _, edge in ipairs(edges) do
		edge:SetShown(framed)
		edge:SetVertexColor(er, eg, eb, math.min(1, ba + 0.10))
	end

	local mode = p.accentMode or "icon"
	-- Not on the framed look: the stripe would run a pixel inside the left edge
	-- and read as a drawing mistake. The ring still carries the colour.
	local showAccent = not framed and (mode == "stripe" or mode == "both")
	accentTop:SetShown(showAccent)
	accentBottom:SetShown(showAccent)
	accentTop:SetHeight(p.height / 2)
	accentBottom:SetHeight(p.height / 2)
	sweepFrame:SetShown(showAccent)

	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT

	-- icon
	local textX = 10
	icon:ClearAllPoints()
	iconBack:ClearAllPoints()
	glowFrame:ClearAllPoints()
	if p.showIcon then
		icon:SetSize(p.iconSize, p.iconSize)
		icon:SetPoint("LEFT", 10, 0)
		icon:Show()

		-- The coloured ring, and a pixel of dark between it and the art.
		local ring = (p.accentMode == "icon" or p.accentMode == "both") and 2 or 1
		local outer = ring + 1
		iconBack:SetPoint("TOPLEFT", icon, "TOPLEFT", -outer, outer)
		iconBack:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outer, -outer)
		iconBack:Show()
		iconEdge:ClearAllPoints()
		iconEdge:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
		iconEdge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		iconEdge:Show()
		-- Darkest at the bottom edge and gone by the middle: the icon reads as
		-- set into the panel rather than printed on it.
		iconShade:ClearAllPoints()
		iconShade:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
		iconShade:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
		iconShade:SetHeight(math.max(2, math.floor(p.iconSize * 0.55)))
		Gradient(iconShade, "VERTICAL", 0, 0, 0, 0.38, 0, 0, 0, 0)
		iconShade:Show()

		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
		end

		-- A circular icon is available where masks are, but it reads as a
		-- portrait rather than a spell, so it stays opt-in.
		local round = false
		if p.roundIcon and art.CreateMaskTexture and icon.AddMaskTexture then
			if not iconMask then
				local ok, mask = pcall(art.CreateMaskTexture, art)
				if ok and mask then
					mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
						"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
					iconMask = mask
					pcall(icon.AddMaskTexture, icon, mask)
				end
			end
			if iconMask then
				iconMask:ClearAllPoints()
				iconMask:SetAllPoints(icon)
				iconMask:Show()
				iconBack:Hide()
				-- Square pieces under and over a round icon would poke out
				-- at its corners.
				iconEdge:Hide()
				iconShade:Hide()
				-- The mask art doubles as the swipe texture, as the client's
				-- own round buttons do.
				if cooldown then
					Try(cooldown, "SetSwipeTexture", "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
				end
				round = true
			end
		else
			if iconMask then iconMask:Hide() end
			if cooldown then Try(cooldown, "SetSwipeTexture", WHITE) end
		end

		-- The halo starts where the ring stops and ends at the panel's edge
		-- (past it, light read as bars stuck to the prompt), reaching further
		-- sideways where there is more room. A round icon wears the ring
		-- instead.
		local sy = math.max(2, math.min(8, math.floor((p.height - p.iconSize) / 2) - outer))
		local sx = math.max(2, math.min(8, 10 - outer))
		local roundSize = round and p.iconSize or nil
		glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT")
		glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
		PlaceHalo(glowHalo, glowFrame, sx, sy, outer, roundSize)
		burstFrame:ClearAllPoints()
		burstFrame:SetPoint("TOPLEFT", icon, "TOPLEFT")
		burstFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
		PlaceHalo(burstHalo, burstFrame, 4, 4, outer, roundSize)

		textX = 10 + p.iconSize + 10
	else
		icon:Hide()
		iconBack:Hide()
		iconEdge:Hide()
		iconShade:Hide()
		if iconMask then iconMask:Hide() end
	end
	-- Whether there is an icon to sweep, and a cooldown running to sweep it
	-- with, is SyncCooldown's to decide; the settings behind both just changed.
	self:SyncCooldown()

	-- The band of light is about a fifth of the panel wide and crosses all of
	-- it, so the distance it travels is the width less its own.
	local shineWidth = math.max(16, math.min(48, math.floor(p.width * 0.18)))
	shineFrame:ClearAllPoints()
	shineFrame:SetPoint("LEFT", art, "LEFT", 0, 0)
	shineFrame:SetSize(shineWidth, p.height)
	if shineFrame.anim then shineFrame.anim.move:SetOffset(p.width - shineWidth, 0) end

	-- count chip: sized from the font, so large fonts do not spill out of it;
	-- at the default 13 it is the old 20 by 14, with 28 reserved.
	local countSize = math.max(8, p.fontSize - 3)
	-- A digit is about half the font's size across: room for four.
	local chipWidth = countSize * 2
	-- Kept inside the panel at the top of the slider, where a chip grown from
	-- the font would otherwise stand taller than the prompt it is drawn on.
	local chipHeight = math.min(countSize + 4, math.max(8, p.height - 6))
	countChip:ClearAllPoints()
	countChip:SetPoint("RIGHT", -7, 0)
	countChip:SetSize(chipWidth, chipHeight)
	countChip:SetShown(false)
	Gradient(countChip, "VERTICAL", 1, 1, 1, 0.03, 1, 1, 1, 0.09)

	-- What the lines keep clear while the chip is up: the chip, its 7px inset
	-- and a point of gap.
	local chipRoom = p.showCount and (chipWidth + 8) or EDGE_ROOM

	-- text
	-- Two lines need both fonts plus the insets: see ns.TwoLineHeight.
	local twoLine = p.showSub and p.height >= ns.TwoLineHeight(p.fontSize)

	countText:ClearAllPoints()
	countText:SetPoint("CENTER", countChip, "CENTER", 0, 0)
	-- Fonts, colours, shadows and the lines' anchors, from the panel colour.
	-- The count's font is the size the chip was just sized from.
	StyleText(p, style, fontPath, textX, chipRoom, twoLine, countSize)
	-- The grey just written over the reason line's tint, and the ring and the
	-- stripe may have changed shape: the next PaintAccent paints in full.
	accentPainted = nil

	-- Rows get one anchor and an explicit width: TOPLEFT and RIGHT together
	-- fight over the vertical centre. Which way the list hangs is settled here.
	queueAbove = QueueGoesAbove()
	-- Kept for PaintQueue, which re-places the rows when the list hangs above
	-- and therefore needs the same inset this loop uses.
	queueTextX = textX
	local rowHeight = p.fontSize + 4
	local rowCount = math.max(1, p.queueRows or 1)
	for i, fs in ipairs(queueRows) do
		fs:ClearAllPoints()
		if queueAbove then
			-- Counted down from the top of the block, so the list reads top to
			-- bottom.
			fs:SetPoint("BOTTOMLEFT", art, "TOPLEFT", textX, 4 + (rowCount - i) * rowHeight)
		else
			fs:SetPoint("TOPLEFT", art, "BOTTOMLEFT", textX, -4 - (i - 1) * rowHeight)
		end
		-- The font and the colour are StyleText's; the width is the room
		-- FitLine shrinks a long row into.
		local width = math.max(20, p.width - textX - 8)
		fs:SetWidth(width)
		fit.room[fs] = width

		-- Anchored to its own row, so the bar follows the list whichever way it
		-- hangs and whatever the font size is.
		local bar = queueBars[i]
		bar:ClearAllPoints()
		bar:SetSize(3, math.max(6, p.fontSize - 2))
		bar:SetPoint("RIGHT", fs, "LEFT", -4, 0)
	end

	-- The background behind the list; PaintQueue sets its depth from the rows
	-- filled.
	queueBack:ClearAllPoints()
	queueHair:ClearAllPoints()
	queueHair:SetHeight(1)
	if queueAbove then
		queueBack:SetPoint("BOTTOMLEFT", art, "TOPLEFT", 0, 0)
		queueBack:SetPoint("BOTTOMRIGHT", art, "TOPRIGHT", 0, 0)
		queueHair:SetPoint("BOTTOMLEFT", art, "TOPLEFT", 0, 0)
		queueHair:SetPoint("BOTTOMRIGHT", art, "TOPRIGHT", 0, 0)
	else
		queueBack:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, 0)
		queueBack:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", 0, 0)
		queueHair:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, 0)
		queueHair:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", 0, 0)
	end
	-- A shade darker than the panel and slightly more transparent, with a
	-- hairline of light so the two rectangles do not read as one. Only a shade
	-- on a light panel, where halving went to a mud neither text colour reads
	-- on.
	local shade = ink.light and 0.55 or 0.90
	queueBack:SetVertexColor(br * shade, bg * shade, bb * (ink.light and 0.66 or 0.92),
		math.min(1, ba * 0.9))
	queueHair:SetVertexColor(1, 1, 1, 0.07)

	self:Refresh()
end

-- ApplyStyle for a look from Looks/: the regions only the three looks here
-- use hidden, the shared ones handed over, the text styled as for any panel.
-- Out of ApplyStyle, for its upvalues.
function Prompt:ApplyLook(p, look)
	if not look.kit then look:Build(self:LookKit()) end
	-- The built-in looks' animations stopped, not only hidden: a pulse left
	-- looping on a hidden frame still loops, Calm or not.
	for _, f in ipairs({ glowFrame, sweepFrame, shineFrame, burstFrame }) do
		if f.pulse then f.pulse:Stop() end
		if f.anim then f.anim:Stop() end
	end
	for _, part in ipairs(self.builtinParts) do part:Hide() end
	if iconMask then iconMask:Hide() end
	local hl = button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0) end
	local above = QueueGoesAbove()
	queueAbove = above
	local textX, chipRoom = look:Apply(p, above)
	local twoLine = p.showSub and p.height >= ns.TwoLineHeight(p.fontSize, p.style)
	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT
	StyleText(p, p.style, fontPath, textX, chipRoom or EDGE_ROOM, twoLine, math.max(7, p.fontSize - 3))
	if look.Styled then look:Styled(p, twoLine) end
	accentPainted = nil
	self:SyncCooldown()
	self:Refresh()
end

-- What a look is handed to draw with: see Looks/Looks.lua.
function Prompt:LookKit()
	if not self.kit then
		self.kit = {
			button = button, art = art, textLayer = textLayer, icon = icon, cooldown = cooldown,
			name = nameText, sub = subText, count = countText, rows = queueRows,
			fit = fit, ink = ink,
			Gradient = Gradient, Legible = Legible, TextWidth = TextWidth,
			SetLine = SetLine, FitLine = FitLine, FullEffects = FullEffects,
			ReasonColor = ReasonColor, OUTCOME_SECONDS = OUTCOME_SECONDS,
		}
	end
	return self.kit
end

function Prompt:PaintAccent(reason)
	local p = ns.db.profile.prompt
	local mode = p.accentMode or "icon"
	local r, g, b = self:AccentColor(reason)

	-- Runs on every repaint and the colour rarely changes, so the same colour
	-- again is nothing to do. ApplyStyle and a refusal's red ring forget the
	-- key when they write over these textures.
	local key = ("%s:%.3f:%.3f:%.3f:%s"):format(mode, r, g, b, tostring(tintSub))
	if key == accentPainted then return end
	accentPainted = key
	if activeLook then return activeLook:PaintReason(r, g, b, reason, mode) end

	-- Brightest at the middle, fading towards both ends.
	Gradient(accentTop, "VERTICAL", r, g, b, 1, r, g, b, 0.15)
	Gradient(accentBottom, "VERTICAL", r, g, b, 0.15, r, g, b, 1)
	sweep:SetVertexColor(r, g, b, 1)
	PaintHalo(glowHalo, r, g, b, 1)

	if mode == "icon" or mode == "both" then
		-- A little brighter at the top of the ring, lit from above, so it reads
		-- as a rim.
		Gradient(iconBack, "VERTICAL", r * 0.78, g * 0.78, b * 0.78, 0.95,
			math.min(1, r * 1.12), math.min(1, g * 1.12), math.min(1, b * 1.12), 0.95)
	else
		iconBack:SetVertexColor(0, 0, 0, 0.85)
	end

	-- The reason line, warmed a little towards the same colour so the two agree
	-- at a glance -- but not with accents off, nor on a light panel where the
	-- tint costs contrast. The tinted grey is held to the plain one's contrast.
	local mix = (tintSub and mode ~= "off") and 0.35 or 0
	local base = ink.sub or GREYS.panel.sub
	local sr, sg, sb = Legible(base[1] + (r - base[1]) * mix, base[2] + (g - base[2]) * mix,
		base[3] + (b - base[3]) * mix, TEXT_CONTRAST)
	subText:SetTextColor(sr, sg, sb, 1)
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------

-- The softened class codes ClassColored has worked out, for the look's
-- classSoften in `by`.
local softened = {}

local function ClassColored(entry, text)
	if not ns.db.profile.prompt.classColor or not entry.class then return text end
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
	if not c or not c.colorStr then return text end
	-- Taken towards white where the look asks, so a name never reads as a
	-- reason colour.
	local soften = activeLook and activeLook.classSoften
	if soften then
		-- Worked out once per class and look: this runs on every repaint.
		if softened.by ~= soften then wipe(softened) softened.by = soften end
		local code = softened[c.colorStr]
		if not code then
			-- From the code itself ("ffRRGGBB"), which every client fills in.
			local function up(at)
				local v = (tonumber(c.colorStr:sub(at, at + 1), 16) or 255) / 255
				return math.floor((v + (1 - v) * soften) * 255 + 0.5)
			end
			code = ("|cff%02x%02x%02x"):format(up(3), up(5), up(7))
			softened[c.colorStr] = code
		end
		return ("%s%s|r"):format(code, text)
	end
	return string.format("|c%s%s|r", c.colorStr, text)
end

-- Core's; its comment says why substitutions use a function replacement.
-- Local because this runs on every line of every repaint.
local Swap = ns.Swap

local function Substitute(template, entry, extra)
	local out = template or ""
	-- A group cast names the party it is for ("Gwen's party") in the name's
	-- place, and the group spell in the buff's.
	out = Swap(out, "{name}", entry.display or entry.short or entry.name or "?")
	out = Swap(out, "{count}", tostring(extra or 0))
	out = Swap(out, "{class}", ns.ClassName(entry.class))
	out = Swap(out, "{buff}", entry.buff and ns.EntrySpellName(entry) or "")
	-- Empty for everybody who is simply missing the buff: only a top-up has a
	-- timer to quote, and the queue sets `remaining` for nobody else.
	out = Swap(out, "{time}", RemainingText(entry.remaining))
	return out
end

function Prompt:ReasonText(entry)
	local p = ns.db.profile.prompt
	-- A group cast's second line is what it is and for how many, which no
	-- reason line the player wrote can say.
	local group = entry.groupCast
	if group then
		local missing, low = group.missing or 0, group.low or 0
		local spell = ns.EntrySpellName(entry)
		if low == 0 then return L["%s -- %d missing"]:format(spell, missing) end
		if missing == 0 then return L["%s -- %d running out"]:format(spell, low) end
		return L["%s -- %d need it"]:format(spell, missing + low)
	end
	local template = p[REASON_KEY[entry.reason] or "reasonNearby"] or ""
	-- The sub-line must be true without hovering: a top-up gets its own
	-- wording, and so does an unreadable aura except for owed or asked, whose
	-- reason is the line worth reading. Swapped in whole, since reason lines
	-- are free text. One chain on purpose, so both can never apply. A group
	-- member a ready check or a death put first says that instead: it is why
	-- they are at the front, and the queue only does it for a reading.
	if entry.sweep and entry.reason == "group" then
		template = entry.sweep == "readycheck" and L["ready check"] or L["just revived"]
	elseif RemainingText(entry.remaining) then
		template = p.reasonRefresh or template
	elseif entry.checked and entry.known == nil and entry.reason ~= "owed"
		and entry.reason ~= "asked" then
		template = p.reasonUnknown or template
	end
	return Substitute(template, entry, 0)
end

function Prompt:RenderPrimary(entry, extra)
	local p = ns.db.profile.prompt
	local template = p.format or "{name}"
	local out = Substitute(template, entry, extra)
	if template:find("{name}", 1, true) then
		-- The name is escaped into the pattern and the colour goes in through a
		-- function: gsub is being handed text, not a template.
		local plainName = entry.short or entry.name or "?"
		local coloured = ClassColored(entry, plainName)
		out = (out:gsub(plainName:gsub("(%W)", "%%%1"), function() return coloured end, 1))
	end
	-- A reason line is free text, and as a gsub replacement a % in it ("10%
	-- left") threw on every repaint; Swap takes it as text.
	return Swap(out, "{reason}", self:ReasonText(entry))
end

---------------------------------------------------------------------------
-- targeting
---------------------------------------------------------------------------

-- The one repaint PLAYER_REGEN_DISABLED makes before the lockdown: whatever it
-- arms is frozen for every press of the fight, so the hold and the fuse, which
-- only smooth flicker, must not keep somebody the queue has dropped.
local function ArmingForFight()
	return Prompt.armedForFight == true and not InCombatLockdown()
end

-- Whether the last candidate painted is still entitled to the panel. It
-- expires, it never holds off somebody strictly better (PickTop checks that),
-- and it never holds somebody deliberately retired (see Retired) -- not even
-- inside HOLD_SECONDS, which a press may land in.
local function HoldStillStands(now)
	if not (heldEntry and heldAt) then return false end
	-- Longer while the cursor is on the panel (see CursorHolds).
	if now - heldAt >= HOLD_SECONDS and not CursorHolds(heldEntry, now) then return false end
	if ListedWithoutDebt(heldEntry.name, now) then return false end
	if ns.HeldForPvP(heldEntry) then return false end
	return not ns.IsBlocked(heldEntry.name, heldEntry.buff and heldEntry.buff.key, now)
end

-- Whoever is offered stays offered: the current pick wins ties, and the last
-- painted one is held briefly after leaving the queue against anything no
-- better.
function Prompt:PickTop(queue, fallback)
	local top = fallback
	if current and top then
		for _, candidate in ipairs(queue) do
			if candidate.name == current.name then
				if candidate.priority <= top.priority then return candidate end
				break
			end
		end
	end

	-- An empty queue is the fuse's question, in Refresh; holding here too would
	-- stack the two.
	if not top then return nil end
	if not HoldStillStands(GetTime()) then return top end
	-- Not on the pull's own pass (see ArmingForFight). `top` already prefers
	-- the current pick while it is still in the queue.
	if ArmingForFight() then return top end
	if top.name == heldEntry.name then return top end
	-- Judged by what this scan says of them, not by the copy painted: that
	-- one keeps the priority they had then, so somebody retargeted away from,
	-- or whose favour lapsed, still outranked everybody on it -- and, being in
	-- the queue, renewed the hold on every paint (see RefreshPanel).
	local held = heldEntry
	for _, candidate in ipairs(queue) do
		if candidate.name == heldEntry.name then held = candidate break end
	end
	-- Lower is better: a strict improvement (a favour owed over a passer-by) is
	-- never held off.
	if top.priority < held.priority then return top end
	return held
end

-- Buttons 2 to 5 get a type the secure handler does not recognise, so they do
-- nothing; otherwise the unsuffixed type/macrotext (the form that works on
-- this client) fires for every button, a right-press included.
local function SilenceOtherButtons()
	for index = 2, 5 do
		button:SetAttribute("type" .. index, "none")
	end
end

-- Which targeting command to write. Not /targetexact, though it would stop
-- "/target Mort" finding Mortimer: the name is built from UnitName's two
-- returns, whose second is undocumented here for other realms, and one
-- character out finds nobody. caps.targetExact (/manners debug) is the probe
-- for switching.
local function TargetCommand()
	return "/target"
end
-- Published so the options page can name the command the macro really uses
-- rather than a second, hand-maintained opinion about it.
ns.TargetCommand = TargetCommand

-- The shape of the macro for this person. There is deliberately one targeting
-- strategy: /cast [@Name] works only for group members, cannot be tested here
-- and fails silently (a retail 12.0 restriction), and [@nameplateN] resolves
-- nowhere. Targeting reaches ungrouped strangers everywhere.
local function StrategyFor(entry)
	if entry.reason == "self" then return "self" end
	if entry.buff and entry.buff.selfCast then return "selfcast" end
	return "target"
end

-- Each returns the lines, whether /targetlasttarget goes on the end, and a
-- record the settle path judges the press by:
--
--   targeted  the macro carries a targeting line of ours, aimed at this person
--   selfCast  the spell lands on the caster and reaches the party from there
--   onSelf    the spell is for the caster alone: your own buff
--   aimedAt   the exact spelling that went onto the targeting line
local STRATEGIES = {}

-- Whether this entry was reached through the target token and is still the
-- player's target at this moment -- or is your own buff, with yourself
-- targeted. The strategy and the macro's key ask it the same way, so a change
-- of target rebuilds the macro.
local function StillTargeted(entry)
	return (entry.unit == "target" or entry.reason == "self") and entry.name ~= nil
		and ns.UnitFullName ~= nil and ns.UnitFullName("target") == entry.name
end

-- No targeting line: the spell lands on you and reaches the party from there.
-- The record says so, which is what lets the settle path judge the press.
STRATEGIES.selfcast = function(entry, spell)
	return { "/cast " .. spell }, false,
		{ targeted = false, selfCast = true, aimedAt = nil }
end

-- Your own buff: you are targeted by name, the spell cast, and your target
-- handed back -- the shape every other press takes, because it is the one
-- shape known to work on WoW Forever. Not [@player]: conditional targeting
-- does not resolve on that client at all ([@unit], [@focus], [@mouseover] and
-- the secure unit attribute all fail -- the README's client notes), and
-- nobody has cast [@player] there. Not a bare /cast either: with a friendly
-- player targeted it lands on them. No spoken line: there is nobody to say it
-- to (ns.PickPhrase). The record stays one on yourself, which is how the press
-- is settled (Clicks.lua).
--
-- Your target is handed back whatever "Hand my target back" says: that switch
-- is about other people, and this press takes your target only because the
-- client can cast on you no other way -- a hunter's aspect dropped the mob
-- he had targeted. Not when you are your own target already, where
-- /targetlasttarget would switch away; in a fight it stays, as for anybody
-- (STRATEGIES.target).
STRATEGIES.self = function(entry, spell)
	local lines = STRATEGIES.target(entry, spell)
	local restore = not StillTargeted(entry) or Prompt.armedForFight == true
	return lines, restore,
		{ targeted = true, selfCast = false, onSelf = true, aimedAt = entry.targetName or entry.name }
end

-- Target them, cast, and optionally hand the player's own target back. One
-- targeting line with one spelling: with two, /targetlasttarget hands back
-- what the first found, not the player's target. The account is in Clicks.lua.
STRATEGIES.target = function(entry, spell)
	-- targetName is the spelling, entry.name the identity; they differ only for
	-- a cross-realm player off Camelot. The fallback covers made-up entries
	-- (the preview, the phrase roller).
	local who = entry.targetName or entry.name or ""
	-- No hand-back for somebody reached through the target token who is still
	-- your target: /targetlasttarget would switch away (often to a mob). The
	-- token alone is not enough: a held or fused entry keeps "target" after you
	-- have picked somebody else, who is then the one to hand back.
	-- In a fight the macro armed at the pull runs every press, so it keeps it.
	local restore = ns.db.profile.filters.restoreTarget == true
		and (not StillTargeted(entry) or Prompt.armedForFight == true)
	return {
		TargetCommand() .. " " .. who,
		"/cast " .. spell,
	}, restore,
		{ targeted = true, selfCast = false, aimedAt = who }
end

-- The cast half of the macro, as a list, so the room left for a spoken line can
-- be measured.
local function CastLines(entry)
	-- A group cast is the same /target and /cast, with the group spell.
	return STRATEGIES[StrategyFor(entry)](entry, ns.EntrySpellName(entry))
end

-- How many characters a spoken line has left for this person. Asked by the
-- cast path and the options preview, so the two cannot disagree.
function ns.PhraseBudget(entry)
	local lines, restore = CastLines(entry)
	-- The newline the spoken line itself would add, and the restore that
	-- follows it with a newline of its own.
	local used = #table.concat(lines, "\n") + 1
	if restore then used = used + #"/targetlasttarget" + 1 end
	return ns.MACRO_LIMIT - used
end

-- What the button will do, said the way a person would say it, quoting the
-- settled spoken line (see phraseKey in ApplyTarget). A method because the
-- tooltip handler is written above CastLines.
function Prompt:ClickSummary(entry)
	local out = {}
	if not (entry and entry.buff) then return out end
	local spell = ns.EntrySpellName(entry)
	-- No name at all is rare, and gets sentences of its own: "them" takes a
	-- different form in each position in plenty of languages.
	local who = entry.short or entry.name

	-- /manners try replaces the whole macro with whatever was typed, and none
	-- of the sentences below are true of it.
	if ns.tryMacro then
		-- Asked the same question the button was, so this cannot promise a run
		-- the button was left empty for.
		local text, unfilled = ns.ExpandTokens(ns.tryMacro)
		if not text then
			out[#out + 1] = L["|cffffcc66Does nothing:|r %s."]:format(unfilled)
			return out
		end
		out[#out + 1] = who
			and L["Runs your |cffffd100/manners try|r macro against |cffffffff%s|r."]:format(who)
			or L["Runs your |cffffd100/manners try|r macro against |cffffffffthem|r."]
		return out
	end

	if entry.reason == "self" then
		-- Nothing about targets: the macro hands your target back (see
		-- STRATEGIES.self), whatever the switch for other people says.
		out[#out + 1] = L["Casts |cffffffff%s|r on you."]:format(spell)
	elseif entry.buff.selfCast then
		out[#out + 1] = L["Casts |cffffffff%s|r on you; it reaches your party from there."]
			:format(spell)
	else
		-- The spelling the targeting line will carry, which differs from the
		-- filed or shortened name for a cross-realm player off Camelot.
		local target = entry.targetName or entry.name or who
		local group = entry.groupCast
		if group and target then
			-- Who the one cast reaches besides the person it is aimed at.
			out[#out + 1] = group.class
				and L["Targets |cffffffff%s|r, casts |cffffffff%s|r on %s in your party or raid."]:format(target, spell, group.label or "?")
				or L["Targets |cffffffff%s|r, casts |cffffffff%s|r on everybody in %s."]:format(target, spell, group.label or "?")
		else
			out[#out + 1] = target
				and L["Targets |cffffffff%s|r, casts |cffffffff%s|r."]:format(target, spell)
				or L["Targets |cffffffffthem|r, casts |cffffffff%s|r."]:format(spell)
		end
		-- What the strategy decided, not the setting it started from: the two
		-- differ for your own target, whose macro hands nothing back.
		local _, restore = CastLines(entry)
		if restore then
			out[#out + 1] = L["Hands your own target back afterwards."]
		elseif ns.db.profile.filters.restoreTarget then
			out[#out + 1] = L["They are already your target, so they stay targeted."]
		else
			out[#out + 1] = L["|cffffcc66Leaves them targeted|r -- your own target is not restored."]
		end
	end

	if phraseText and phraseArmed then
		-- Quoted without its slash command (or a whisper's name): the channel is
		-- a setting, and what it says is the part worth reading.
		out[#out + 1] = L["Says: |cffffffff%s|r"]:format(ns.SpokenText(phraseText))
	end
	return out
end

-- `silent` leaves the spoken line out whatever the entry says: PreClick's
-- last-moment range reading.
function Prompt:ApplyTarget(entry, silent)
	if InCombatLockdown() then
		-- Frozen until the fight ends. `current` may only be cleared: a disarm
		-- must take effect, and pointing it at somebody new would file
		-- bookkeeping under a name the macro does not hold. appliedKey stays:
		-- it says what is on the button, which the fight froze, and the
		-- unconditional clear path below disarms it after the fight. Who the
		-- macro names is kept (frozenEntry) for a repaint in this fight to put
		-- back once the prompt is live again.
		if not entry then
			frozenEntry = frozenEntry or current
			current = nil
		end
		return
	end

	-- Out of combat the button is armed or disarmed for real.
	frozenEntry = nil
	current = entry

	if not entry or not entry.buff or testMode then
		-- Unconditionally: PreClick nils appliedKey just before calling here,
		-- so a guard on it never ran on a click and left the last person's
		-- macro armed.
		for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
			"type", "macrotext", "spell", "unit",
			"type2", "type3", "type4", "type5" }) do
			button:SetAttribute(attribute, nil)
		end
		appliedKey = nil
		-- Nothing on the button, so nothing for a settle to be judged against.
		armed = nil
		-- Same reasoning for the spoken line: there is no macro, so there is no
		-- line, and the tooltip must not still be quoting the last one.
		phraseKey, phraseText, phraseArmed = nil, nil, nil
		return
	end

	-- The console expands {unit}/{name}/{spell} against whoever is offered;
	-- above the early return, because the unit can change while the macro does
	-- not.
	ns.lastTopEntry = entry
	ns.lastTopUnit = entry.unit

	-- Whether a spoken line may go in. Not for somebody known to be out of
	-- reach: the macro runs on past a /cast that fails, and the line went out
	-- over a buff that never landed (beta.8). Nor for a while after the game
	-- refused a cast on them (ns.SpeechHeld), so pressing at somebody it will
	-- not let you reach does not keep talking. An unknown reading (nil, or a
	-- secret) keeps the line: some clients never report range, and silencing
	-- everybody there would take the feature away rather than fix it.
	local speak = not silent and entry.ranged ~= false and not ns.SpeechHeld(entry.name)

	-- Everything the macro is built from, so it is not rebuilt at 2.5 Hz. Other
	-- inputs come through InvalidateMacro; the unit is here for try's {unit},
	-- armedForFight and who is targeted for the hand-back, and whether the line
	-- is armed so a change of range or a refusal re-arms it (out of combat).
	-- The group spell too: the same person moves between a single cast and
	-- their party's group cast as the others come and go. And the name the
	-- macro casts by, which the key alone does not pin down: the trainer that
	-- teaches Ice Armor renames the Frost Armor line (Core.lua, ProbeBuff)
	-- under an entry that has not moved, and a key without it kept "/cast
	-- Frost Armor" armed for as long as that entry stayed up.
	local key = table.concat({ entry.name, tostring(entry.unit), entry.buff.key,
		ns.EntrySpellName(entry),
		tostring(entry.groupCast and entry.groupCast.spell),
		tostring(entry.reason), tostring(ns.tryMacro), tostring(Prompt.armedForFight),
		tostring(StillTargeted(entry)), tostring(speak) }, "\1")
	if key == appliedKey then return end

	-- /manners try: arbitrary macro text, expanded against the candidate, so
	-- testing on this client is one guess per click rather than per /reload.
	if ns.tryMacro then
		local text, unfilled = ns.ExpandTokens(ns.tryMacro)
		if not text then
			-- A template asking for a unit token this person lacks: nothing
			-- goes on the button rather than a guess ("target" would cast at
			-- whoever is targeted). The key carries the unit, so a later
			-- repaint through a token arms it.
			for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
				"type", "macrotext", "spell", "unit" }) do
				button:SetAttribute(attribute, nil)
			end
			ns.lastMacro = "[try, not armed] " .. tostring(unfilled)
			appliedKey = key
			armed = nil
			return
		end
		button:SetAttribute("type1", "macro")
		button:SetAttribute("macrotext1", text)
		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", text)
		SilenceOtherButtons()
		ns.lastMacro = "[try] " .. text
		appliedKey = key
		-- None of this text is a /target this addon wrote, so it is evidence
		-- about nobody's name and there is no record for the settle path.
		armed = nil
		return
	end

	local lines, restore, record = CastLines(entry)

	-- Rolled once per candidate (who, buff, why), so the tooltip quotes the
	-- line the press will cast; InvalidateMacro clears it, PreClick does not. A
	-- kept line that no longer fits the room is rolled again, or the client
	-- would cut the hand-back off the macro.
	-- The group spell too, as in the macro's key: the line names the spell, and
	-- one kept from a single cast would name the wrong one under a group cast.
	local phraseIdentity = table.concat({ entry.name, entry.buff.key, tostring(entry.reason),
		tostring(entry.groupCast and entry.groupCast.spell), tostring(ns.tryMacro) }, "\1")
	local budget = ns.PhraseBudget(entry)
	if phraseKey ~= phraseIdentity or (phraseText and #phraseText > budget) then
		phraseKey, phraseText = phraseIdentity, ns.PickPhrase(entry, budget)
	end
	-- Rolled whether or not it is said, so the roll the tooltip quoted is
	-- the one said once the line is armed again.
	local phrase = speak and phraseText or nil
	phraseArmed = phrase ~= nil
	if phrase then lines[#lines + 1] = phrase end

	-- Last, always: it is what hands your target back, and the client reads the
	-- macro top to bottom.
	if restore then lines[#lines + 1] = "/targetlasttarget" end

	local macro = table.concat(lines, "\n")

	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	SilenceOtherButtons()

	ns.lastMacro = macro
	appliedKey = key
	-- Taken whole from the strategy that built the macro: one opinion about it.
	armed = record
end

function Prompt:InvalidateMacro()
	appliedKey = nil
	-- The settled roll goes with the macro. PreClick clears appliedKey on its
	-- own instead, so a press re-resolves who without re-rolling what is said.
	phraseKey, phraseText = nil, nil
end

---------------------------------------------------------------------------
-- refresh
---------------------------------------------------------------------------

local function TestEntry()
	return {
		name = "Preview",
		short = "|cffffd100" .. L["PREVIEW"] .. "|r",
		class = "PRIEST",
		reason = "owed",
		buff = ns.ResolveBuff(true),
		known = false,
	}
end

local TEST_SECONDS = 20

-- `line` is the whole chat line for a preview that ended on its own, written
-- where the reason is known so each reason is one sentence to translate.
function Prompt:ExitTest(line)
	if not testMode then return end
	testMode, testExpiry = false, nil
	self:ApplyTarget(nil)
	ns.addon:Print(line or L["preview off."])
	-- Every way a preview ends comes through here, so this tells an open
	-- options page that its button reads "Preview" again.
	if ns.RepaintOptions then ns.RepaintOptions() end
end

-- Read by the options page to label its button.
function Prompt:InTest()
	return testMode == true
end

function Prompt:ToggleTest()
	if testMode then
		self:ExitTest()
		self:Refresh()
		return
	end
	-- Time-limited, because a preview left on looks like a working prompt; the
	-- clock stops while the options window is open. Not in a fight: the panel
	-- cannot be put up, and an armed macro would still cast under "PREVIEW".
	if InCombatLockdown() then
		ns.addon:Print(L["|cffff8080not during a fight|r -- the preview can be shown once it ends."])
		return
	end
	-- Refresh stands a mock-up aside when somebody real is waiting, so ask
	-- first, with Refresh's own test word for word, rather than start a preview
	-- that would end on its first pass. The options window holds one up anyway.
	local db = ns.db and ns.db.profile
	-- Except while snoozed: nobody real is on a snoozed prompt, so a preview
	-- there stands in front of nobody. Refresh makes the same exception.
	if db and db.enabled and db.prompt.locked and not InCombatLockdown()
		and not ns.SnoozeLeft() and not (ns.OptionsOpen and ns.OptionsOpen())
		and #ns.BuildQueue() > 0 then
		ns.addon:Print(L["somebody real is on the prompt, so there is nothing to preview -- open |cffffd100/manners|r to style it; a preview holds while that window is open."])
		return
	end
	testMode = true
	testExpiry = GetTime() + TEST_SECONDS
	self:ApplyTarget(nil)
	self:Refresh()
	-- Should Refresh stand it aside after all, it has said so itself, and
	-- repainted on the way out.
	if not testMode then return end
	-- The options page's button now has to read "Stop preview"; see ExitTest.
	if ns.RepaintOptions then ns.RepaintOptions() end
	ns.addon:Print(L["preview on -- it stays while the options window is open, then %ds longer, or |cffffd100/manners test|r to stop."]
		:format(TEST_SECONDS))
end

---------------------------------------------------------------------------
-- what the click turned into
--
-- Three states, because the settle path separates a confirmed cast from one
-- the client would not attribute.
---------------------------------------------------------------------------

-- The motion for an outcome, once: ring and light for a confirmed buff, a
-- shake for a refusal, nothing for an unconfirmed cast. None when quiet in
-- combat, on "Calm", or with the panel not shown.
function Prompt:PlayOutcomeFlourish(kind)
	local p = ns.db and ns.db.profile.prompt
	if not p or not FullEffects() then return end
	if InCombatLockdown() and p.hideInCombat then return end
	if not button:IsShown() then return end
	self:StopFlourishes()
	if activeLook then
		activeLook:Flourish(kind)
		if kind == "failed" and textLayer.shake then textLayer.shake:Play() end
		return
	end
	if kind == "cast" then
		-- Coloured here rather than by PaintAccent: the repaint that follows
		-- is usually about the next person, and the ring belongs to this one.
		local r, g, b = 1, 1, 1
		if (p.accentMode or "icon") ~= "off" then
			r, g, b = self:AccentColor(current and current.reason or "owed")
		end
		if p.showIcon and burstFrame.anim then
			PaintHalo(burstHalo, r, g, b, 1)
			burstFrame.anim:Play()
		end
		self:PlayShine(1, 1, 1, 0.30)
	elseif kind == "failed" then
		if textLayer.shake then textLayer.shake:Play() end
	end
end

function Prompt:ShowOutcome(kind, name, detail)
	if not button then return end
	outcomeKind, outcomeAt, outcomeName, outcomeDetail = kind, GetTime(), name, detail
	-- The same cross-fade a target swap uses: the text is about to change.
	if textLayer.swap then
		textLayer.swap:Stop()
		textLayer.swap:Play()
	end
	-- Taken off on time rather than at the next scan.
	self:PlayOutcomeFlourish(kind)
	outcomeGen = outcomeGen + 1
	local gen = outcomeGen
	if C_Timer and C_Timer.After then
		C_Timer.After(OUTCOME_SECONDS + 0.05, function()
			if gen ~= outcomeGen then return end
			ns.Guard("prompt outcome expiry", Prompt.Refresh, Prompt)
		end)
	end
	-- Painted now rather than waiting for the scan. At 0.4s between ticks, a
	-- confirmation that waits for one misses most of its own half-second.
	ns.Guard("prompt outcome paint", Prompt.Refresh, self)
end

function Prompt:OutcomeLive()
	if not outcomeKind then return false end
	if GetTime() - outcomeAt <= OUTCOME_SECONDS then return true end
	outcomeKind, outcomeAt, outcomeName, outcomeDetail = nil, nil, nil, nil
	if resultFill then resultFill:Hide() end
	if activeLook then activeLook:ClearOutcome() end
	return false
end

-- Who the panel names for a press: the outcome's person while its words are on
-- the name line, otherwise the entry last painted.
function Prompt:PanelName()
	if outcomePainted then return outcomePainted end
	return heldEntry and heldEntry.name
end

-- A press aimed at somebody the panel is not naming: nothing is cast. The
-- panel is brought up to date and disarmed, so the next press casts at who it
-- says.
function Prompt:MovedOn(top)
	outcomeKind, outcomeAt, outcomeName, outcomeDetail = nil, nil, nil, nil
	outcomePainted = nil
	if resultFill then resultFill:Hide() end
	if activeLook then activeLook:ClearOutcome() end
	ns.Guard("prompt moved on", Prompt.Refresh, self)
	self:ApplyTarget(nil)
	-- Your own buff by what it is: your name in the third person reads as
	-- somebody else who shares it.
	if top.reason == "self" then
		ns.addon:Print(L["the prompt has moved on to your own buff -- press again to buff yourself."])
		return
	end
	-- A group cast by whom it lands on and what it is: the entry is a copy of
	-- one member, and the next press casts the group spell on them all, with
	-- its reagent.
	if top.groupCast then
		ns.addon:Print(L["the prompt has moved on to |cffffffff%s|r -- press again to cast |cffffffff%s|r on them all."]
			:format(top.groupCast.label or "?", ns.EntrySpellName(top)))
		return
	end
	ns.addon:Print(L["the prompt has moved on to |cffffffff%s|r -- press again to buff them."]
		:format(tostring(top.short or top.name)))
end

-- Written over whatever Paint put on the panel: by the time the outcome lands
-- the queue has usually moved on.
function Prompt:PaintOutcome()
	-- No name is rare, and each headline has its own "them" sentence for it,
	-- for the same reason as in ClickSummary.
	local who = ns.ShortName and ns.ShortName(outcomeName) or outcomeName
	-- A press on yourself says so, rather than naming you like a stranger.
	local own = ns.IsPlayerName(outcomeName)

	local r, g, b = self:AccentColor(current and current.reason or "owed")
	local lead, sub

	if outcomeKind == "failed" then
		-- Red, with the game's own localised words underneath: often the only
		-- thing that says why (range, line of sight, mana).
		r, g, b = 0.90, 0.26, 0.22
		lead = own and L["|cffff8080could not buff|r |cffffffffyourself|r"]
			or who and L["|cffff8080could not buff|r |cffffffff%s|r"]:format(who)
			or L["|cffff8080could not buff|r |cffffffffthem|r"]
		sub = outcomeDetail
	elseif outcomeKind == "sent" then
		-- Deliberately not a tick: our spell went out, but tying it to this
		-- person is an inference, and the panel says it at the settle path's
		-- strength. The settle sends the clause for which inference; the
		-- fallback is the commoner.
		lead = who and L["|cffe8e0a0sent to|r |cffffffff%s|r"]:format(who)
			or L["|cffe8e0a0sent to|r |cffffffffthem|r"]
		sub = outcomeDetail or L["cast -- this client will not confirm who to"]
	elseif own then
		-- [@player] can land nowhere else, so our spell going out is the
		-- whole answer (Clicks.lua, SettleSelf).
		lead = L["|cff8ce88cbuffed|r |cffffffffyourself|r"]
		sub = L["cast on you"]
	else
		lead = who and L["|cff8ce88cbuffed|r |cffffffff%s|r"]:format(who)
			or L["|cff8ce88cbuffed|r |cffffffffthem|r"]
		sub = L["the game confirmed it"]
	end

	-- A look of its own writes the outcome its way; the count goes as here.
	if activeLook then
		activeLook:PaintOutcome(outcomeKind, lead, sub, own and L["You"] or who, outcomeAt)
		accentPainted = nil
		outcomePainted = outcomeName
		ShowChip(false)
		countText:SetText("")
		return
	end

	-- A low-alpha wash over the whole panel, read without being looked at.
	-- Lighter for a refusal, which the red words and ring already say, and
	-- lightest for an unconfirmed cast.
	local wash = (outcomeKind == "failed" and 0.15) or (outcomeKind == "sent" and 0.14) or 0.20
	resultFill:SetVertexColor(r, g, b, wash)
	resultFill:Show()
	-- The ring says it too, where the ring carries a colour at all. Put back by
	-- the next PaintAccent, which every repaint of a person runs.
	local mode = ns.db.profile.prompt.accentMode or "icon"
	if outcomeKind == "failed" and (mode == "icon" or mode == "both") then
		Gradient(iconBack, "VERTICAL", 0.62, 0.16, 0.14, 0.95, 1.0, 0.36, 0.30, 0.95)
		accentPainted = nil
	end
	SetLine(nameText, lead)
	outcomePainted = outcomeName
	if subText:IsShown() then SetLine(subText, sub or "") end
	ShowChip(false)
	countText:SetText("")
end

-- Dim the whole panel for combat, or undo it; remembers what it last did, so a
-- repaint costs nothing.
function Prompt:SetCombatHold(on)
	if combatHeld == on then return end
	combatHeld = on
	-- art, never the button: every visual in this file lives on art precisely
	-- so that combat -- which is when this runs -- cannot refuse it.
	RestArtAlpha()
	if activeLook then activeLook:Combat(on) end
	-- The sweep answers to the fight as well: see SyncCooldown.
	self:SyncCooldown()
end

-- What a branch paints when the fight would not let the prompt go. The two
-- shapes -- inert, or still armed by the fight -- are read off the attribute
-- PostClick warns about, so the two agree. Callers pass whole sentences, not a
-- reason word: a translator needs the sentence the word agrees with.
function Prompt:PaintHeldInert(whyFrozen, whyInert)
	local frozen = button:GetAttribute("macrotext1")
	SetLine(nameText, frozen and "|cffff8080" .. L["still armed by the fight"] .. "|r"
		or "|cff909098" .. L["nothing to buff"] .. "|r")
	outcomePainted = nil
	if subText:IsShown() then
		SetLine(subText, ("|cffb0b0b0%s|r"):format(frozen and whyFrozen or whyInert))
	end
	-- Every other claim on the panel goes with the name: a count of a queue
	-- that is not being offered, and the wash of colour from a click that is
	-- over.
	ShowChip(false)
	countText:SetText("")
	resultFill:Hide()
	if activeLook then activeLook:ClearOutcome() end
	self:PaintAccent("nearby")
	-- The same statement the held panel makes, for the same reason: nothing
	-- here can be pointed at anybody until the fight ends.
	self:SetCombatHold(true)
end

-- The list of who is next, and the panel behind it; the preview draws it too.
function Prompt:PaintQueue(rows)
	local p = ns.db.profile.prompt
	local shown = 0
	for i, fs in ipairs(queueRows) do
		local row = rows and rows[i]
		if row then
			-- The words after the name in the look's own dimmer grey.
			local text = row.text
			if row.detail then
				text = text .. "  " .. (ink.rowReason or GREYS.panel.reason) .. row.detail .. "|r"
			end
			SetLine(fs, text)
			-- Three pixels of the reason colour.
			local c = ReasonColor(row.reason)
			queueBars[i]:SetVertexColor(c[1], c[2], c[3], 0.9)
			queueBars[i]:SetShown(not activeLook)
			shown = shown + 1
		else
			fs:SetText("")
			queueBars[i]:Hide()
		end
	end

	-- A look of its own lays the list out itself.
	if activeLook then return activeLook:PaintQueue(rows, shown, queueAbove) end

	-- Sized to the filled rows, not the slider.
	local back = shown > 0 and p.style ~= "minimal"
	if back then queueBack:SetHeight(6 + shown * (p.fontSize + 4)) end

	-- Rows hanging above are placed here, where the number filled is known.
	if queueAbove then
		local rowHeight = p.fontSize + 4
		for i, fs in ipairs(queueRows) do
			if i <= shown then
				fs:ClearAllPoints()
				fs:SetPoint("BOTTOMLEFT", art, "TOPLEFT",
					queueTextX, 4 + (shown - i) * rowHeight)
			end
		end
	end
	queueBack:SetShown(back)
	queueHair:SetShown(back)
end

function Prompt:Paint(entry, extra)
	local p = ns.db.profile.prompt

	SetLine(nameText, self:RenderPrimary(entry, extra))
	-- The name line is the entry's again, so a press follows the entry.
	outcomePainted = nil
	if subText:IsShown() then SetLine(subText, self:ReasonText(entry)) end

	local showCount = p.showCount and extra > 0
	countText:SetText(showCount and tostring(extra) or "")
	ShowChip(showCount)

	self:PaintAccent(entry.reason)
	-- On every paint of a person, the scan's own tick: a look's clock.
	if activeLook and activeLook.Painted then activeLook:Painted(entry) end

	if p.showIcon then
		local info = ns.BuffInfo(entry.buff)
		local groupIcon = entry.groupCast and entry.groupCast.icon
		icon:SetTexture(groupIcon or (info and info.icon) or 135932)
	end
end

-- The outro belongs to one branch (an outcome over an empty queue); every
-- other repaint cancels it and brings the panel back from where it had got.
function Prompt:Refresh()
	if not button or not ns.db then return end
	self.outroWanted = nil
	local fadedTo = OutroAlpha()
	self:RefreshPanel()
	if not self.outroWanted then self:ComeBack(fadedTo) end
end

-- Listing somebody repaints the prompt at once, whatever the route, so the
-- macro is not left armed at them until the next scan. Core loads first.
do
	local putOnNeverList = ns.PutOnNeverList
	if putOnNeverList then
		ns.PutOnNeverList = function(name)
			local listed = putOnNeverList(name)
			if listed then ns.Guard("never repaint", Prompt.Refresh, Prompt) end
			return listed
		end
	end
end

function Prompt:RefreshPanel()
	local db = ns.db.profile
	if not db then return end
	local p = db.prompt

	local now = GetTime()

	-- The combat dim comes off here, above every early return: it means "the
	-- button cannot be pointed at anybody new", which is true exactly while the
	-- lockdown is.
	if not InCombatLockdown() then self:SetCombatHold(false) end

	-- Nothing to cast on anybody, yourself included: a hunter with an aspect
	-- learned has a prompt, for his own.
	if not ns.CanCastAnything() and not testMode then
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		-- SPELLS_CHANGED can land mid-fight, and the panel cannot come down
		-- then.
		if not SetPanelShown(false) then
			self:PaintHeldInert(
				L["nothing this character can cast -- a press still casts what the fight froze"],
				L["nothing this character can cast -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if testMode then
		-- While the options window is open the clock is pushed on and somebody
		-- real does not end it, so the prompt can be styled in a city.
		local styling = ns.OptionsOpen and ns.OptionsOpen()
		if styling then
			testExpiry = now + TEST_SECONDS
		elseif testExpiry and now > testExpiry then
			self:ExitTest(L["preview off -- timed out."])
		elseif db.enabled and p.locked and not InCombatLockdown() and not ns.SnoozeLeft(now)
			and #ns.BuildQueue() > 0 then
			-- Somebody real is waiting. Never let a mock-up stand in front of
			-- an actual person who just buffed you.
			self:ExitTest(L["preview off -- somebody real turned up."])
		end
	end

	if testMode then
		-- Preview is a disarm, asked again on every pass: one started in combat
		-- could only clear `current`, and the first pass after the fight must
		-- clear the macro for real.
		self:ApplyTarget(nil)
		-- A preview started in a fight paints on whatever the fight left: a
		-- hidden panel stays hidden until it ends. Everything below is art and
		-- runs anyway.
		if not button:IsShown() and SetPanelShown(true) then
			if art.intro then art.intro:Play() end
		end
		self:Paint(TestEntry(), 2)
		self:StartAttention(false)
		-- Mock rows with mock reasons, since the reason bar is being styled
		-- too.
		local mock, reasons = {}, { "owed", "group", "nearby", "nearby", "nearby" }
		for i = 1, (p.showQueue and p.queueRows or 0) do
			mock[i] = { text = L["Someone %d"]:format(i), reason = reasons[i] }
		end
		self:PaintQueue(mock)
		return
	end

	-- Ahead of the unlocked branch: an unlocked prompt must obey /manners off.
	if not db.enabled then
		self:ApplyTarget(nil)
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		-- In a fight the macro under the name could not be cleared; say so.
		if not SetPanelShown(false) then
			self:PaintHeldInert(L["switched off -- a press still casts what the fight froze"],
				L["switched off -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if not p.locked then
		self:ApplyTarget(nil)
		self:StopAttention()
		HideQueue()
		ClearHold()
		if SetPanelShown(true) then
			SetLine(nameText, "|cffffd100" .. L["Drag to move"] .. "|r")
			outcomePainted = nil
			if subText:IsShown() then SetLine(subText, "|cffff8080" .. L["not buffing while unlocked"] .. "|r") end
			ShowChip(false)
			countText:SetText("")
			resultFill:Hide()
			if activeLook then activeLook:ClearOutcome() end
			self:PaintAccent("owed")
		else
			-- "Drag to move" is refused in a fight too (OnDragStart gives up on
			-- lockdown), so say what the panel is instead.
			self:PaintHeldInert(L["unlocked -- a press still casts what the fight froze"],
				L["unlocked -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if InCombatLockdown() then
		-- The panel cannot leave the screen, and blanking the art (or a
		-- visibility driver) would leave an invisible button that still casts
		-- from its binding. So this branch says true things on art.

		-- Switched off and on (or unlocked and locked) inside the fight: the
		-- macro still names the person the fight froze, so the bookkeeping
		-- must too. Not pointing `current` at somebody new: it is the same one.
		if not current and frozenEntry and button:GetAttribute("macrotext1") then
			current = frozenEntry
		end

		-- The pulse claims somebody is still owed, and the debt can expire or
		-- be settled mid-fight.
		local debt = current and current.name and ns.owed[current.name]
		if not current or current.reason ~= "owed" or not debt or ns.DebtExpiry(debt) <= now then
			self:StopAttention()
		end

		-- The panel is frozen at whoever was on it when the fight started, so
		-- it must not look live: the dim, the blanked list and the line all say
		-- it is held.
		self:SetCombatHold(true)
		HideQueue()
		-- Asked for rather than assumed: a missing method would take the whole
		-- scan tick with it.
		if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
		-- A click still works in combat, so its outcome wins over the held
		-- line. Art only: a panel the fight found hidden stays hidden.
		if self:OutcomeLive() and not p.hideInCombat then
			self:PaintOutcome()
		else
			-- Repainted from `current`, the frozen macro's identity, so an
			-- expired outcome's headline does not stand over the next person's
			-- macro.
			if current then
				SetLine(nameText, self:RenderPrimary(current, 0))
				outcomePainted = nil
				-- The ring as well: a refusal turned it red, and the name
				-- line is not the only thing the flash wrote over.
				self:PaintAccent(current.reason)
				if subText:IsShown() then
					SetLine(subText, "|cffb0b0b0" .. L["held -- in combat"] .. "|r")
				end
				-- No count: it is a claim about the queue this branch just
				-- blanked.
				ShowChip(false)
				countText:SetText("")
			else
				-- The commonest way in: a click emptied the queue and a fight
				-- started with nobody on the panel, so the click's green
				-- headline would otherwise stand for the whole fight over an
				-- empty button.
				self:PaintHeldInert(L["held -- a press still casts what the fight froze"],
					L["held -- nothing armed, and the panel cannot go"])
			end
		end
		return
	end

	-- Snoozed, below the combat branch: a snooze started in a fight waits for
	-- it to end, when the panel can come down.
	if ns.SnoozeLeft(now) then
		self:ApplyTarget(nil)
		button:Hide()
		outcomePainted = nil
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		return
	end

	-- With the cursor on the panel, every verdict written down (see
	-- BuildQueue), so the cursor's hold can tell the dead from the unseen.
	local queue, verdicts = ns.BuildQueue(hovering)
	NoteVerdicts(verdicts)
	local top = self:PickTop(queue, queue[1])
	pickedFrom = queue

	if not top then
		-- An empty queue in a crowd is usually a gap, so the first empty scan
		-- lights a short fuse and a refill puts it out. Nobody retired gets
		-- one. Nothing is disarmed while it burns: a panel on screen must stay
		-- clickable for the person it names.
		local retired = Retired(current, now)

		if self:OutcomeLive() then
			-- The click is what empties the queue, so its confirmation nearly
			-- always lands here. Disarmed: PostClick files nothing without a
			-- current entry, so the button is inert for the half second it
			-- stays up.
			self:ApplyTarget(nil)
			button:Show()
			self:StopAttention()
			HideQueue()
			self:PaintOutcome()
			lastTop = nil
			ClearHold()
			-- Nobody left: fade over the second half of the confirmation. The
			-- hide is still the repaint the outcome's own timer asks for.
			if FullEffects() then
				self.outroWanted = true
				self:PlayOutro(outcomeAt)
			end
			return
		end

		-- No fuse on the pull's own pass (see ArmingForFight): it would freeze
		-- the dropped person's macro for the whole fight.
		if button:IsShown() and current and not retired and not ArmingForFight() then
			LightFuse(now)
			-- Nor does it burn out under the cursor (see hovering): the
			-- player is on the way to clicking it. OnLeave repaints. Not
			-- when the queue emptied on a verdict, theirs or your own state
			-- (see CursorHolds).
			if CursorHolds(current, now) then return end
			if now - emptyAt < EMPTY_FUSE_SECONDS then return end
		end

		self:ApplyTarget(nil)
		button:Hide()
		outcomePainted = nil
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		return
	end
	emptyAt = nil

	self:ApplyTarget(top)

	-- Who else is waiting, which of them are listed, and whether the pick is in
	-- the queue: counted, not read off queue order, because the pick is not
	-- always queue[1] (ties keep the current one; a held one may be absent).
	local rows, others, inQueue = {}, 0, false
	local wanted = (p.showQueue and p.queueRows) or 0
	for _, entry in ipairs(queue) do
		if entry.name == top.name then
			-- The queue's own entry, not merely the name: a paint of the copy
			-- the hold kept is never a paint from the queue.
			inQueue = inQueue or entry == top
		else
			others = others + 1
			if #rows < wanted then
				-- The name and the words apart: PaintQueue colours the words
				-- for the look it is painting in.
				rows[#rows + 1] = {
					text = Substitute("{name}", entry, 0),
					detail = self:ReasonText(entry),
					reason = entry.reason,
				}
			end
		end
	end

	local wasHidden = not button:IsShown()
	local isNew = top.name ~= lastTop
	-- The moment somebody becomes owed, which includes a passer-by already on
	-- the panel who then buffs you.
	local becameOwed = top.reason == "owed" and (isNew or lastTopReason ~= "owed")
	lastTop = top.name
	lastTopReason = top.reason
	-- Narrower again: the favour itself was only just done, keyed on the debt's
	-- own stamp. A favour first seen while somebody else was on the panel is
	-- not news when its giver reaches the top later.
	local newest = seenDebtAt
	for _, owed in pairs(ns.owed or {}) do
		if type(owed) == "table" and type(owed.at) == "number"
			and owed.at > (newest or -math.huge) then
			newest = owed.at
		end
	end
	local debt = top.reason == "owed" and ns.owed and ns.owed[top.name]
	local debtAt = type(debt) == "table" and type(debt.at) == "number" and debt.at or nil
	local arrived = debtAt ~= nil and debtAt > (seenDebtAt or -math.huge)
		and now - debtAt <= ARRIVAL_SECONDS
	seenDebtAt = newest

	-- Stamped where the panel is painted, not where the pick is made (PreClick
	-- picks too). Renewed by paints from the queue, never by a paint the hold
	-- itself produced, or somebody long gone would own the prompt. A paint
	-- from the queue is a fresh start for the cursor's hold as well: whoever
	-- a scan turned down is back (see heldTurnedDown).
	if inQueue or not heldEntry then heldAt, heldTurnedDown = now, nil end
	heldEntry = top

	self:Paint(top, others)
	button:Show()

	if wasHidden then
		if art.intro then art.intro:Play() end
		-- A panel coming up part-way through a global cooldown shows what is
		-- left of it; the cast that started it was sent while it was down.
		self:SyncCooldown()
	elseif isNew and textLayer.swap then
		textLayer.swap:Stop()
		textLayer.swap:Play()
	end

	-- A floor under the sound as well as the name: a swapped name can be
	-- ignored, a sound cannot. And the flash's filter: both exist to make you
	-- look, so they agree about who is worth it -- where anybody can be owed:
	-- a class with no buffs to give (a hunter's aspects) files no favour, and
	-- "Only for people who buff me", on out of the box, silenced it for good.
	if isNew and db.sound.enabled
		and (not db.sound.owedOnly or top.reason == "owed"
			or not (ns.caps and ns.caps.hasClassBuffs == true and db.sources.owed ~= false))
		and not (lastSoundAt and (now - lastSoundAt) < SOUND_FLOOR_SECONDS) then
		lastSoundAt = now
		ns.Guard("prompt sound", ns.PlayPromptSound, db.sound.file)
	end

	if top.reason == "owed" then
		self:StartAttention(becameOwed, arrived)
	else
		self:StopAttention()
	end

	self:PaintQueue(rows)

	-- Last, over all of it: the outcome belongs to the press just made.
	if self:OutcomeLive() then
		self:PaintOutcome()
	else
		resultFill:Hide()
		if activeLook then activeLook:ClearOutcome() end
	end
end

-- Says on the panel that the pause is the game's, on the sub-line only: the
-- person is still the one being offered.
function Prompt:SayWaiting(left)
	if not button or not subText then return end
	if InCombatLockdown() then return end
	-- The colour rides in the string: set on the font string it would stay
	-- after the wait. Rounded up, so a refused press never reads "ready in
	-- 0.0s".
	ns.Guard("waiting line", function()
		SetLine(subText, "|cffb8b8c7" .. L["ready in %.1fs"]:format(
			math.max(0.1, math.ceil((left or 0) * 10) / 10)) .. "|r")
	end)
end

-- A drag still held when a fight starts is ended here, from
-- PLAYER_REGEN_DISABLED just before the lockdown: the release will come in the
-- fight, where the move can be neither stopped nor saved.
function Prompt:FinishDragForFight()
	if not dragging or not button or InCombatLockdown() then return end
	FinishDrag()
end

function Prompt:GetButton()
	return button
end

-- The entry the panel is armed at, or nil with no panel up or a preview
-- showing. Read by the launcher's tooltip and menu.
function Prompt:Showing()
	if not button or testMode or not button:IsShown() then return nil end
	return current
end

-- The pieces of the panel, handed out so tests can read back what this file
-- wrote: many failures here have no symptom but how they look.
function Prompt:Regions()
	return {
		art = art,
		name = nameText,
		sub = subText,
		count = countText,
		-- The chip beside its number: both are sized from one font, and a chip
		-- smaller than its digits throws nothing.
		chip = countChip,
		fill = resultFill,
		-- The framed look's four edges.
		edges = edges,
		-- The two carriers of the reason colour, each switched off from
		-- elsewhere (the stripe by the framed look, the ring by hiding or
		-- rounding the icon).
		iconBack = iconBack,
		accentTop = accentTop,
		-- What "When someone buffs you" animates: whether one played is the
		-- only evidence the setting does anything.
		sweep = sweepFrame,
		glow = glowFrame,
		glowStrips = glowHalo and glowHalo.strips,
		glowRound = glowHalo and glowHalo.round,
		burstStrips = burstHalo and burstHalo.strips,
		burstRound = burstHalo and burstHalo.round,
		-- The look's effects, for the same reason. The cooldown is nil on a
		-- client without the template.
		cooldown = cooldown,
		burst = burstFrame,
		shine = shineFrame,
		shake = textLayer and textLayer.shake,
		intro = art and art.intro,
		outro = art and art.outro,
		comeback = art and art.comeback,
		shadows = shadows,
		sheen = sheen,
		iconEdge = iconEdge,
		iconShade = iconShade,
		icon = icon,
		queueBack = queueBack,
		queueHair = queueHair,
		rows = queueRows,
		bars = queueBars,
		-- The rest of what only the three looks here draw, and the look from
		-- Looks/ in use (nil for those three), whose own regions are its `own`.
		panel = panel,
		hairTop = hairTop,
		hairBottom = hairBottom,
		accentBottom = accentBottom,
		builtin = Prompt.builtinParts,
		look = activeLook,
		textLayer = textLayer,
	}
end
