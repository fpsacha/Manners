-- Manners -- the on-screen prompt.
--
-- The button itself is a SecureActionButtonTemplate: Blizzard owns the click,
-- and SetAttribute, SetSize, SetScale and SetPoint are all protected once
-- combat starts. Every visual instead lives on `art`, an ordinary frame
-- parented to it, so animations never touch protected state.
--
-- Everything is drawn from a single white texture plus gradients, alpha and
-- motion. That is deliberate: a missing atlas or art file renders as a green
-- placeholder, and a solid texture cannot fail. Atlas and mask work is layered
-- on top only after being confirmed present at runtime.

local ADDON, ns = ...
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
	-- noDefault: without it an entry whose addon has been uninstalled resolves
	-- to "None", which is the number 1 and plays nothing -- silence that reads
	-- as a broken addon, which is the bug this fixes.
	--
	-- A key that is not there falls back to our own sound, here and not in the
	-- saved setting. Rewriting the setting at load is what reset a sound from
	-- any pack that loads after this addon: it had not registered yet.
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
-- The drop shadow, as steps of falloff from a crisp dark rim at the panel's
-- edge out to almost nothing, each a little lower than the last so the light
-- reads as coming from above. Two hard-edged rectangles was the old version,
-- and at a glance it read as a grey frame round the panel rather than as depth.
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
-- The four edges of the framed look, drawn from the same white texture as
-- everything else here. A backdrop needs BackdropTemplate and a border needs an
-- art file or an atlas, and both of those are things this client may not have
-- -- which is how the look that promised one went three releases applying
-- nothing at all. Four one-pixel rectangles cannot fail.
local edges
local accentTop, accentBottom, sweep, sweepFrame
local iconBack, icon, glowFrame, iconMask
-- The glow is a halo round the icon, rather than the filled square it was.
-- glowFrame is a frame of its own so it can be animated, and a child frame
-- draws over everything its parent draws -- so the square was washed
-- additively over the spell icon, and at the top of the pulse the icon turned
-- into a pale smudge of the reason colour. The halo starts at the ring, so the
-- icon stays readable at every point of the pulse. See Halo.
local glowHalo
-- A dark line between the icon and its ring, and a shade over the icon's lower
-- half. Without them the ring sat flush against the art and read as a flat
-- coloured square rather than a frame.
local iconEdge, iconShade
-- The global cooldown, swept over the icon. See SyncCooldown.
local cooldown
-- The confirmation a landed buff gets, and the light that catches the panel
-- when somebody buffs you: a ring that pops outward from the icon, and a band
-- of light that crosses the panel once. Both play once and stop; neither runs
-- while nothing is happening.
local burstFrame, burstHalo, shineFrame, shineLeft, shineRight
-- Whether the panel colour is dark enough for the reason line to carry a tint
-- of the reason colour. On a light panel a tinted grey loses its contrast.
local tintSub
-- What PaintAccent last painted, so a repaint in the same colour costs nothing.
local accentPainted
local nameText, subText, countChip, countText, queueRows
-- A flood of colour over the whole panel, for the half-second after a click.
-- The panel is what the eye is already on, so the confirmation goes there
-- rather than into a chat line nobody is watching for.
local resultFill
-- The queue list is drawn outside the panel, so it needs its own background or
-- it is white text on the world. queueBars are the reason stripes down the
-- left of each row.
local queueBack, queueHair, queueBars
local queueTextX = 0
-- Goes into every click line. A log that does not say which build produced it
-- can be diagnosed for an hour before anyone notices the game never loaded the
-- file being read.
ns.BUILD = "1.0.0-beta.5"

local current, testMode, testExpiry, lastTop, appliedKey, lastClickAt, lastPreClickAt, lastSkipAt
-- Why the last painted person was on the panel, beside lastTop's who.
local lastTopReason
-- The stamp of the newest favour a repaint has seen, and how old a favour can
-- be and still count as just done. A scan comes round every fraction of a
-- second, so three is time enough for the repaint to reach it, and short
-- enough that an old favour first seen late -- one carried over from the last
-- session, or done while a fight kept the panel from looking -- is not news.
local seenDebtAt
local ARRIVAL_SECONDS = 3
-- Its own stamp rather than one of the three above: the refusal it rate-limits
-- happens on presses none of those are counting.
local lastStaleAt

-- What the last resolved press left on the button, as appliedKey stood when
-- PreClick finished with it. The debounce below lets the second half of a press
-- through without re-resolving, and that is only safe while the button still
-- holds what the resolved half armed: an error in between repaints the prompt
-- onto the next person, and a debounced press then fired their macro with no
-- record behind it -- so the parked record from the refused press was settled
-- by the other person's cast, and the one who got the buff stayed owed.
local pressKey

-- The moment of a press the cooldown turned away, stamped in PreClick and
-- consumed by PostClick of the same press. Both run in the one frame, so the
-- clock agrees. Stamped ahead of the combat return, because in a fight the
-- macro cannot be disarmed and the bookkeeping is the only thing left to refuse.
local cooldownPressAt
-- ...and what the button was holding when the guard disarmed it, so PostClick
-- can put it back once the secure handler has had its turn and found nothing.
-- Left disarmed, a fight starting before the next scan froze the prompt empty
-- for its whole length.
local guardedEntry
-- ...and the spoken line it was carrying. The disarm wipes the roll along with
-- the macro, as every disarm must, and putting the same person back rolled a
-- fresh line -- so the tooltip, which had not changed its mind about who, went
-- on quoting the old one while the next press said another.
local guardedPhraseKey, guardedPhraseText

---------------------------------------------------------------------------
-- hysteresis
--
-- The scan runs two and a half times a second and the queue is rebuilt from
-- scratch each time. In a quiet field that is invisible; in a city it is a
-- strobe. Somebody steps a yard out of range, a nameplate is recycled, an aura
-- read falls out of the three-second cache -- and the top of the queue changes
-- for a moment. The panel hid, showed again, replayed its entrance animation
-- and replayed the sound, at 2.5 Hz, for a prompt that never actually had
-- anything new to say.
--
-- Three floors, because there are three separate things churning: who is on
-- it, whether it is on screen at all, and the sound. None of them is a
-- smoothing filter -- each one refuses a *change* for a short time and then
-- allows it, so nothing can be held back indefinitely by a queue that keeps
-- flickering.
---------------------------------------------------------------------------

-- How long a freshly painted candidate is protected from being replaced by
-- one of equal or lower priority. Someone strictly more deserving -- a favour
-- owed arriving over a passer-by -- takes the panel immediately, because that
-- is the case the prompt exists to notice.
local HOLD_SECONDS = 1.5

-- How long an empty queue is given to refill before the prompt comes down.
-- Shorter than the hold on purpose: "there is nobody" should be believed
-- quickly, it is only the first empty scan that is not worth believing.
local EMPTY_FUSE_SECONDS = 0.75

-- The floor between two sounds. Without it the sound is tied to the name
-- changing, and the name changing is exactly what churns.
local SOUND_FLOOR_SECONDS = 3

-- How long a click's outcome sits over the panel.
local OUTCOME_SECONDS = 0.6

-- The entry last painted and when, which together are what the hold is
-- measured against. Held as the whole entry rather than the name: when the
-- queue drops somebody for a scan there is nothing left to look the rest of
-- them up from, and re-arming the macro needs the buff as much as the name.
local heldEntry, heldAt
-- When the queue first came back empty, cleared the moment it refills.
local emptyAt
local lastSoundAt
-- Whether the panel is currently dimmed for combat, so the alpha is written
-- once on each transition rather than on every pass through a locked-down
-- Refresh.
local combatHeld
-- Whether a drag has actually started. The client delivers OnDragStop for
-- every drag gesture, including the ones OnDragStart refused -- a locked
-- prompt, a fight -- so the release cannot take it on trust that a move is
-- under way.
local dragging

-- What the last click turned into: "cast", "sent" or "failed", who it was
-- about, and the game's own words where it had any.
local outcomeKind, outcomeAt, outcomeName, outcomeDetail
-- Who the name line is actually about while an outcome is written over it, and
-- nil once anything else has been painted there. Kept apart from outcomeName
-- because the two end at different moments: the outcome stops being live on
-- the clock, and the words stay on the panel until something repaints it. The
-- press has to follow the words.
local outcomePainted
-- Which outcome the expiry timer was set for. A second press can put a new
-- outcome up before the first one's timer fires; that timer then has nothing
-- of its own left to take down, and is ignored rather than spending a repaint
-- on a flash that is not its own.
local outcomeGen = 0

-- The spoken line settled for the candidate currently on the button, and the
-- person, buff and reason it was settled against. Both exist so the tooltip
-- can quote a line that is still the one that will run: PickPhrase rolls a
-- random entry out of the pool, and PreClick rebuilds the macro at press time
-- -- so the line being read and the line being cast were never the same roll.
local phraseKey, phraseText

-- Which side of the panel the queue list hangs off. Decided in ApplyStyle,
-- because the only things that move the prompt come back through it.
local queueAbove

-- Everything the hysteresis is holding on to. Dropped whenever the prompt goes
-- down for a reason of its own -- switched off, unlocked, nothing learned -- so
-- that coming back up is a fresh start rather than a continuation of a panel
-- that was last on screen an hour ago.
local function ClearHold()
	heldEntry, heldAt, emptyAt = nil, nil, nil
end

-- Lights the fuse on an empty queue, once, and asks for a repaint the moment
-- it has burnt out. The scan is what used to notice, and at two seconds
-- between scans the panel stood for over a second past its own fuse, still
-- naming somebody the queue had already let go of.
local function LightFuse(now)
	if emptyAt then return end
	emptyAt = now
	if C_Timer and C_Timer.After then
		C_Timer.After(EMPTY_FUSE_SECONDS + 0.05, function()
			ns.Guard("fuse repaint", Prompt.Refresh, Prompt)
		end)
	end
end

-- Whether this entry was deliberately retired: a block is either the retry
-- cooldown a click wrote or the refusal a right-press wrote, and in both cases
-- "they are gone" is the answer that was just asked for. Asked by the repaint
-- and by the press, which have to agree about it: a press inside the fuse used
-- to keep the person a right-click had just declined, and cast at them.
local function Retired(entry, now)
	return entry ~= nil and entry.name ~= nil
		and ns.IsBlocked(entry.name, entry.buff and entry.buff.key, now)
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
end

-- Show and Hide are protected on the secure button, and the client refuses both
-- for the length of a fight without throwing, without returning anything and
-- without changing the frame. Four branches of Refresh called one of them
-- straight and returned above the branch that knows lockdown exists, so the
-- lockdown was never consulted at all: they walked away believing the panel had
-- gone up or come down when it had done neither, and whatever was last painted
-- stood for the rest of the fight.
--
-- `false` back means the panel is exactly where the fight found it, and the
-- caller then owes the user a sentence about the rectangle that did not move.
local function SetPanelShown(want)
	if InCombatLockdown() then return false end
	if want then button:Show() else button:Hide() end
	return true
end

-- Ends a move that is under way: the frame let go of, where it landed written
-- down, and the prompt locked. One place for the two ways a drag can end -- the
-- release, and a fight arriving while it is still held -- because the second
-- has to leave the prompt exactly where the first would have.
local function FinishDrag()
	dragging = nil
	button:StopMovingOrSizing()
	local point, _, relPoint, x, y = button:GetPoint()
	local p = ns.db.profile.prompt
	-- The client hands the offsets back in the frame's own scaled units, and
	-- the profile keeps UIParent's -- the units the presets, Reset position
	-- and the X and Y sliders all mean. Saved as they came, a prompt dropped
	-- at Scale 2 moved when the scale went back to 1. The frame's own scale
	-- is the one it was moved at; the profile's can be ahead of it by a slider
	-- moved in a fight, whose restyle is still waiting for the fight to end.
	local okScale, s = pcall(button.GetScale, button)
	if not okScale or type(s) ~= "number" or s <= 0 then s = p.scale end
	p.point, p.relPoint = point, relPoint
	p.x, p.y = math.floor(x * s + 0.5), math.floor(y * s + 0.5)

	-- Lock straight after a drag. An unlocked prompt cannot cast, and
	-- leaving it that way looks identical to a working one that simply has
	-- nobody to offer -- so the addon silently does nothing. Unlock again
	-- to nudge it further.
	p.locked = true
	Prompt:ApplyStyle()
	-- The page is usually open for this -- its Locked box is how the prompt
	-- was unlocked -- and it went on showing the box unticked over a prompt
	-- that had just locked itself, with the sliders and the position
	-- dropdown still describing where it used to be.
	ns.RepaintOptions()
	ns.addon:Print(L["moved and locked."])
end

-- Below the panel normally, above it when the prompt is sitting in the bottom
-- third of the screen -- which is where the default position now puts it, and
-- where five rows hanging underneath run off the bottom edge entirely.
--
-- Every call is guarded rather than checked, because neither of these methods
-- is one the addon can assume: a frame that has never been positioned has no
-- centre, and both test harnesses have neither.
--
-- The centre comes back in the prompt's own scaled units and the height in
-- UIParent's, so the centre is converted before the two are compared. Held
-- against each other raw, the line was drawn at the scale times a third of the
-- screen: at Scale 2.5 a prompt four fifths of the way up hung its list above
-- itself and off the top edge. The ratio of the two effective scales is the
-- conversion; where either is missing the prompt's own scale stands in for it,
-- which is the same number while UIParent is the prompt's parent.
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

-- What the macro currently sitting on the button is aimed at:
-- { targeted = boolean, selfCast = boolean }, or nil when there is no macro of
-- ours on it at all. PostClick copies this onto the pending click so the settle
-- handler can judge the press by what actually went out -- a /target of ours
-- aimed at this person is the one thread tying a press to a person on a client
-- that will not name a recipient.
--
-- Written here rather than worked out again over there, because a settle
-- arriving a few hundred milliseconds later would be re-deriving it from a
-- queue that has been rebuilt half a dozen times since. It is set beside
-- appliedKey, so the early return that skips a rebuild skips this too --
-- correct, because the macro it describes did not change either.
local armed

-- Amber for a favour returned, because that is the case worth noticing.
-- The others stay quiet so the prompt does not shout at you constantly.
-- Chosen so the pairs stay apart for the commonest colour blindness, not just
-- on a calibrated monitor.
--
-- The previous set put a soft green against the owed amber, which is precisely
-- the pair deuteranopia and protanopia collapse -- and amber is the one that
-- matters most, because it is the favour you owe somebody standing in front of
-- you. Target is now a pale cyan instead: it sits on the blue side with the
-- group colour but is separated from it by lightness rather than by hue, which
-- survives every form of colour blindness because it survives greyscale.
--
-- Desaturated with the weights ApplyStyle uses for the border (Rec.601), the
-- four come out at 0.83, 0.79, 0.56 and 0.54 -- target, owed, group, nearby.
-- So they are not four distinct greys. Target and group are apart by
-- lightness, 0.27, which is the pair the cyan was chosen for. Group and nearby
-- are 0.02 apart and told apart by hue and saturation alone, and target and
-- owed, 0.04 apart, by blue against amber -- the one opposition red-green
-- colour blindness leaves intact.
local REASON_COLOR = {
	target = { 0.62, 0.90, 1.00 },
	owed = { 1.00, 0.78, 0.30 },
	group = { 0.34, 0.60, 0.96 },
	nearby = { 0.52, 0.54, 0.62 },
}

local REASON_KEY = { target = "reasonTarget", owed = "reasonOwed",
	group = "reasonGroup", nearby = "reasonNearby" }

-- Whole minutes, because the refresh threshold is set in minutes and a countdown
-- ticking under the cursor reads as urgency the prompt does not mean. Under a
-- minute is the one case where seconds say something a "0m" cannot.
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

-- A method this client may not have, called if it is there. The effects below
-- use a few calls -- scale animations, start delays, the cooldown sweep's
-- settings -- that every retail-line client has and nothing here has been able
-- to watch run; a missing one costs that one detail, never the prompt.
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
-- half-width. RING_AT in tools/make-glow.py; the two have to agree, because
-- the texture is sized from this so that its rim lands on the round icon's edge.
local GLOW_RING_AT = 0.70

-- Where each piece of the square halo is cut from Glow.tga, as the left, right,
-- top and bottom of SetTexCoord. The texture is light falling off in every
-- direction from its centre, so a quarter of it is a corner that fades from the
-- icon's corner outwards, and a thin line through the middle is a side that
-- fades straight out. The strips used to be gradients, which run along one axis
-- only: the corners could not fade both ways, and the halo read as four bars
-- with a notch at each corner. Cut from one falloff, every join has the same
-- brightness on both sides of it.
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

-- Placed round `box`, outside an inset of `gap`: `sx` pixels out to the sides
-- and `sy` above and below, which differ because the panel has more room
-- beside the icon than over it. With `round` -- the size of a round icon --
-- the ring instead, sized so its rim sits on the icon's edge. The size is
-- passed rather than read off the box, which may not have been laid out yet.
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

-- The whole halo in one colour. The fade is in the texture, so this is a
-- vertex colour per piece and nothing else -- no gradient, and no colour
-- objects made on the way.
local function PaintHalo(halo, r, g, b, alpha)
	for _, t in ipairs(halo.strips) do t:SetVertexColor(r, g, b, alpha) end
	halo.round:SetVertexColor(r, g, b, alpha)
end

local function AtlasExists(name)
	if not C_Texture or not C_Texture.GetAtlasInfo then return false end
	local ok, info = pcall(C_Texture.GetAtlasInfo, name)
	return ok and info ~= nil
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

-- The one question the click path asks, in one place.
--
-- It was written out by hand at each site with a different set of members, and
-- ns.caps.anyKnown was in none of them: a character with nothing it can cast
-- still armed a macro and still filed a press against somebody, while Refresh
-- one function away had already taken the panel down for exactly that reason.
--
-- Deliberately NOT the same question as Core's "is the addon switched on".
-- That one governs bookkeeping -- whether a favour is recorded at all -- and
-- says nothing about whether the button in front of somebody should fire.
local function PromptIsLive()
	local db = ns.db and ns.db.profile
	if not db or not db.enabled then return false end
	-- Unlocked is drag mode, and a prompt being dragged must not cast.
	if not db.prompt.locked then return false end
	if testMode then return false end
	-- Belt and braces rather than a live fix, and worth saying so: BuildQueue
	-- already returns nothing when this is false, so no candidate reaches the
	-- button and no mutation of this line can be made to go red. It is here so
	-- the click path states the same condition the panel does instead of
	-- relying on a caller two files away to have got there first.
	if not ns.caps.anyKnown then return false end
	return true
end

function Prompt:Create()
	if button then return end

	button = CreateFrame("Button", "MannersPrompt", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	-- Copied exactly from the secure buttons that do work on this client.
	-- MountActions and GroupTools both use this trio, and one carries the
	-- comment "force the action to trigger on key down regardless of
	-- ActionButtonUseKeyDown":
	--
	--     RegisterForClicks("AnyDown")
	--     type = "macro"
	--     pressAndHoldAction = true
	--
	-- The two settings go together. Registering down while leaving
	-- pressAndHoldAction false leaves the click arriving, the attributes
	-- reading back correctly, and nothing cast -- which is where this was.
	button:RegisterForClicks("AnyDown")
	button:SetAttribute("pressAndHoldAction", true)
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:RegisterForDrag("LeftButton")

	art = CreateFrame("Frame", nil, button)
	art:SetAllPoints()

	-- Stacked black rectangles stand in for a soft drop shadow. Real blur is
	-- not available, but four steps of falloff, each dropped a pixel lower
	-- than the last, read as a panel lifted off the world rather than a panel
	-- with a grey frame round it. The innermost step is a crisp dark rim, which
	-- is what keeps the edge clean over a bright floor.
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

	-- A hairline of light along the top and shade along the bottom. The
	-- cheapest possible bevel, and the thing that stops a flat rectangle
	-- reading as a debug frame.
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
	-- stripe, because it replaces both: the bevel is two edges of a box that
	-- this draws all four of, and the stripe would sit on top of the left one.
	--
	-- Anchored corner to corner rather than sized, so it follows the panel
	-- through a width or height change without ApplyStyle having to measure it.
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

	-- Doubles as the icon's border and as the reason signal. A ring around the
	-- icon reads far better than a hairline stripe at the panel edge, which
	-- ends up competing with the icon rather than framing it.
	iconBack = Solid(art, "BACKGROUND", -2)
	iconBack:SetVertexColor(0, 0, 0, 0.85)
	iconEdge = Solid(art, "BACKGROUND", -1)
	iconEdge:SetVertexColor(0, 0, 0, 0.9)

	icon = art:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	iconShade = Solid(art, "ARTWORK", 1)

	-- The global cooldown swept over the icon, the way an action button shows
	-- it. A Cooldown frame is not protected and the client animates it itself,
	-- so it costs nothing per frame here and is allowed in a fight. Made in a
	-- pcall because the template is the one part of this that is not ours: a
	-- client without it has an icon with no sweep, not a prompt that failed to
	-- build.
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

	-- Above every other art layer and below textLayer, which is a frame of its
	-- own and therefore draws over all of them. That is what makes the wash
	-- read as light falling on the panel rather than as a rectangle over the
	-- name.
	resultFill = Solid(art, "ARTWORK", 2)
	resultFill:SetAllPoints()
	resultFill:Hide()

	-- The highlight layer only reacts to the mouse on a Button, so it belongs
	-- to the button itself rather than to the art frame.
	button:SetHighlightTexture(WHITE, "ADD")
	local hl = button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.045) end

	-- The list of who is next hangs outside the panel, so it gets a panel of its
	-- own. Same background at a lower alpha, divided from the prompt by a
	-- hairline, because without one the rows were unreadable text lying
	-- directly on the world -- and on a dark floor they simply were not there.
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
		-- Three pixels of the reason colour in front of each row. Priority is
		-- the one thing about the list worth knowing at a glance, and reading
		-- four words of grey text to find it out is not a glance.
		local bar = Solid(art, "ARTWORK", 1)
		bar:Hide()
		queueBars[i] = bar
	end

	self:BuildAnimations()

	button:SetScript("OnDragStart", function(self)
		if ns.db.profile.prompt.locked or InCombatLockdown() then return end
		self:StartMoving()
		dragging = true
	end)

	-- Only a drag that started has anything to end. The release arrives for
	-- the refused ones too, and ending them stopped a move on the secure button
	-- in combat -- a call the client refuses there -- and said "moved and
	-- locked." for a click on a locked prompt that slid a few pixels. A drag
	-- still held when a fight starts was ended at the start of it (FinishDrag,
	-- from PLAYER_REGEN_DISABLED), so one released in combat has nothing left
	-- to do but forget itself.
	button:SetScript("OnDragStop", function()
		if not dragging then return end
		if InCombatLockdown() then
			dragging = nil
			return
		end
		FinishDrag()
	end)

	-- Remember that we tried this person so the queue moves on even if the
	-- cast failed for reasons we cannot see: line of sight, range, immunity.
	-- MountActions does the same thing: PreClick runs before the secure handler
	-- reads the attributes, and out of combat it may still change them. So the
	-- target is re-resolved at the last possible moment, and a nameplate token
	-- that has since been handed to somebody else can never be cast at.
	-- RegisterForClicks("AnyDown") is what makes the secure handler act at all
	-- on this client, but it means every mouse button reaches these handlers.
	-- Only the left button casts; a right-press to turn the camera used to
	-- burn the candidate: retry cooldown set, favour cleared, nothing cast.
	button:SetScript("PreClick", function(self, mouseButton)
		if mouseButton and mouseButton ~= "LeftButton" then return end
		local now = GetTime()

		-- Asked before the fight is, because the fight does not stop the global
		-- cooldown mattering. In combat the macro is frozen and nothing here can
		-- disarm it, so a press inside the cooldown still goes out and is still
		-- refused -- and PostClick used to file it against the frozen person,
		-- which is the very blame the guard below was written to stop. The
		-- bookkeeping can still be refused where the macro cannot.
		local ready, left = ns.CastReady()
		-- In combat the frozen macro goes out whatever this decides, and one
		-- pressed in the last stretch of the cooldown is not refused: the client
		-- queues it and casts it when the cooldown ends. Treating that as turned
		-- away dropped the bookkeeping for a buff that actually landed, so the
		-- person stayed owed and was offered -- and cast at -- again. Only a
		-- press too early to be queued is one the game refuses.
		--
		-- Out of combat the whole cooldown is still held back: there the macro
		-- CAN be disarmed, and a queued /cast would fire after /targetlasttarget
		-- has already handed the old target back.
		if InCombatLockdown() and not ready and left <= ns.SpellQueueWindow() then
			ready = true
		end
		cooldownPressAt = (not ready) and now or nil
		if InCombatLockdown() then return end

		-- Down and up both land here; one rebuild per press is enough -- but only
		-- while the button still holds what that rebuild armed. Between the two
		-- halves an error can repaint the prompt onto somebody else, and a cast
		-- can start the cooldown, and in either case what is sitting on the
		-- button is not something this press resolved.
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

		-- A keypress with an empty prompt is otherwise indistinguishable from a
		-- binding that does not work, which is what this one was. Says it here
		-- rather than in Bindings.xml because the macro route lands here too.
		--
		-- And it says why the panel is empty where that is the addon's own
		-- doing. A key pressed after /manners off used to hear "nobody to buff"
		-- -- often untrue, since the queue is built whatever the switch says --
		-- and nothing about the switch that actually took the panel away.
		--
		-- The commands go in as arguments rather than as part of the sentence:
		-- they are what the player has to type, in English in every language,
		-- and a translator should never be handed them to translate. The option
		-- and tab names go in the same way, through the keys the options window
		-- shows them with, so the sentence names the labels the player will find.
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
					:format("|cffffd100" .. L["Not while mounted"] .. "|r", L["When"]))
			elseif not ns.caps.anyKnown then
				local class = ns.caps.class
				if class and ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class] then
					ns.addon:Print(ns.NO_CLASS_BUFFS)
				else
					ns.addon:Print(L["nothing learned to cast yet."])
				end
			else
				ns.addon:Print(L["nobody to buff right now."])
			end
			Prompt:ApplyTarget(nil)
			return
		end

		-- An unlocked or disabled prompt must not cast, and PreClick is the
		-- last chance to make sure of it: it runs after Refresh has decided
		-- what to show but before the secure handler reads the attributes.
		if not PromptIsLive() then
			Prompt:ApplyTarget(nil)
			return
		end

		-- Nor may a press during the global cooldown. Disarming here is what
		-- stops it reaching the server: a cast sent inside that second and a
		-- half is refused, and the refusal used to be filed against the person
		-- it was aimed at -- so they were marked tried and dropped, and the
		-- one thing the user actually wanted never happened. Nothing is cast,
		-- nothing is recorded, and the panel says why.
		--
		-- And it does not count as a press. Its stamp is taken back, so a press
		-- a moment later -- the cooldown ends mid-click as often as not -- is
		-- resolved properly rather than swallowed by the debounce above, which
		-- either did nothing or fired whatever a scan had re-armed with no
		-- record filed for it.
		if not ready then
			lastPreClickAt = nil
			guardedEntry = current
			guardedPhraseKey, guardedPhraseText = phraseKey, phraseText
			Prompt:ApplyTarget(nil)
			Prompt:SayWaiting(left)
			return
		end

		local queue = ns.BuildQueue()
		local top = Prompt:PickTop(queue, queue[1])
		local named = Prompt:PanelName()
		-- An empty queue under a panel still naming somebody is the panel
		-- showing a person it has not given up on yet, and the press has to
		-- agree with what is on screen. Re-resolving to nobody here would disarm
		-- a prompt that is visible and naming a person, so the click would do
		-- nothing at all and say nothing about it -- the silent failure the fuse
		-- was added to avoid, arriving by the other door.
		--
		-- Asked of the panel rather than of the fuse's clock. Only a scan lights
		-- the fuse, so a press between somebody stepping out of range and the
		-- next scan noticing found no fuse at all; and one after the fuse had
		-- burnt out found the panel still up until the repaint came to take it
		-- down. Both disarmed a prompt still naming them. The worst this can do
		-- instead is send a cast the game refuses, and that says so in red.
		--
		-- Unless that person was retired: a right-click skip leaves them named
		-- on the panel until the repaint, and this must not keep them armed for
		-- a left press to cast at, and speak at, somebody just declined. Nor
		-- when a flash about somebody else is written over their name: the
		-- press follows the words on the panel, never the entry under them.
		if not top and current and not Retired(current, now) and named == current.name then
			LightFuse(now)
			pressKey = appliedKey
			return
		end

		-- And the press goes to whoever the panel is naming, not to whoever the
		-- queue has just promoted. PickTop hands the panel to somebody strictly
		-- better at once, which is right for the next repaint and wrong for a
		-- press made on this one: a target picked up a tenth of a second ago
		-- was cast at, and spoken to, under a panel still naming somebody else.
		-- The same goes for a red flash about a refused press, which sits over a
		-- button the refusal has already re-armed at the next person.
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

		appliedKey = nil
		Prompt:ApplyTarget(top)
		pressKey = appliedKey
	end)

	button:SetScript("PostClick", function(self, mouseButton, down)
		-- Nothing below casts anything -- the secure handler has already had its
		-- turn -- but all of it is bookkeeping about a cast this addon asked for,
		-- and switched off, unlocked or previewing it asked for none. Hiding the
		-- button was never a guard: a CLICK binding is delivered to a hidden
		-- frame, so a disabled addon went on settling debts and blocking people
		-- for every press of the key.
		--
		-- In combat the macro cannot be disarmed, so the press may genuinely have
		-- cast from an attribute armed before the addon was switched off.
		-- Refusing the bookkeeping is the honest answer to that -- the debt stays
		-- standing, because none of what we meant to do happened -- and the line
		-- says so rather than leaving somebody to wonder why a buff went out. Its
		-- own stamp, because down and up both land here.
		local db = ns.db and ns.db.profile
		if not PromptIsLive() then
			local now = GetTime()
			-- Only a press that could have cast gets the warning. type2 to
			-- type5 are "none", so the secure handler matches nothing for the
			-- right button however stale the macro sitting on the attributes
			-- is -- and this guard is above the right-button branch, so it was
			-- telling somebody who pressed to skip that a buff may have gone
			-- out when provably none did. A keybinding arrives with no button
			-- at all and is treated as a left press, which is the same reading
			-- the cast path below takes.
			local couldCast = mouseButton == nil or mouseButton == "LeftButton"
			if couldCast and db and db.verbose and InCombatLockdown() and self:GetAttribute("macrotext1")
				and not (lastStaleAt and (now - lastStaleAt) < 0.25) then
				lastStaleAt = now
				ns.addon:Print(L["|cffff8080that may still have cast|r -- the prompt cannot be disarmed in combat, and nothing was recorded for it."])
			end
			return
		end

		-- A right-press says "not this one", which is not a repayment: the debt
		-- stands, nothing is cast, and only the offer is postponed. The block is
		-- on the person rather than the buff, because declining is about who is
		-- being offered, not which spell they would have got.
		if mouseButton == "RightButton" then
			-- Its own stamp: sharing the cast path's would let a right-press
			-- swallow a real left click landing just after it.
			local now = GetTime()
			if lastSkipAt and (now - lastSkipAt) < 0.25 then return end
			lastSkipAt = now
			-- Whoever the panel names, which the left press was already made to
			-- follow. Under a red flash that is the person the flash is about,
			-- while `current` is the next one the refusal re-armed underneath --
			-- so the skip declined somebody still out of sight for the full
			-- cooldown, and the one on screen came back two seconds later. With
			-- nobody underneath at all it did nothing and said nothing.
			local victim = Prompt:PanelName() or (current and current.name)
			if not victim then
				ns.addon:Print(L["nobody to skip right now."])
				return
			end
			local db = ns.db and ns.db.profile
			-- The retry cooldown, not the two seconds a failed cast writes:
			-- that would put them straight back on the prompt.
			ns.BlockPerson(victim)
			Prompt:StopAttention()
			-- Held shift makes it "never", not "not now": onto the never-offer
			-- list, with a line saying how to undo it. The block above is still
			-- wanted -- it is what takes them off the panel at once rather than
			-- after the hold and the fuse -- and nothing else here differs from
			-- the skip, so the secure side cannot tell the two apart: type2 is
			-- "none", no shift- attribute is ever set, and the shifted press
			-- matches nothing exactly as the plain one does.
			--
			-- Nothing in this branch touches the button, so it is as safe in a
			-- fight as the skip. The list reaches the queue at its next rebuild,
			-- which in a fight is when it ends.
			if IsShiftKeyDown and ns.plain(IsShiftKeyDown()) then
				ns.PutOnNeverList(victim)
				ns.Guard("never repaint", Prompt.Refresh, Prompt)
				return
			end
			if db and db.verbose then
				local shown = (current and current.name == victim and current.short)
					or (ns.ShortName and ns.ShortName(victim)) or victim
				ns.addon:Print(L["skipping |cffffffff%s|r for now."]:format(shown))
			end
			-- And the panel moves on now rather than at the next scan. Until it
			-- did, the declined person stayed named and armed for up to a scan --
			-- longer with the fuse burning -- and a left press in that time cast
			-- at them. Refresh knows about the fight and about an empty queue.
			ns.Guard("skip repaint", Prompt.Refresh, Prompt)
			return
		end
		if mouseButton and mouseButton ~= "LeftButton" then return end

		local now = GetTime()
		-- A press the cooldown turned away is not a press: nothing reached the
		-- server, so nothing is filed, and it takes no stamp that would swallow
		-- the next one. Out of combat PreClick disarmed it and this puts back
		-- what it found, so a fight starting now finds the prompt armed. In
		-- combat the frozen macro went out and was refused, and refusing the
		-- bookkeeping is the whole of what is left to do.
		if cooldownPressAt == now then
			cooldownPressAt = nil
			local found = guardedEntry
			guardedEntry = nil
			if found and not InCombatLockdown() then
				-- The line it was carrying goes back with it, so the macro is
				-- rebuilt around the roll the tooltip has been quoting rather than
				-- a new one.
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
		-- Only assembled when asked for: /manners clicks. The build stamp stays
		-- because a log that does not say which build produced it can be
		-- diagnosed for an hour before anyone notices the game never loaded
		-- the file being read.
		if ns.db and ns.db.profile.debugClicks then
			ns.addon:Print(("|cffffd100CLICK|r build=%s macro=%s"):format(
				tostring(ns.BUILD),
				tostring(button:GetAttribute("macrotext1") or "nil"):gsub("%s+", " ")))
		end
		if not (current and current.name) then return end

		-- Hold the debt rather than clearing it outright. The game says a few
		-- hundred milliseconds later whether anything was actually cast, and
		-- clearing here meant a cast blocked by range or line of sight counted
		-- as a favour returned.
		--
		-- What the macro was aimed at rides along, and so does the rotation
		-- pointer as it stood before this press moved it. The settle handler
		-- reads both: the first so a name is only ever judged on a /target that
		-- was really there, the second so a cast that went nowhere can put the
		-- pointer back instead of walking this person off their own buff list.
		-- gave is read here, above the write below, which is the only place it
		-- is still the old value.
		--
		-- And before any of that, whatever is already parked is dealt with. One
		-- slot with no identity on it means the record about to be overwritten
		-- cannot be matched to the event that will arrive for it -- so the next
		-- cast event would be read against this press whichever press it
		-- belongs to. Above the read of ns.lastGave as well as the write,
		-- because abandoning the old record puts that pointer back and this
		-- record has to carry the value that is there afterwards.
		ns.AbandonPendingClick()
		ns.pendingClick = { name = current.name, at = GetTime(),
			buffKey = current.buff and current.buff.key,
			selfCast = armed ~= nil and armed.selfCast == true,
			targeted = armed and armed.targeted,
			-- The spelling the macro aimed at, straight from the builder. The
			-- settle path compares it against whoever the client says was hit,
			-- and taking it from here is what stops that comparison being a
			-- second opinion about text the builder already had in hand.
			aimedAt = armed and armed.aimedAt,
			-- Whether the scan measured them inside a shout's reach. A selfCast
			-- press has nothing else tying it to the person named, so the
			-- settle clears a debt on it only where this is true.
			withinShout = current.ranged == true,
			-- And whether it measured them outside it, which is a different
			-- reason for the same kept debt: with "Hide players known to be out
			-- of range" off they are still offered, and the line has to say the
			-- answer was no rather than that nothing answered.
			outOfShout = current.ranged == false,
			-- For the favour ledger, which records who a buff went to and
			-- whether they were in the group; nothing on the settle path reads
			-- either.
			class = current.class,
			inGroup = current.inGroup,
			gave = ns.lastGave[current.name] }
		-- Per buff, so casting Fortitude does not stop the walk reaching
		-- Divine Spirit on the next click.
		if current.buff then
			ns.MarkAttempted(current.name, current.buff.key)
			-- Only where the walk will read it back. A paladin's blessings
			-- overwrite one another, so PickBuffFor deliberately never rotates
			-- them -- and a pointer written for a walk that will not happen is
			-- a record of nothing, which is exactly how this one came to be
			-- believed as a feature.
			if ns.RotatesBuffs() then ns.lastGave[current.name] = current.buff.key end
		end
		Prompt:StopAttention()
	end)

	button:SetScript("OnEnter", function(self)
		-- Nothing armed is nothing to describe, and a tooltip already up from
		-- the last person goes with it: "Click to cast" over a press that does
		-- nothing is the tooltip describing a button that is no longer there.
		if not current or not current.buff then
			if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
			return
		end
		-- Every line below describes the macro sitting on the button, and in
		-- combat that macro is frozen at whoever was on it when the fight
		-- started -- Blizzard will not let an addon retarget a secure frame.
		-- The tooltip is the most detailed thing the prompt says, and saying it
		-- in that much detail about somebody stale is worse than saying nothing.
		if InCombatLockdown() then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Manners")
		GameTooltip:AddDoubleLine(current.short or current.name, ns.BuffName(current.buff),
			1, 1, 1, 0.8, 0.8, 0.8)
		-- The refresh mode offers somebody a buff it has read them as already
		-- holding, and for those people "missing it" is simply untrue --
		-- the countdown line below used to sit under it saying so, one line
		-- apart. Naming the contradiction is not the same as removing it, so
		-- the reason itself changes: a top-up is a different offer and reads
		-- like one, and the countdown then says how urgent it is.
		--
		-- And "missing it" only where it was read as missing. "Always offer"
		-- does not look at all, and a client that hides auras cannot, so both
		-- used to read "missing it" with the line underneath saying nothing was
		-- checked -- about somebody who may well have been wearing it. Those two
		-- get the plain reason, and the line below says why nothing more is
		-- known.
		local left = RemainingText(current.remaining)
		local why
		if current.reason == "owed" then
			why = L["Buffed you -- return the favour."]
		elseif left then
			why = current.reason == "group" and L["In your group, and theirs is running out."]
				or current.reason == "target" and L["Your target, and theirs is running out."]
				or L["Nearby, and theirs is running out."]
		elseif current.known == false then
			why = current.reason == "group" and L["In your group and missing it."]
				or current.reason == "target" and L["Your target, and missing it."]
				or L["Nearby and missing it."]
		else
			why = current.reason == "group" and L["In your group."]
				or current.reason == "target" and L["Your target."]
				or L["Nearby."]
		end
		GameTooltip:AddLine(why, 0.7, 0.7, 0.7, true)
		-- Why they are ahead of the others like them, where Who comes first
		-- put them there. Only ever set for a group member or a passer-by.
		if current.close == "friend" then
			GameTooltip:AddLine(L["On your friends list."], 0.7, 0.7, 0.7, true)
		elseif current.close == "guild" then
			GameTooltip:AddLine(L["In your guild."], 0.7, 0.7, 0.7, true)
		end
		if left then
			GameTooltip:AddLine(L["Theirs expires in %s."]:format(left), 0.7, 0.7, 0.7, true)
		end
		if current.checked and current.known == nil then
			GameTooltip:AddLine(L["Buff state unreadable on this build -- they may already have it."],
				1, 0.5, 0.5, true)
		elseif not current.checked then
			GameTooltip:AddLine(L["Not checking whether they have it -- set by your options."],
				0.7, 0.7, 0.7, true)
		end
		GameTooltip:AddLine(" ")
		-- Plain English, first. What was here before was headed "Will run:" and
		-- quoted the macro -- four lines of slash commands at somebody who
		-- wanted to know what the button does -- and it was not even an honest
		-- quote, for the reason ClickSummary sets out.
		for _, line in ipairs(Prompt:ClickSummary(current)) do
			GameTooltip:AddLine(line, 0.62, 0.78, 0.62, true)
		end
		GameTooltip:AddLine(" ")
		-- The raw macro is a debugging tool and reads like one, so it goes where
		-- the other debugging tools are. /manners clicks turns it back on.
		if ns.db.profile.debugClicks and ns.lastMacro then
			GameTooltip:AddLine(L["Will run:"], 0.5, 0.5, 0.5)
			for line in ns.lastMacro:gmatch("[^\r\n]+") do
				GameTooltip:AddLine("  " .. line, 0.4, 0.8, 0.4)
			end
			GameTooltip:AddLine(" ")
		end
		-- The command goes in as an argument, as it does in PreClick's lines: it
		-- is typed in English whatever the client's language.
		GameTooltip:AddLine(L["Click to cast. %s for options."]:format("|cffffd100/manners|r"),
			0.5, 0.5, 0.5)
		-- A gesture nobody can discover is not a feature.
		GameTooltip:AddLine(L["Right-click to skip this one."], 0.5, 0.5, 0.5)
		-- Somebody already on the list is only here because they are owed, and
		-- for them the same press lets that favour go; offering to put them on
		-- a list they are on was the tooltip describing a different person.
		if ns.IsNeverOffered and ns.IsNeverOffered(current.name) then
			GameTooltip:AddLine(L["Shift-right-click to let this favour go."], 0.5, 0.5, 0.5)
		else
			GameTooltip:AddLine(L["Shift-right-click to put them on your never-offer list."], 0.5, 0.5, 0.5)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Keep the tooltip honest if the entry changes while it is open.
	-- Checked a few times a second rather than every frame; the target cannot
	-- change faster than the scan interval anyway.
	button:SetScript("OnUpdate", function(self, elapsed)
		self.sinceCheck = (self.sinceCheck or 0) + elapsed
		if self.sinceCheck < 0.2 then return end
		self.sinceCheck = 0
		if not GameTooltip:IsOwned(self) then return end
		if not (current and current.buff) then
			self.tooltipFor = nil
			GameTooltip:Hide()
			return
		end
		-- Keyed on everything the tooltip says, not on the name alone. The same
		-- person moves from one buff to the next as a priest's walk settles, a
		-- passer-by becomes somebody you owe, and the spoken line is re-rolled
		-- when the macro is -- and keyed on the name, the tooltip went on naming
		-- the old buff, the old reason and the old line over a button that would
		-- cast and say the new ones.
		local shown = table.concat({ current.name, current.buff.key, tostring(current.reason),
			tostring(phraseText), tostring(appliedKey) }, "\1")
		if self.tooltipFor ~= shown then
			self.tooltipFor = shown
			local onEnter = self:GetScript("OnEnter")
			if onEnter then onEnter(self) end
		end
	end)

	button:Hide()
end

---------------------------------------------------------------------------
-- animation
---------------------------------------------------------------------------

function Prompt:BuildAnimations()
	-- Entrance: rise into place and fade in. Short, eased out, never repeated.
	--
	-- A translation is undone the moment its group ends, so the old single
	-- step -- up six pixels -- rose past the panel's place and then dropped
	-- back into it with a visible hop at the end. The drop comes first now,
	-- in an instant, and the rise brings it back to exactly where it belongs,
	-- so the group ends where the panel already is.
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

	-- A single flash is easy to miss if you were looking elsewhere. This one
	-- keeps breathing for as long as somebody is still owed a buff, and stops
	-- the moment they are not.
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

	-- A refusal: the text gives a small shake of the head. Two pixels either
	-- way and back to rest, a quarter of a second in all -- enough to say no
	-- without turning the panel into an alarm.
	local shake = textLayer:CreateAnimationGroup()
	for i, dx in ipairs({ -2, 4, -4, 2 }) do
		local step = shake:CreateAnimation("Translation")
		step:SetOffset(dx, 0)
		step:SetDuration(0.06)
		step:SetOrder(i)
	end
	textLayer.shake = shake

	-- Leaving after the last buff: the panel fades out over the second half of
	-- the confirmation, so it goes rather than vanishes. Only ever played while
	-- the prompt is on its way down anyway -- the secure button is hidden when
	-- the confirmation runs out, exactly as before, and this changes nothing
	-- about when. Parked at invisible when it finishes, because the button is
	-- not hidden until a moment later, and the next Refresh puts the alpha back.
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

	-- A fade cancelled part-way, brought back to where the panel rests rather
	-- than snapped there. Two ways in: somebody arrives while the panel is on
	-- its way out, and a fight starts, which keeps the panel up whatever it
	-- was doing -- the button cannot be hidden in combat. From and to are set
	-- for each play, from how far the fade had got.
	local comeback = art:CreateAnimationGroup()
	local cFade = comeback:CreateAnimation("Alpha")
	cFade:SetDuration(0.18)
	if cFade.SetSmoothing then cFade:SetSmoothing("OUT") end
	comeback.fade = cFade
	art.comeback = comeback
end

-- Whether the extra motion is wanted: the landing burst, the shine, the shake
-- and the fade on the way out. "Calm" keeps the prompt as it was before those
-- existed -- fades, the text cross-fade and the favour glow -- for anybody who
-- finds movement at the edge of the screen distracting.
local function FullEffects()
	local p = ns.db and ns.db.profile.prompt
	return p ~= nil and p.effects ~= "calm"
end

-- The alpha art should have when nothing is animating it: dimmed for a fight,
-- full otherwise. One place, because the fade on the way out leaves art at
-- zero and every way back onto the screen has to undo that.
local function RestArtAlpha()
	art.faded = nil
	art:SetAlpha(combatHeld and 0.55 or 1)
end

function Prompt:StopOutro()
	if art.outro and art.outro:IsPlaying() then art.outro:Stop() end
	if art.faded then RestArtAlpha() end
	art.outroFor = nil
end

-- How far the fade on the way out has taken art, worked out from when it
-- started rather than read back: what GetAlpha answers in the middle of an
-- animation is not something this client has been seen to settle. The same
-- shape the fade is built with -- a wait, then an eased-in fall to nothing.
local function OutroAlpha()
	if art.faded then return 0 end
	if not (art.outro and art.outro:IsPlaying() and art.outroAt) then return nil end
	local wait = OUTCOME_SECONDS * 0.5
	local t = (GetTime() - art.outroAt - wait) / (OUTCOME_SECONDS * 0.5)
	if t <= 0 then return 1 end
	if t >= 1 then return 0 end
	return 1 - t * t
end

-- The fade on the way out, for the outcome being shown now. Started again for
-- each new outcome rather than once: a second one -- a refusal that arrives a
-- moment after the buff before it, the realistic case -- would otherwise be
-- painted onto a panel the first one's fade had already taken to nothing, or
-- cut short by a fade that was half over when it arrived.
function Prompt:PlayOutro(stamp)
	if art.outroFor == stamp then return end
	self:StopOutro()
	if art.comeback and art.comeback:IsPlaying() then art.comeback:Stop() end
	art.outroFor, art.outroAt = stamp, GetTime()
	art.outro:Play()
end

-- A fade that a repaint has just cancelled, taken back to the resting alpha
-- from wherever it had got to, over a moment. `from` is nil when no fade was
-- running, and then there is nothing to do.
function Prompt:ComeBack(from)
	self:StopOutro()
	local rest = combatHeld and 0.55 or 1
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
end

-- The band of light across the panel, in the colour given. Brighter for a buff
-- that landed than for somebody arriving on the panel: the first is the answer
-- to a question the player asked, the second only a nudge.
--
-- Not on the Minimal look, which has no panel: the band is additive light, and
-- with nothing under it, it was a white column sweeping across the game world
-- behind the text.
function Prompt:PlayShine(r, g, b, strength)
	if not shineFrame.anim then return end
	if ns.db and ns.db.profile.prompt.style == "minimal" then return end
	Gradient(shineLeft, "HORIZONTAL", r, g, b, 0, r, g, b, strength)
	Gradient(shineRight, "HORIZONTAL", r, g, b, strength, r, g, b, 0)
	shineFrame.anim:Stop()
	shineFrame.anim:Play()
end

-- The cooldown sweep, brought up to date with the client. Asked for when a
-- cast goes out and when the panel comes up, never on a timer: the Cooldown
-- frame animates itself, so between those two moments there is nothing to do.
function Prompt:SyncCooldown()
	if not cooldown then return end
	local p = ns.db and ns.db.profile.prompt
	-- And not in a fight with "Stay quiet in combat" on, which promises a
	-- panel that sits still for the length of it. Every cast of the fight
	-- starts a global cooldown, most of them from the action bars, so the
	-- sweep would be the busiest thing on a panel asked to be quiet. The
	-- Cooldown frame is ours and not protected, so hiding it in combat is
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
end

-- `isNew` is somebody owed who has just become the one on the panel, which is
-- what the flash and the stripe's sweep answer to. `arrived` is narrower: the
-- favour itself has only just been done, which is what the light on arrival
-- answers to -- see Refresh for why the two are not the same moment.
function Prompt:StartAttention(isNew, arrived)
	local p = ns.db.profile.prompt
	local mode = p.flashStyle or "pulse"
	if mode == "off" then
		self:StopAttention()
		return
	end

	-- The stripe's sweep first, and whatever the icon is doing. It has nothing
	-- to do with the icon, and returning on a hidden icon above it silenced
	-- both flash styles outright -- the setting stayed on the page, enabled,
	-- and did nothing at all with the accent on the stripe.
	if isNew and sweepFrame.anim and sweepFrame:IsShown() then
		sweepFrame.anim:Stop()
		sweepFrame.anim.move:SetOffset(0, -(p.height - 14))
		sweepFrame.anim:Play()
	end

	-- And the panel catches the light once, as the favour is done. Nothing to
	-- do with the icon either, so it is above the return below as well. In
	-- the reason colour where the prompt uses one, plain light where the
	-- player has asked for no accent at all.
	--
	-- Never over an outcome, or over light already crossing: the success of
	-- the last press sends its own band across, and the repaint that follows
	-- it -- usually the next person owed -- used to restart the band in this
	-- dimmer colour, so the answer to the press was cut off by a nudge.
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
		-- Unconditionally, and before anything else plays: the looping pulse is
		-- only ever stopped inside the branch above, so changing Flash style
		-- away from Pulse left it running and the one-shot flash played on top
		-- of a glow that never went out.
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

function Prompt:AccentColor(reason)
	local p = ns.db.profile.prompt
	if not p.accentByReason then return unpackColor(p.accentColor, { 0.45, 0.4, 0.9, 1 }) end
	local c = REASON_COLOR[reason or "nearby"] or REASON_COLOR.nearby
	return c[1], c[2], c[3], 1
end

-- How tall the prompt has to be for a second line at this font size: both
-- fonts plus the insets. Published because the options page states it, and a
-- page with its own figure is how "at least 34 pixels" outlived the 34.
function ns.TwoLineHeight(fontSize)
	return 16 + fontSize + math.max(7, fontSize - 3)
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

	button:SetSize(p.width, p.height)
	button:SetScale(p.scale)
	button:SetAlpha(p.alpha)
	button:ClearAllPoints()
	-- The stored offsets are in UIParent's units, and the client reads
	-- SetPoint's in the frame's own scaled ones, so they are divided by the
	-- scale on the way in. Passed straight through, every offset was
	-- multiplied by it: at Scale 2 "Above the action bars" sat 600 up instead
	-- of 300, and moving the slider moved the prompt. FinishDrag converts the
	-- other way.
	button:SetPoint(p.point, UIParent, p.relPoint, p.x / p.scale, p.y / p.scale)

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

	-- The border, and the one look that has it. Derived from the panel colour
	-- rather than fixed, because the panel colour is the user's: a light panel
	-- with a hardcoded pale border has no border, and finding that out means
	-- opening the colour picker and wondering whether the setting works.
	--
	-- Pushed away from the panel, not towards white. Brightening towards white
	-- is the same failure the paragraph above describes, arrived at from the
	-- other side: the lighter the panel, the less room there is above it, so the
	-- edge converges on the panel exactly as the panel gets pale, and at white
	-- the two are the same colour. So the direction is chosen from the panel's
	-- own luminance -- a dark panel gets a lighter edge, a light one a darker
	-- edge -- and the distance is a fraction of the room available in whichever
	-- direction was picked, which is the same separation either way.
	local framed = style == "framed"
	-- Rec. 601 weights rather than a flat average. Green carries most of the
	-- apparent brightness, so an average calls a saturated blue panel mid-grey
	-- and lands the edge on top of it -- the one case this is here to prevent.
	local lighten = (0.299 * br + 0.587 * bg + 0.114 * bb) <= 0.5
	-- The same question decides whether the reason line can carry a tint: on a
	-- dark panel a grey warmed towards the reason colour still reads, on a
	-- light one it loses the contrast the plain grey had. With no panel at all
	-- the world is behind it, which is dark far more often than not.
	tintSub = lighten or style == "minimal"
	local function edgeOf(c, amount)
		if lighten then return c + (1 - c) * amount end
		return c * (1 - amount)
	end
	-- Blue travels a little further towards light and a little less far towards
	-- dark, so the edge lands slightly cooler than the panel in both directions.
	-- That is the tint the framed look already had, and it is worth keeping: a
	-- dead-neutral border on a tinted panel reads as grey dirt rather than as a
	-- frame. The two numbers are the same 0.05 of bias, mirrored.
	local er, eg, eb = edgeOf(br, 0.50), edgeOf(bg, 0.50),
		edgeOf(bb, lighten and 0.55 or 0.45)
	for _, edge in ipairs(edges) do
		edge:SetShown(framed)
		edge:SetVertexColor(er, eg, eb, math.min(1, ba + 0.10))
	end

	local mode = p.accentMode or "icon"
	-- Not on the framed look: the stripe would run down the inside of the left
	-- edge, a second line a pixel from the first, which reads as a drawing
	-- mistake rather than as a reason colour. The ring around the icon is still
	-- there, and it is the better carrier of the two anyway.
	local showAccent = not framed and (mode == "stripe" or mode == "both")
	accentTop:SetShown(showAccent)
	accentBottom:SetShown(showAccent)
	accentTop:SetHeight(p.height / 2)
	accentBottom:SetHeight(p.height / 2)
	sweepFrame:SetShown(showAccent)

	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT
	local outline = style == "minimal" and "OUTLINE" or ""

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
				-- The sweep follows the icon's shape: the mask art doubles as
				-- the swipe texture, which is how the client's own round
				-- buttons do it.
				if cooldown then
					Try(cooldown, "SetSwipeTexture", "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
				end
				round = true
			end
		else
			if iconMask then iconMask:Hide() end
			if cooldown then Try(cooldown, "SetSwipeTexture", WHITE) end
		end

		-- The halo starts where the ring stops, so it frames the icon without
		-- ever lying over it, and it stops at the panel's edge: past it, even a
		-- little light read as bars stuck to the top and bottom of the prompt,
		-- and on the framed look it lit the border up over the icon. There is
		-- more room beside the icon than above it -- ten pixels to the panel's
		-- edge on the left and to the text on the right -- so the halo reaches
		-- further sideways. A rounded icon wears the ring instead, whose rim is
		-- its own edge: square pieces round a circle read as a picture frame.
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

	-- count chip
	--
	-- Sized from the font, like everything else on the panel. It was a fixed
	-- 20x14 box with a fixed 28px reserved beside it, holding a number drawn at
	-- fontSize - 3 -- and the font slider goes to 32, where those digits are
	-- taller than the box they sit in and wider than the gap left for it. The
	-- chip then read as a smudge behind a number spilling over the name.
	--
	-- The arithmetic is pinned so it reproduces the old constants exactly at the
	-- default font of 13, where they were chosen and where they looked right:
	-- 20 wide, 14 high, 28 reserved. Nobody who never touched the slider sees
	-- anything move.
	local countSize = math.max(8, p.fontSize - 3)
	-- A digit is about half the font's size across, so this is room for four of
	-- them. The queue never gets near that; the width is what keeps the chip a
	-- chip rather than a square around one number.
	local chipWidth = countSize * 2
	-- Kept inside the panel at the top of the slider, where a chip grown from
	-- the font would otherwise stand taller than the prompt it is drawn on.
	local chipHeight = math.min(countSize + 4, math.max(8, p.height - 6))
	countChip:ClearAllPoints()
	countChip:SetPoint("RIGHT", -7, 0)
	countChip:SetSize(chipWidth, chipHeight)
	countChip:SetShown(false)
	Gradient(countChip, "VERTICAL", 1, 1, 1, 0.03, 1, 1, 1, 0.09)

	-- What the name and sub-line have to keep clear: the chip itself, the 7px it
	-- is inset from the right edge, and a point of gap so the two do not touch.
	local countRoom = p.showCount and (chipWidth + 8) or 10

	-- text
	-- The arithmetic the constant 34 stood in for. Two lines need both fonts
	-- plus the insets, and at the top of the font slider 34 is not close --
	-- so the sub-line silently vanished at sizes the page happily offers.
	local twoLine = p.showSub and p.height >= ns.TwoLineHeight(p.fontSize)

	nameText:ClearAllPoints()
	subText:ClearAllPoints()
	nameText:SetFont(fontPath, p.fontSize, outline)
	nameText:SetTextColor(unpackColor(p.fontColor, { 1, 1, 1, 1 }))
	subText:SetFont(fontPath, math.max(7, p.fontSize - 3), outline)
	subText:SetTextColor(0.60, 0.61, 0.68, 1)
	-- The grey just written over the reason line's tint, and the ring and the
	-- stripe may have changed shape: the next PaintAccent paints in full.
	accentPainted = nil

	if twoLine then
		nameText:SetPoint("TOPLEFT", textX, -8)
		nameText:SetPoint("RIGHT", -countRoom, 0)
		subText:SetPoint("BOTTOMLEFT", textX, 8)
		subText:SetPoint("RIGHT", -countRoom, 0)
		subText:Show()
	else
		nameText:SetPoint("LEFT", textX, 0)
		nameText:SetPoint("RIGHT", -countRoom, 0)
		subText:Hide()
	end

	countText:ClearAllPoints()
	countText:SetPoint("CENTER", countChip, "CENTER", 0, 0)
	-- The same number the chip was just sized from. Two expressions of one size
	-- is how they came apart in the first place.
	countText:SetFont(fontPath, countSize, outline)
	countText:SetTextColor(0.72, 0.73, 0.80, 1)

	-- Anchoring a row by both TOPLEFT and RIGHT fights over its vertical
	-- centre, so the rows get one anchor and an explicit width instead.
	--
	-- Which way the list hangs is settled here rather than on every repaint:
	-- the only three things that move the prompt -- a drag, a position preset,
	-- a profile switch -- all come back through ApplyStyle.
	queueAbove = QueueGoesAbove()
	-- Kept for PaintQueue, which re-places the rows when the list hangs above
	-- and therefore needs the same inset this loop uses.
	queueTextX = textX
	local rowHeight = p.fontSize + 4
	local rowCount = math.max(1, p.queueRows or 1)
	for i, fs in ipairs(queueRows) do
		fs:ClearAllPoints()
		if queueAbove then
			-- Counted down from the top of the block rather than up from the
			-- panel: row one nearest the panel would put the list in reverse
			-- reading order, which is a list you have to think about.
			fs:SetPoint("BOTTOMLEFT", art, "TOPLEFT", textX, 4 + (rowCount - i) * rowHeight)
		else
			fs:SetPoint("TOPLEFT", art, "BOTTOMLEFT", textX, -4 - (i - 1) * rowHeight)
		end
		fs:SetWidth(math.max(20, p.width - textX - 8))
		fs:SetFont(fontPath, math.max(7, p.fontSize - 3), outline)
		-- A little brighter than it was. These rows sit on their own background
		-- now instead of on the world, so they no longer have to be dim enough
		-- to survive a bright one.
		fs:SetTextColor(0.62, 0.63, 0.70, 1)

		-- Anchored to its own row, so the bar follows the list whichever way it
		-- hangs and whatever the font size is.
		local bar = queueBars[i]
		bar:ClearAllPoints()
		bar:SetSize(3, math.max(6, p.fontSize - 2))
		bar:SetPoint("RIGHT", fs, "LEFT", -4, 0)
	end

	-- The background behind the list: left and right edges only. How deep it
	-- goes is not known until the queue is painted, because it depends on how
	-- many rows have somebody in them rather than on how many were asked for.
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
	-- A shade darker than the panel and slightly more transparent, so the list
	-- reads as belonging to the prompt without competing with it. The hairline
	-- is the same bevel trick used along the top of the panel itself: one pixel
	-- of light is what stops two stacked rectangles reading as one.
	queueBack:SetVertexColor(br * 0.55, bg * 0.55, bb * 0.66, math.min(1, ba * 0.9))
	queueHair:SetVertexColor(1, 1, 1, 0.07)

	self:Refresh()
end

function Prompt:PaintAccent(reason)
	local p = ns.db.profile.prompt
	local mode = p.accentMode or "icon"
	local r, g, b = self:AccentColor(reason)

	-- This runs on every scan -- every repaint of a person, and every pass of
	-- a fight -- and the colour almost never changes between two of them. So
	-- the colour last painted is kept, and the same one again is nothing to
	-- do: two and a half repaints a second of a dozen textures, each gradient
	-- making two colour objects, was work the eye could not see. Forgotten by
	-- anything else that writes over these textures: ApplyStyle, and a
	-- refusal's red ring.
	local key = ("%s:%.3f:%.3f:%.3f:%s"):format(mode, r, g, b, tostring(tintSub))
	if key == accentPainted then return end
	accentPainted = key

	-- Brightest at the middle, fading towards both ends.
	Gradient(accentTop, "VERTICAL", r, g, b, 1, r, g, b, 0.15)
	Gradient(accentBottom, "VERTICAL", r, g, b, 0.15, r, g, b, 1)
	sweep:SetVertexColor(r, g, b, 1)
	PaintHalo(glowHalo, r, g, b, 1)

	if mode == "icon" or mode == "both" then
		-- Lit from above like everything else on the panel: a little brighter
		-- at the top of the ring than at the bottom, which is what makes it
		-- read as a rim rather than a flat square of colour.
		Gradient(iconBack, "VERTICAL", r * 0.78, g * 0.78, b * 0.78, 0.95,
			math.min(1, r * 1.12), math.min(1, g * 1.12), math.min(1, b * 1.12), 0.95)
	else
		iconBack:SetVertexColor(0, 0, 0, 0.85)
	end

	-- The reason line, warmed a little towards the same colour, so the two
	-- things that say why somebody is on the prompt agree at a glance. Mostly
	-- the grey it always was: it is the second line, and it must not compete
	-- with the name. Not where the player asked for no accent, and not on a
	-- light panel, where the tint costs the grey its contrast.
	local mix = (tintSub and mode ~= "off") and 0.35 or 0
	subText:SetTextColor(0.60 + (r - 0.60) * mix, 0.61 + (g - 0.61) * mix,
		0.68 + (b - 0.68) * mix, 1)
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------

local function ClassColored(entry, text)
	if not ns.db.profile.prompt.classColor or not entry.class then return text end
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
	if not c or not c.colorStr then return text end
	return string.format("|c%s%s|r", c.colorStr, text)
end

-- Core's, and the comment on it says why every substitution below goes through
-- a function replacement rather than a string one. Taken as a local because
-- this runs two and a half times a second on every line of the panel.
local Swap = ns.Swap

local function Substitute(template, entry, extra)
	local out = template or ""
	out = Swap(out, "{name}", entry.short or entry.name or "?")
	out = Swap(out, "{count}", tostring(extra or 0))
	out = Swap(out, "{class}", entry.class)
	out = Swap(out, "{buff}", entry.buff and ns.BuffName(entry.buff) or "")
	-- Empty for everybody who is simply missing the buff: only a top-up has a
	-- timer to quote, and the queue sets `remaining` for nobody else.
	out = Swap(out, "{time}", RemainingText(entry.remaining))
	return out
end

function Prompt:ReasonText(entry)
	local p = ns.db.profile.prompt
	local template = p[REASON_KEY[entry.reason] or "reasonNearby"] or ""
	-- The sub-line is what somebody reads without hovering, so it has to be the
	-- true one. In refresh mode the person on the prompt is holding the buff,
	-- and "needs {buff}" says the opposite of the countdown the tooltip prints
	-- underneath it. A top-up is a different offer and gets its own wording --
	-- swapped in whole, not suffixed, because the four reason lines belong to
	-- the user and may say anything at all by the time this runs.
	--
	-- The two swaps cannot both apply: a top-up is read off an aura we did read
	-- and were given a timer for, so `known` is true and the unverified branch
	-- is unreachable for it. Written as one chain anyway, so a later change to
	-- either condition cannot end up applying both.
	--
	-- The owed exclusion used to be belt and braces over a case that could not
	-- happen: a debt's aura state was fabricated as false before it ever got
	-- here, so `known` was never nil for one. Now that the queue reports what
	-- the client actually said, an unreadable debt arrives here for real -- and
	-- the exclusion is doing work. It stays because the reason somebody is on
	-- the prompt is the favour they did, and that is the line worth reading;
	-- the tooltip still says the aura could not be read.
	if RemainingText(entry.remaining) then
		template = p.reasonRefresh or template
	elseif entry.checked and entry.known == nil and entry.reason ~= "owed" then
		template = p.reasonUnknown or template
	end
	return Substitute(template, entry, 0)
end

function Prompt:RenderPrimary(entry, extra)
	local p = ns.db.profile.prompt
	local template = p.format or "{name}"
	local out = Substitute(template, entry, extra)
	if template:find("{name}", 1, true) then
		-- The name is escaped on the way into the pattern, and the colour
		-- wrapper goes in through a function for the same reason as everything
		-- else here: what is being handed to gsub is text, not a template.
		local plainName = entry.short or entry.name or "?"
		local coloured = ClassColored(entry, plainName)
		out = (out:gsub(plainName:gsub("(%W)", "%%%1"), function() return coloured end, 1))
	end
	-- The one that was live. A reason line is free text somebody typed, and it
	-- was being handed to gsub as a replacement, where % is an escape: "10%
	-- left" in the top-up wording threw here on every repaint.
	return Swap(out, "{reason}", self:ReasonText(entry))
end

---------------------------------------------------------------------------
-- targeting
---------------------------------------------------------------------------

-- Whether the last candidate painted is still entitled to the panel.
--
-- Three things keep this from being a lie. It expires, so nothing can hold the
-- prompt indefinitely. It never holds off somebody strictly more deserving --
-- that test is in PickTop, because it needs the replacement. And it never
-- holds somebody who was deliberately retired: a block is either the retry
-- cooldown a click wrote or the refusal a right-press wrote, and in both cases
-- "they are gone" is the answer the user just asked for.
local function HoldStillStands(now)
	if not (heldEntry and heldAt) then return false end
	if now - heldAt >= HOLD_SECONDS then return false end
	return not ns.IsBlocked(heldEntry.name, heldEntry.buff and heldEntry.buff.key, now)
end

-- Whoever is offered should stay offered. Re-sorting every tick swapped the
-- target while the cursor was over it, so the tooltip described one person and
-- the button was aimed at another. The current pick wins ties.
--
-- That much only works while the current pick is still in the queue, and in a
-- crowd the reason the top changes is usually that it is not: somebody steps a
-- yard out of range, a nameplate is recycled, an aura read falls out of the
-- three-second cache. The loop below then finds nothing to keep, the panel
-- swaps to a stranger, and the scan after that swaps back -- at 2.5 Hz, with
-- the sound and the entrance animation following each swap.
--
-- So the last painted candidate is also held for a moment after leaving the
-- queue, against anything no better than itself.
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

	-- An empty queue is a different question and gets a different, shorter
	-- answer: the fuse in Refresh. Holding here as well would stack the two
	-- and leave a prompt up for over two seconds with nobody behind it.
	if not top then return nil end
	if not HoldStillStands(GetTime()) then return top end
	if top.name == heldEntry.name then return top end
	-- Lower number is better, so this is the strict improvement -- a favour
	-- owed arriving over a passer-by -- and it is never held off. Noticing that
	-- is the whole business of the prompt.
	if top.priority < heldEntry.priority then return top end
	return heldEntry
end

-- Buttons 2 to 5 get a type the secure handler does not recognise, so they
-- match nothing and do nothing. Without this the unsuffixed type/macrotext --
-- which must stay, being the form that provably works on this client -- act as
-- the fallback for every button, and a right-press to turn the camera over the
-- panel fired the buff with none of the bookkeeping.
local function SilenceOtherButtons()
	for index = 2, 5 do
		button:SetAttribute("type" .. index, "none")
	end
end

-- Which targeting command to write.
--
-- /targetexact matches the whole name, /target matches a prefix -- so
-- "/target Mort" will happily find Mortimer standing beside Mort and buff, and
-- speak at, the wrong player. On that alone /targetexact is the better command
-- and this returned it.
--
-- It is not used, and the reason is worth keeping. The name this addon writes
-- is assembled from UnitName's two returns, and what the second one means is
-- exactly what this client does differently from every other: a surname here,
-- a realm everywhere else, and undocumented here for a player from another
-- realm. /target tolerates a name that is slightly wrong, because a prefix
-- still finds them. /targetexact does not: a name one character out finds
-- nobody, casts nothing, and the addon appears broken on the only client
-- anybody has ever run it on.
--
-- So the prefix risk is accepted for now. It casts on the wrong person, which
-- is worse in kind but rarer, and the settle path already notices a cast that
-- landed on somebody other than the person offered. Switching this on wants
-- one live test of what the assembled name actually looks like -- caps
-- .targetExact is probed and reported by /manners debug for exactly that.
local function TargetCommand()
	return "/target"
end
-- Published so the options page can name the command the macro really uses
-- rather than a second, hand-maintained opinion about it.
ns.TargetCommand = TargetCommand

-- The shape of the macro for this person. One place, and deliberately a name
-- rather than a condition inside the builder, so a second strategy is a new
-- entry in STRATEGIES plus a line here instead of a branch threaded through
-- everything that assembles a line.
--
-- There is exactly one targeting strategy, and the absence of a second one is a
-- decision rather than an oversight. The obvious candidate is
-- /cast [@Playername,help,nodead] <Spell> for somebody in your group on a
-- non-Camelot client: a named conditional resolves for party and raid members
-- everywhere, and it would never touch the player's own target, so there would
-- be no /targetlasttarget and nothing to restore. It is not built, for three
-- reasons:
--
--   * It has to be right about something nobody who works on this addon can
--     test. Conditional targeting is believed to work on Classic Era, TBC and
--     Mists; every source says so and nobody has run it. Worse, the restriction
--     that rules it out on Camelot arrived in retail 12.0, so it may well fail
--     on retail Midnight too.
--   * Its failure mode is silent. A guarded clause that resolves to nothing
--     casts nothing and says nothing, so a user on an untested client would get
--     an addon that quietly never works and no symptom to report.
--   * It buys convenience only. Not taking the player's target is nicer; being
--     cast at all is the feature.
--
-- The targeting route below is the only way to buff an ungrouped stranger on any
-- client -- [@name] resolves only for group members, and [@nameplateN] resolves
-- nowhere -- and a stranger is the whole reason this addon exists. It also works
-- perfectly well for somebody in your group. So it ships everywhere.
local function StrategyFor(entry)
	if entry.buff and entry.buff.selfCast then return "selfcast" end
	return "target"
end

-- Each returns three things: the lines, whether a /targetlasttarget belongs on
-- the end, and a record of what the macro does.
--
-- That record is what the settle path judges a press by, several hundred
-- milliseconds later. Nothing over there reads the macro text back to work it
-- out, and nothing over there re-derives it from the queue entry, because by
-- then the queue has been rebuilt a dozen times. So a strategy added later
-- cannot mislead it by omission: filling the record in is part of being a
-- strategy.
--
--   targeted  the macro carries a targeting line of ours, aimed at this person
--   selfCast  the spell lands on the caster and reaches the party from there
--   aimedAt   the exact spelling that went onto the targeting line
local STRATEGIES = {}

-- No targeting line, and there is no version of this that has one: the spell
-- lands on you and reaches the party from there. Saying so in the record is what
-- lets the settle path judge the press at all -- that it was left to work this
-- out for itself is why a warrior could never once repay anybody.
STRATEGIES.selfcast = function(entry, spell)
	return { "/cast " .. spell }, false,
		{ targeted = false, selfCast = true, aimedAt = nil }
end

-- Target them, cast, and optionally hand the player's own target back.
--
-- One targeting line, carrying one spelling. Two lines offering both spellings,
-- and the fallback that replaced them, were both tried and both are gone: with
-- two, /targetlasttarget hands back whatever the first line found rather than
-- the player's target, and two players sharing a first name is all that takes.
-- The account is in Core, where the counting used to live.
STRATEGIES.target = function(entry, spell)
	-- targetName is the spelling, entry.name is the identity. They differ only
	-- for a cross-realm player off Camelot; the fallback is for the handful of
	-- made-up entries -- the preview, the phrase roller -- whose names have no
	-- realm in them either way.
	local who = entry.targetName or entry.name or ""
	-- No hand-back for somebody reached through the target token: they are
	-- already the player's target, /target on them changes nothing, and the
	-- last-target slot still holds whoever came before them -- a mob, as often
	-- as not -- which /targetlasttarget would then switch to. The unit is in
	-- the macro's key, so this is rebuilt the moment the target changes.
	--
	-- Except in a fight, where nothing is rebuilt at all: the macro armed at
	-- the pull is the one every press runs until it ends. The player tabs to
	-- the mob, presses, and a macro without the hand-back leaves them
	-- targeting the friend with the mob lost. So the macro armed for the
	-- fight keeps it -- a press with the friend still targeted then switches
	-- to whoever came before them, which is the smaller of the two losses.
	local restore = ns.db.profile.filters.restoreTarget == true
		and (entry.unit ~= "target" or Prompt.armedForFight == true)
	return {
		TargetCommand() .. " " .. who,
		"/cast " .. spell,
	}, restore,
		{ targeted = true, selfCast = false, aimedAt = who }
end

-- The cast half of the macro, in the order the client needs it. Handed back as
-- a list rather than a string so the room left for a spoken line can be measured
-- against what these actually take.
local function CastLines(entry)
	return STRATEGIES[StrategyFor(entry)](entry, ns.BuffName(entry.buff))
end

-- How many characters a spoken line has left, for this person with these
-- settings. One answer, asked by the cast path and by the options preview, so
-- the preview can no longer promise a line the cast would silently drop.
function ns.PhraseBudget(entry)
	local lines, restore = CastLines(entry)
	-- The newline the spoken line itself would add, and the restore that
	-- follows it with a newline of its own.
	local used = #table.concat(lines, "\n") + 1
	if restore then used = used + #"/targetlasttarget" + 1 end
	return ns.MACRO_LIMIT - used
end

-- What the button will do, said the way a person would say it.
--
-- The tooltip used to print the macro instead, under the heading "Will run:",
-- and that heading was not true. The spoken line is drawn at random out of the
-- phrase pool and was re-rolled on every repaint -- two and a half times a
-- second -- and then once more inside PreClick, so the line quoted was never
-- the line that went out. The roll is settled per candidate now (see phraseKey
-- in ApplyTarget) and this quotes the settled one.
--
-- A method rather than a local because Create's tooltip handler is written
-- above CastLines, and a local would not be in scope there.
function Prompt:ClickSummary(entry)
	local out = {}
	if not (entry and entry.buff) then return out end
	local spell = ns.BuffName(entry.buff)
	-- An entry with no name at all is rare, and it gets sentences of its own
	-- that say "them" rather than a bare "them" slotted into each one: the
	-- pronoun takes a different form in each position in plenty of languages.
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

	if entry.buff.selfCast then
		out[#out + 1] = L["Casts |cffffffff%s|r on you; it reaches your party from there."]
			:format(spell)
	else
		-- The spelling the targeting line will actually carry, rather than the
		-- name the person is filed under or the shortened one the panel shows.
		-- Those are the same string on Camelot and diverge for a cross-realm
		-- player anywhere else, and this sentence claims to describe the macro.
		local target = entry.targetName or entry.name or who
		out[#out + 1] = target
			and L["Targets |cffffffff%s|r, casts |cffffffff%s|r."]:format(target, spell)
			or L["Targets |cffffffffthem|r, casts |cffffffff%s|r."]:format(spell)
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

	if phraseText then
		-- Quoted without its slash command: which channel it goes to is a
		-- setting three lines away in the options, and what it says is the part
		-- worth reading before pressing anything.
		out[#out + 1] = L["Says: |cffffffff%s|r"]:format((phraseText:gsub("^/%S+%s*", "")))
	end
	return out
end

function Prompt:ApplyTarget(entry)
	if InCombatLockdown() then
		-- The attributes are frozen until the fight ends, so the macro on the
		-- button cannot follow an entry in here. Everything that is not secure
		-- can, and has to: `current` is what PostClick files its bookkeeping
		-- under, what the tooltip describes and what the pulse claims. Giving
		-- up above it made every disarm a no-op in combat -- /manners off,
		-- /manners unlock and leaving preview all arrive here with nil -- so
		-- the prompt went on naming somebody it had been told to forget, and a
		-- CLICK binding still reaches the handlers on a hidden button.
		--
		-- Only the clearing direction is taken. Pointing `current` at somebody
		-- new while the armed macro still names the last person swaps one lie
		-- for another, and the bookkeeping would then be filed under a name
		-- nothing was cast at.
		--
		-- appliedKey is left alone on purpose: it says what is on the button,
		-- and what is on the button did not change. The clear path below is
		-- unconditional, so the first pass after the fight disarms it for real.
		if not entry then current = nil end
		return
	end

	current = entry

	if not entry or not entry.buff or testMode then
		-- Unconditionally. This used to be guarded by `appliedKey ~= nil` as an
		-- optimisation, but PreClick sets appliedKey to nil immediately before
		-- calling here -- so the guard was always false on a click and the
		-- clear never ran. An emptied queue therefore left the previous
		-- person's macro armed, and clicking cast at them instead of nobody.
		for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
			"type", "macrotext", "spell", "unit",
			"type2", "type3", "type4", "type5" }) do
			button:SetAttribute(attribute, nil)
		end
		appliedKey = nil
		-- Nothing on the button, so nothing for a settle to be judged against.
		-- Left standing, it would describe the last person's macro to the next
		-- press that arrives from somewhere this path cannot see.
		armed = nil
		-- Same reasoning for the spoken line: there is no macro, so there is no
		-- line, and the tooltip must not still be quoting the last one.
		phraseKey, phraseText = nil, nil
		return
	end

	-- The console expands {unit}/{name}/{spell} against whoever is offered.
	-- Above the early return below, because the token a person is reached
	-- through can change while the macro that would go out does not.
	ns.lastTopEntry = entry
	ns.lastTopUnit = entry.unit

	-- Everything the macro is built out of. The same person, the same buff and
	-- the same reason produce the same macro, so rebuilding it two and a half
	-- times a second -- eight SetAttribute calls each time -- buys nothing.
	-- Every other input comes through InvalidateMacro: the restore setting, the
	-- speech options, /manners try. PreClick clears it outright, so a press
	-- always re-arms against a queue built in that moment.
	--
	-- It also settles the spoken line per candidate instead of re-rolling it on
	-- every tick, which is what makes the tooltip's "Will run:" worth reading.
	--
	-- The clear path above stays unconditional. That asymmetry is deliberate:
	-- guarding it was the 1.4.1 bug, because PreClick nils the key immediately
	-- before calling here, so the guard was always false on a click and an
	-- emptied queue left the last person's macro armed.
	--
	-- Everything the macro interpolates is in the key, the unit token included:
	-- a /manners try template can say {unit}, so the same person reached
	-- through a nameplate one tick and through party2 the next expands to a
	-- different macro, and the memo would have shown and armed the old one.
	-- And whether it is being armed for a fight, which decides the hand-back
	-- for your own target: see STRATEGIES.target.
	local key = table.concat({ entry.name, tostring(entry.unit), entry.buff.key,
		tostring(entry.reason), tostring(ns.tryMacro), tostring(Prompt.armedForFight) }, "\1")
	if key == appliedKey then return end

	-- /manners try: arbitrary macro text, expanded against the current
	-- candidate. Iterating on this client otherwise means one guess per
	-- /reload; this makes it one guess per click.
	if ns.tryMacro then
		local text, unfilled = ns.ExpandTokens(ns.tryMacro)
		if not text then
			-- A template that asks for a unit token this person has not got.
			-- Nothing goes on the button rather than a guess at one: the guess
			-- was "target", which casts at whoever you happen to have targeted.
			-- The key is still taken, and it carries the unit, so the first
			-- repaint that reaches them through a token arms it after all.
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
		-- Whatever this text does, none of it is a /target this addon wrote, so
		-- it is evidence about nobody's name. A template that casts nothing at
		-- all -- "/target {name}" on its own, which is exactly the shape you
		-- reach for while working out what resolves -- used to park a click
		-- that never settled and then blame the next spell cast by hand for it.
		armed = nil
		return
	end

	local lines, restore, record = CastLines(entry)

	-- Rolled once per candidate rather than once per repaint and again on the
	-- press. PickPhrase draws at random out of the pool, so asking it twice for
	-- the same person gives two different lines -- and PreClick clears
	-- appliedKey and comes straight back through here, so the line the tooltip
	-- quoted was reliably not the line that went out. Keyed on who, which buff
	-- and why, and not on the macro's own key: that one carries the unit token,
	-- which only /manners try reads -- and try returns above here. Keyed on the
	-- macro, the same person seen through a nameplate on one scan and under
	-- the cursor on the next was somebody new to the roll, and the line changed
	-- under a tooltip still quoting the last one.
	--
	-- Deliberately not cleared by PreClick, which sets appliedKey to nil
	-- directly; InvalidateMacro clears both, and that is the split that makes
	-- the quote honest while still following a change to the phrase pool.
	--
	-- Measured, not assumed. The budget used to be a constant 120 with a
	-- second, correct length check immediately below it -- two rules for one
	-- question, and the constant was the one the options preview quoted.
	--
	-- The room is not part of the identity, though, and it can change under a
	-- settled line: your own target's macro has no hand-back and leaves the
	-- line eighteen characters more than the same person's macro off a
	-- nameplate. A line rolled into that room and kept took the macro past
	-- the client's limit, which cuts off the last line -- the hand-back. So a
	-- kept line is measured again, and rolled afresh only when it no longer
	-- fits.
	local phraseIdentity = table.concat({ entry.name, entry.buff.key, tostring(entry.reason),
		tostring(ns.tryMacro) }, "\1")
	local budget = ns.PhraseBudget(entry)
	if phraseKey ~= phraseIdentity or (phraseText and #phraseText > budget) then
		phraseKey, phraseText = phraseIdentity, ns.PickPhrase(entry, budget)
	end
	local phrase = phraseText
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
	-- Taken whole from the strategy that built the macro, rather than assembled
	-- here out of what the entry says and what the text looks like. selfCast
	-- used to be read back off the buff and `targeted` off whether a line had
	-- been added, which is two opinions about one macro -- and the try path
	-- writes no record at all, because whatever that text does, none of it is
	-- ours.
	armed = record
end

function Prompt:InvalidateMacro()
	appliedKey = nil
	-- The phrase pool, the channel and the speech toggle all invalidate through
	-- here, so the settled roll goes with the macro it belonged to. PreClick
	-- does not come through here -- it clears appliedKey on its own -- and that
	-- asymmetry is the point: a press re-resolves who is being buffed without
	-- re-rolling what is said, which is what makes the tooltip's quote true.
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
	-- The options page labels its button from InTest, and AceConfig only asks
	-- while it is drawing. Every way a preview ends comes through here -- the
	-- slash command, the page's own button, the clock, somebody real -- so
	-- this is the one place the open page can be told its button now reads
	-- "Preview" again. Does nothing with the window shut.
	if ns.RepaintOptions then ns.RepaintOptions() end
end

-- Read by the options page, which used to offer a button labelled "Preview"
-- whether that would start one or stop one.
function Prompt:InTest()
	return testMode == true
end

function Prompt:ToggleTest()
	if testMode then
		self:ExitTest()
		self:Refresh()
		return
	end
	-- Time-limited on purpose. A preview that stays until you remember to turn
	-- it off looks exactly like a working prompt while ignoring every real
	-- buff, which is a silent failure with no clue attached.
	--
	-- The limit does not run while the options window is open, which is the one
	-- place the preview is of any use -- see Refresh. So the number quoted here
	-- is what is left after the window is shut, and the line says that rather
	-- than starting a countdown the user will watch expire mid-slider.
	--
	-- Not in a fight, for the reason the greeting gives. A panel the fight
	-- found hidden cannot be put up, so the mock-up was painted on a frame
	-- nobody could see while chat said "preview on" and, twenty seconds
	-- later, "timed out". And a panel armed at somebody real keeps that macro
	-- -- the fight froze it -- so the preview painted "PREVIEW" over a button
	-- that still cast at them. Stopping one is above this and still works.
	if InCombatLockdown() then
		ns.addon:Print(L["|cffff8080not during a fight|r -- the preview can be shown once it ends."])
		return
	end
	-- Refresh stands a mock-up aside the moment somebody real is waiting, and
	-- says so. "Preview on" printed after that described a preview that was no
	-- longer running, and "/manners test to stop" invited a second toggle that
	-- did exactly the same thing again. The options window holds a preview up
	-- over a real person, which is where one is any use.
	--
	-- Asked before the preview is started rather than after, the way the
	-- greeting asks: started first, Refresh took it down again with "preview
	-- off -- somebody real turned up", and this then said the same thing a
	-- second time in other words, about a preview that never appeared. The
	-- test is Refresh's own, word for word, so the two cannot disagree about
	-- whether a preview would survive its first pass.
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
-- Every ingredient for this already existed -- the parked click, the cast
-- event with its recipient, the error event -- and all of it was thrown away
-- unless the debug flag was on. So the one question anybody has after pressing
-- the button ("did that work?") had no answer anywhere on screen, on a client
-- that also refuses to show most auras.
--
-- Three states, and they are not interchangeable. The settle path in Core is
-- careful about the difference between a cast the client attributed to the
-- person we aimed at and one it would not attribute at all, and a tick over
-- the second would be the panel claiming exactly what that care exists to
-- avoid claiming.
---------------------------------------------------------------------------

-- The motion that goes with an outcome, once, as it arrives. A buff the game
-- confirmed gets the ring popping outward and a band of light across the
-- panel; a refusal gets the text shaking its head. A cast nobody confirmed gets
-- neither, on purpose: the panel claims no more than the settle path does, and
-- a flourish is a claim.
--
-- Nothing at all where "Stay quiet in combat" has asked for a still panel in a
-- fight, or where "Calm" has asked for less movement; and nothing on a panel
-- that is not up, where it would play to nobody.
function Prompt:PlayOutcomeFlourish(kind)
	local p = ns.db and ns.db.profile.prompt
	if not p or not FullEffects() then return end
	if InCombatLockdown() and p.hideInCombat then return end
	if not button:IsShown() then return end
	self:StopFlourishes()
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
	-- The cross-fade the target swap already uses. The same gesture -- the text
	-- is about to say something different -- so it gets the same animation
	-- rather than a second one that could fight it.
	if textLayer.swap then
		textLayer.swap:Stop()
		textLayer.swap:Play()
	end
	-- And taken off on time, for the same reason. The scan used to be what
	-- noticed the outcome had run out, up to two seconds later, and all that
	-- while the name line went on reading "could not buff" somebody the button
	-- underneath had already moved on from.
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
	return false
end

-- Who the panel is naming as far as a press is concerned: the person an
-- outcome is about while it is written over the name line, and otherwise the
-- entry last painted. nil when it is naming nobody the queue could hold.
--
-- Read off what was painted, not off whether the outcome is still live. The
-- two used to be treated as one, and they are not: the outcome runs out on the
-- clock and its words stay until something repaints the panel. In that gap
-- this answered with the entry underneath, and a press made on a panel reading
-- "could not buff Anna" cast at whoever the refusal had armed after her.
function Prompt:PanelName()
	if outcomePainted then return outcomePainted end
	return heldEntry and heldEntry.name
end

-- A press that would have gone to somebody the panel is not naming. Nothing is
-- cast: the panel is brought up to date first -- the flash taken off and the
-- new person painted -- and then disarmed, so this press is empty and the next
-- one, made on a panel that says who it is for, casts at them.
function Prompt:MovedOn(top)
	outcomeKind, outcomeAt, outcomeName, outcomeDetail = nil, nil, nil, nil
	outcomePainted = nil
	if resultFill then resultFill:Hide() end
	ns.Guard("prompt moved on", Prompt.Refresh, self)
	self:ApplyTarget(nil)
	ns.addon:Print(L["the prompt has moved on to |cffffffff%s|r -- press again to buff them."]
		:format(tostring(top.short or top.name)))
end

-- Written over whatever Paint has already put on the panel. The outcome is
-- about the press that just happened, and by the time it lands the queue has
-- usually moved on to somebody else -- which is exactly why it has to be able
-- to overwrite rather than being folded into Paint.
function Prompt:PaintOutcome()
	-- No name is rare, and each headline has its own "them" sentence for it,
	-- for the same reason as in ClickSummary.
	local who = ns.ShortName and ns.ShortName(outcomeName) or outcomeName

	local r, g, b = self:AccentColor(current and current.reason or "owed")
	local lead, sub

	if outcomeKind == "failed" then
		-- Red, and the game's own words underneath. They are localised and are
		-- frequently the only thing that says *why* -- out of range, line of
		-- sight, not enough mana -- and until now none of it reached the user
		-- unless they had turned the click debugging on.
		r, g, b = 0.90, 0.26, 0.22
		lead = who and L["|cffff8080could not buff|r |cffffffff%s|r"]:format(who)
			or L["|cffff8080could not buff|r |cffffffffthem|r"]
		sub = outcomeDetail
	elseif outcomeKind == "sent" then
		-- Deliberately not a tick. Our spell went out, but what connects it to
		-- this person is an inference and not the client's word, and the settle
		-- path only infers the favour was repaid. The panel says the same thing
		-- at the same strength.
		--
		-- Which inference varies -- a /target of ours the client would not
		-- confirm, or a selfCast buff with no target at all -- so the settle
		-- sends the clause rather than this file guessing at it. The fallback
		-- is the commoner of the two, for a caller that sends none.
		lead = who and L["|cffe8e0a0sent to|r |cffffffff%s|r"]:format(who)
			or L["|cffe8e0a0sent to|r |cffffffffthem|r"]
		sub = outcomeDetail or L["cast -- this client will not confirm who to"]
	else
		lead = who and L["|cff8ce88cbuffed|r |cffffffff%s|r"]:format(who)
			or L["|cff8ce88cbuffed|r |cffffffffthem|r"]
		sub = L["the game confirmed it"]
	end

	-- Low alpha and the whole panel, rather than a badge somewhere on it: a
	-- wash of colour is read without being looked at, which is the point of it
	-- at half a second. Lighter for a refusal than it was: the red words and
	-- the red ring already say it, and a panel flooded red read as an alarm
	-- over what is usually somebody a step out of range. Lightest for a cast
	-- nobody confirmed, for the reason above.
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
	nameText:SetText(lead)
	outcomePainted = outcomeName
	if subText:IsShown() then subText:SetText(sub or "") end
	countChip:Hide()
	countText:SetText("")
end

-- Dim the whole panel for combat, or take the dim off. One writer, and it
-- remembers what it last did: Refresh runs on every scan and this would
-- otherwise re-set the alpha two and a half times a second for no change.
function Prompt:SetCombatHold(on)
	if combatHeld == on then return end
	combatHeld = on
	-- art, never the button: every visual in this file lives on art precisely
	-- so that combat -- which is when this runs -- cannot refuse it.
	RestArtAlpha()
	-- The sweep answers to the fight as well: see SyncCooldown.
	self:SyncCooldown()
end

-- What a branch says when it wanted the prompt gone and the fight would not let
-- it go. Four are in that position -- switched off, unlocked, nothing this
-- character can cast, and the held panel with nobody on it -- and all four have
-- the same two problems: a panel that cannot be taken down and nobody to put on
-- it. One sentence, then, with the reason the only part that differs.
--
-- Each caller hands over both whole sentences for its reason rather than the
-- reason alone. A bare "held" or "unlocked" gives a translator no idea it
-- names the panel, and the word has to agree with the rest of the sentence it
-- lands in, which only a whole sentence lets them see.
--
-- The name line has two shapes because the state genuinely has two. The
-- attributes were either emptied by the clear path before the fight started -- a
-- click that blocked the last candidate, much the commonest way in -- or frozen
-- by a disarm that arrived during it, which can clear the name and cannot clear
-- the macro. The first is inert; the second still casts on a press, which is
-- what PostClick warns about off this same attribute, so the panel and the
-- warning cannot come apart.
function Prompt:PaintHeldInert(whyFrozen, whyInert)
	local frozen = button:GetAttribute("macrotext1")
	nameText:SetText(frozen and "|cffff8080" .. L["still armed by the fight"] .. "|r"
		or "|cff909098" .. L["nothing to buff"] .. "|r")
	outcomePainted = nil
	if subText:IsShown() then
		subText:SetText(("|cffb0b0b0%s|r"):format(frozen and whyFrozen or whyInert))
	end
	-- Every other claim on the panel goes with the name: a count of a queue that
	-- is not being offered, and the wash of colour from a click that is over.
	countChip:Hide()
	countText:SetText("")
	resultFill:Hide()
	self:PaintAccent("nearby")
	-- The same statement the held panel makes, for the same reason: nothing here
	-- can be pointed at anybody until the fight ends.
	self:SetCombatHold(true)
end

-- The list of who is next, and the panel behind it. One place, because the
-- preview draws it too and a preview whose list has no background is a preview
-- of a prompt that does not exist.
function Prompt:PaintQueue(rows)
	local p = ns.db.profile.prompt
	local shown = 0
	for i, fs in ipairs(queueRows) do
		local row = rows and rows[i]
		if row then
			fs:SetText(row.text)
			-- Three pixels of the reason colour. Priority is the one thing
			-- about this list worth knowing at a glance, and reading four words
			-- of grey text to find it out is not a glance.
			local c = REASON_COLOR[row.reason or "nearby"] or REASON_COLOR.nearby
			queueBars[i]:SetVertexColor(c[1], c[2], c[3], 0.9)
			queueBars[i]:Show()
			shown = shown + 1
		else
			fs:SetText("")
			queueBars[i]:Hide()
		end
	end

	-- Sized to the rows that have somebody in them, not to the number the
	-- slider asks for: a background with two empty rows under it looks like the
	-- addon lost them.
	local back = shown > 0 and p.style ~= "minimal"
	if back then queueBack:SetHeight(6 + shown * (p.fontSize + 4)) end

	-- When the list hangs ABOVE the panel the rows have to be placed here and
	-- not in ApplyStyle, because where the top of the list falls depends on how
	-- many rows have somebody in them -- and that is only known now.
	--
	-- ApplyStyle counted down from a block sized by the slider, while the
	-- background above is sized to the rows actually filled, so with the slider
	-- at four and two people waiting the names floated two rows clear of the
	-- panel they belong to, over a background drawn somewhere else entirely.
	-- Hanging downward has no such problem: the first row starts at the panel's
	-- bottom edge and the rest follow, whatever the count.
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

	nameText:SetText(self:RenderPrimary(entry, extra))
	-- The name line is the entry's again, so a press follows the entry.
	outcomePainted = nil
	if subText:IsShown() then subText:SetText(self:ReasonText(entry)) end

	local showCount = p.showCount and extra > 0
	countChip:SetShown(showCount)
	countText:SetText(showCount and tostring(extra) or "")

	self:PaintAccent(entry.reason)

	if p.showIcon then
		local info = ns.BuffInfo(entry.buff)
		icon:SetTexture((info and info.icon) or 135932)
	end
end

-- The fade on the way out belongs to exactly one branch below -- the panel
-- showing a click's outcome over an empty queue, which is the panel about to
-- come down -- and every other outcome of a repaint has to cancel it, or a
-- person arriving in that half second would be painted onto a panel still
-- fading to nothing. So the branch asks for it by name and this wrapper stops
-- it for everybody else, rather than each of a dozen early returns having to
-- remember to.
--
-- Cancelled gently. How far the fade had got is taken before the repaint --
-- the combat branch sets the dim, and a fight must not read as a fade that
-- finished -- and the panel is brought back from there.
function Prompt:Refresh()
	if not button or not ns.db then return end
	self.outroWanted = nil
	local fadedTo = OutroAlpha()
	self:RefreshPanel()
	if not self.outroWanted then self:ComeBack(fadedTo) end
end

function Prompt:RefreshPanel()
	local db = ns.db.profile
	if not db then return end
	local p = db.prompt

	local now = GetTime()

	-- The dim goes on in the combat branch far below and used to come off on
	-- the one path that reaches past it. Every branch in between returns before
	-- it: preview, /manners off, an unlocked prompt, a client with nothing to
	-- cast. Preview is the one that never heals -- it stays alive for as long
	-- as the options window is open, so a preview started mid-fight sat at 0.55
	-- alpha for the whole of a styling session, long after the fight ended.
	--
	-- One writer per direction, and this one answers the only question that
	-- decides it. The dim means "the button cannot be pointed at anybody new",
	-- which is true exactly while the lockdown is -- so it is read here, above
	-- everything that returns, rather than at the far end of the function.
	if not InCombatLockdown() then self:SetCombatHold(false) end

	if not ns.caps.anyKnown and not testMode then
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		-- This can become true in the middle of a fight -- SPELLS_CHANGED lands
		-- whenever the client finally answers -- and the panel cannot come down
		-- for it any more than for anything else.
		if not SetPanelShown(false) then
			self:PaintHeldInert(
				L["nothing this character can cast -- a press still casts what the fight froze"],
				L["nothing this character can cast -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if testMode then
		-- Both of preview's exits used to fire while you were doing the one
		-- thing preview exists for. Twenty seconds is not long enough to work
		-- through a tab of sliders, and the "somebody real turned up" rule
		-- fires on the first pass anywhere there are people -- so the prompt
		-- could not be styled in a city at all, which is the place its size and
		-- position matter most.
		--
		-- While the options window is open the clock is pushed forward rather
		-- than read, so shutting the window starts a fresh twenty seconds and
		-- both exit rules apply from there. Nothing is disabled: a preview left
		-- running with the window shut still goes away on its own, which is the
		-- silent-failure the limit was put there to prevent.
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
		-- Preview is a disarm like the other two, and it was the only one that
		-- never healed. ToggleTest asks for it once, and a preview started in
		-- combat cannot have it: ApplyTarget can only clear `current` there,
		-- because the attributes are frozen. The disabled and unlocked branches
		-- below re-ask on every pass, so their first pass out of combat clears
		-- the macro for real -- this branch returned before reaching any of
		-- them, so the fight ended with a mock-up on screen and a real person's
		-- macro still armed under it, aimed at somebody `current` no longer
		-- even names.
		self:ApplyTarget(nil)
		-- A preview started in a fight paints onto whatever the fight left on
		-- screen: if the panel was down, this cannot put it up, and the mock-up
		-- is drawn on a hidden frame until the fight ends. Everything below is
		-- art and runs either way, which is what keeps the dim, the mock rows and
		-- the styling itself working the moment the panel is up at all.
		if not button:IsShown() and SetPanelShown(true) then
			if art.intro then art.intro:Play() end
		end
		self:Paint(TestEntry(), 2)
		self:StartAttention(false)
		-- Mock rows, with mock reasons: the reason bar is a thing being styled,
		-- so a preview that drew three grey ones would be previewing something
		-- the prompt never shows.
		local mock, reasons = {}, { "owed", "group", "nearby", "nearby", "nearby" }
		for i = 1, (p.showQueue and p.queueRows or 0) do
			mock[i] = { text = L["Someone %d"]:format(i), reason = reasons[i] }
		end
		self:PaintQueue(mock)
		return
	end

	-- Ahead of the unlocked branch, which used to return before this was ever
	-- read: an unlocked prompt that ignores /manners off is a button still
	-- sitting on screen after the user was told the addon is off.
	if not db.enabled then
		self:ApplyTarget(nil)
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		-- ApplyTarget above cleared the name and, in a fight, could not clear the
		-- macro under it. Saying so is the whole of what is left to do: the user
		-- was told the addon is off, and a panel still standing there naming the
		-- last candidate is the addon disagreeing with its own chat line.
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
			nameText:SetText("|cffffd100" .. L["Drag to move"] .. "|r")
			outcomePainted = nil
			if subText:IsShown() then subText:SetText("|cffff8080" .. L["not buffing while unlocked"] .. "|r") end
			countChip:Hide()
			countText:SetText("")
			resultFill:Hide()
			self:PaintAccent("owed")
		else
			-- "Drag to move" is an instruction, and in a fight it is one the
			-- client refuses as flatly as it refused the Show above it:
			-- OnDragStart gives up on lockdown too. So an unlocked prompt caught
			-- by a fight says what it is rather than inviting the one thing that
			-- cannot be done to it.
			self:PaintHeldInert(L["unlocked -- a press still casts what the fight froze"],
				L["unlocked -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if InCombatLockdown() then
		-- Attributes are frozen, so the list cannot be trusted, and the panel
		-- cannot be taken off the screen either: a fight that starts with it up
		-- keeps it up, and hideInCombat takes effect at the next scan after the
		-- fight ends. There used to be a `if p.hideInCombat or not current then
		-- button:Hide() end` here; this branch only ever runs in combat, so that
		-- call was refused every single time it was made, and it is deleted
		-- rather than guarded because a guard on it would be just as dead.
		--
		-- Nothing honest goes in its place. The button keeps its size, its place
		-- and its armed macro whatever the art does, so blanking the art would
		-- leave an invisible thing that still takes a click and still casts --
		-- worse than a visible panel saying it is held. A secure visibility
		-- driver would not change that: only the conditionals that name a unit,
		-- [@Name], are restricted on this client, and [combat] resolves -- but a
		-- button the driver hides still fires from its key binding and from
		-- /click, casting the frozen macro out of sight, which is the same
		-- invisible thing. So what is left is to say true things on art, which
		-- is the rest of this branch.

		-- The pulse is a claim that somebody is still owed. The debt can expire
		-- or be settled in the middle of a fight, and nothing else down here can
		-- notice, so the claim would outlive it until the fight ended.
		local debt = current and current.name and ns.owed[current.name]
		if not current or current.reason ~= "owed" or not debt or ns.DebtExpiry(debt) <= now then
			self:StopAttention()
		end

		-- Everything on the panel is frozen at whoever was on it when the fight
		-- started -- the macro cannot follow the queue, so neither may the name
		-- above it -- and it went on looking exactly as live as it does out of
		-- combat: full brightness, a list underneath still being rebuilt from a
		-- queue the button cannot be aimed at, and a tooltip describing a macro
		-- for somebody who may have walked off two minutes ago. The dim, the
		-- blanked list and the line are all one statement: this is held.
		self:SetCombatHold(true)
		HideQueue()
		-- Asked for rather than assumed: this runs from inside the scan timer,
		-- and a method the client does not have would take the whole tick with
		-- it -- which is what "the prompt stopped appearing" looks like.
		if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
		-- A click still works in combat -- the frozen macro is a real macro --
		-- so its outcome is still worth showing, and it wins over the held line.
		--
		-- Art, and nothing else. This used to call button:Show() first, which
		-- is a protected method on a protected frame: Blizzard refuses it for
		-- the length of the fight, and it was the one call that would have made
		-- the confirmation appear. Everything the flash is actually made of --
		-- the wash of colour, the headline, the sub-line -- lives on art, which
		-- stays ours in combat. A panel the fight found hidden stays hidden,
		-- and there is nothing honest to be done about that until it ends.
		if self:OutcomeLive() and not p.hideInCombat then
			self:PaintOutcome()
		else
			-- Repainted from `current`, not left where the flash put it.
			-- PaintOutcome writes the click's past-tense headline into the name
			-- line, and this branch only ever rewrote the sub-line underneath
			-- it -- so a click whose half-second outcome window ran out during
			-- a fight left "buffed <whoever you pressed>" as the panel's title
			-- for the rest of that fight, over a frozen macro armed at, and
			-- about to cast on, the next person in the queue.
			--
			-- The name line is the one thing that has to agree with the macro,
			-- and `current` is the macro's identity: in combat ApplyTarget can
			-- only clear it, never point it at somebody new.
			if current then
				nameText:SetText(self:RenderPrimary(current, 0))
				outcomePainted = nil
				-- The ring as well: a refusal turned it red, and the name
				-- line is not the only thing the flash wrote over.
				self:PaintAccent(current.reason)
				if subText:IsShown() then
					subText:SetText("|cffb0b0b0" .. L["held -- in combat"] .. "|r")
				end
				-- Nobody, rather than the number the fight started with. The
				-- count is a claim about a queue this branch has just blanked for
				-- being unaimable, so it goes with the list and the line rather
				-- than outliving both of them on its own -- and the panel then
				-- looks the same whether or not a flash has been over it.
				countChip:Hide()
				countText:SetText("")
			else
				-- And the commonest way into this branch at all, which had no
				-- repaint of any kind: a click blocks the person it was for, the
				-- queue empties, and the empty-queue branch disarms the button and
				-- clears `current` on its way past -- so a fight starting in the
				-- second after a click arrives here with nobody on the panel. The
				-- name line above is guarded on `current` and nothing was written
				-- for the other side of it, so the confirmation the click had just
				-- painted -- a green past-tense headline about somebody no longer
				-- anywhere near the queue -- stood as the panel's title for the
				-- whole fight, over a button holding no macro at all.
				self:PaintHeldInert(L["held -- a press still casts what the fight froze"],
					L["held -- nothing armed, and the panel cannot go"])
			end
		end
		return
	end

	-- Snoozed. Below the combat branch and not beside /manners off, which is
	-- what makes a snooze started in a fight wait for the end of it: in a
	-- fight the panel cannot be taken down, and one that stays up is left
	-- exactly as the fight found it -- its frozen macro still casts on a
	-- press, so blanking it would only hide that. The first pass after the
	-- fight arrives here and takes it down. The off branch above can paint
	-- over a frozen panel because /manners off says it has stopped offering
	-- anybody; a snooze says only that the prompt should be out of the way.
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

	local queue = ns.BuildQueue()
	local top = self:PickTop(queue, queue[1])

	if not top then
		-- An empty queue in a crowd is usually a gap rather than an answer: one
		-- person steps out of range for a single scan, or their aura read falls
		-- out of the cache. Hiding on that and showing again 0.4s later replays
		-- the entrance animation and the sound for a prompt that never went
		-- anywhere. So the first empty scan lights a short fuse, and a refill
		-- puts it out.
		--
		-- Nothing is disarmed and nothing is repainted while it burns: a prompt
		-- on screen has to name somebody and has to be clickable, and the
		-- person it already names is the last one it had.
		--
		-- Somebody deliberately retired gets no fuse at all. A block is either
		-- the cooldown a click wrote or the refusal a right-press wrote, and in
		-- both cases "they are gone" is the answer that was just asked for.
		local retired = Retired(current, now)

		if self:OutcomeLive() then
			-- The click is what empties the queue, so this is where the
			-- confirmation for it nearly always lands -- and hiding first is
			-- why there was never one to see. Disarmed, because there is nobody
			-- to arm against; PostClick files nothing for a press with no
			-- current entry, so the button is inert for the half second it
			-- stays up.
			self:ApplyTarget(nil)
			button:Show()
			self:StopAttention()
			HideQueue()
			self:PaintOutcome()
			lastTop = nil
			ClearHold()
			-- Nobody left and the confirmation running out: the panel is on
			-- its way down, so it fades over the second half of it instead of
			-- blinking out. The hide itself is still the one below, on the
			-- repaint the outcome's own timer asks for.
			if FullEffects() then
				self.outroWanted = true
				self:PlayOutro(outcomeAt)
			end
			return
		end

		if button:IsShown() and current and not retired then
			LightFuse(now)
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

	-- Who else is waiting, which of them goes in the list, and whether the pick
	-- is in the queue at all. One pass, and all three counted rather than read
	-- off the queue's order: the pick is not always queue[1] -- a tie is kept
	-- with the current candidate, and a held one may not be in the queue at all
	-- -- so `#queue - 1` undercounted by one and `queue[i + 1]` dropped the
	-- genuine top out of the list entirely.
	local rows, others, inQueue = {}, 0, false
	local wanted = (p.showQueue and p.queueRows) or 0
	for _, entry in ipairs(queue) do
		if entry.name == top.name then
			inQueue = true
		else
			others = others + 1
			if #rows < wanted then
				rows[#rows + 1] = {
					text = Substitute("{name}", entry, 0) .. "  |cff707078"
						.. self:ReasonText(entry) .. "|r",
					reason = entry.reason,
				}
			end
		end
	end

	local wasHidden = not button:IsShown()
	local isNew = top.name ~= lastTop
	-- The moment somebody becomes owed, which is not only the moment they
	-- arrive on the panel: a passer-by already offered who then buffs you
	-- stays the same name, and "Flash once" and the stripe's sweep -- both
	-- keyed on a new name -- let the one event they are named after go by.
	local becameOwed = top.reason == "owed" and (isNew or lastTopReason ~= "owed")
	lastTop = top.name
	lastTopReason = top.reason
	-- Narrower again: the favour was only just done. The light on arrival
	-- used to take becameOwed, and that is also true of the next person owed
	-- reaching the panel after every press and of somebody coming back after
	-- you targeted somebody else -- people who had been waiting all along.
	--
	-- So it is keyed on the favour, by the debt's own stamp: lit when the
	-- repaint that first sees a favour has its giver on top, and never after.
	-- A favour first seen while somebody else was on the panel has been seen,
	-- and its giver reaching the top later -- after your press on the first,
	-- usually -- is not news.
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

	-- Stamped where the panel is repainted rather than where the pick is made:
	-- PreClick picks too, and a press is not a paint. Renewed on every paint
	-- that came out of the queue, so somebody flickering in and out of a
	-- crowded one keeps the panel for as long as they keep coming back -- and
	-- pointedly not renewed by a paint the hold itself produced, because a hold
	-- that renews itself is somebody who walked away an hour ago still owning
	-- the prompt.
	if inQueue or not heldEntry then heldAt = now end
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

	-- A floor under the sound as well as under the name. They are the same
	-- churn -- the sound fires on the name changing -- but not the same
	-- annoyance: a panel swapping a name is something you can look away from,
	-- and a sound is not.
	--
	-- And the same filter the flash below uses. The two are one job -- getting
	-- you to look -- and they disagreed about who is worth it: the pulse fired
	-- for a favour owed and nothing else, while the sound went off for every
	-- stranger who walked within range of a nameplate.
	if isNew and db.sound.enabled
		and (not db.sound.owedOnly or top.reason == "owed")
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

	-- Last, over the top of all of it. The outcome belongs to the press that
	-- just happened, and by now the panel has usually moved on to the next
	-- person -- so it overwrites rather than being folded into Paint.
	if self:OutcomeLive() then
		self:PaintOutcome()
	else
		resultFill:Hide()
	end
end

-- Says, on the panel itself, that the pause is the game's and not the addon's.
-- Written to the sub-line only: the name stays, because the person is still
-- the one being offered and replacing their name with a countdown would read
-- as having lost them.
function Prompt:SayWaiting(left)
	if not button or not subText then return end
	if InCombatLockdown() then return end
	-- The colour rides in the string rather than on the font string. Set on the
	-- font string it stayed there -- Paint only ever sets text, and only
	-- ApplyStyle sets the colour -- so one press inside the cooldown left the
	-- reason line in this lighter grey for the rest of the session.
	-- Rounded up: "ready in 0.0s" over a press that was just refused for not
	-- being ready reads as the addon contradicting itself.
	ns.Guard("waiting line", function()
		subText:SetText("|cffb8b8c7" .. L["ready in %.1fs"]:format(
			math.max(0.1, math.ceil((left or 0) * 10) / 10)) .. "|r")
	end)
end

-- A drag still held when a fight starts is ended here, from
-- PLAYER_REGEN_DISABLED, which arrives just before the lockdown does. That is
-- the last moment the move can be stopped at all: the release comes in the
-- fight, where stopping a move on the secure button is refused, and the
-- position with it would never have been saved.
function Prompt:FinishDragForFight()
	if not dragging or not button or InCombatLockdown() then return end
	FinishDrag()
end

function Prompt:GetButton()
	return button
end

-- The pieces of the panel, handed out so they can be read back.
--
-- Everything on the prompt is a file local, which is the right shape for a
-- thing only this file ever writes to and the wrong shape for proving what it
-- wrote: a tick over a cast nobody confirmed, a queue row with no background
-- behind it and a panel that looks live while it is frozen are all failures
-- with no symptom except how they look. GetButton above is the same accessor
-- for the same reason.
function Prompt:Regions()
	return {
		art = art,
		name = nameText,
		sub = subText,
		count = countText,
		-- The box the count is drawn in, beside the number itself. The two are
		-- sized from the same font and there is nothing outside this file that
		-- can tell they have come apart: a chip smaller than its own digits
		-- draws perfectly, throws nothing, and reads as a smudge under a number
		-- lying across the name.
		chip = countChip,
		fill = resultFill,
		-- The four edges of the framed look. A look that applies nothing is
		-- indistinguishable from one that applies something, from the outside,
		-- which is how the dropdown came to offer a border the addon never drew.
		edges = edges,
		-- The two carriers of the reason colour. Both are switched off from
		-- somewhere other than the dropdown that asks for them -- the stripe by
		-- the framed look, the ring by hiding or rounding the icon -- and from
		-- outside, a prompt that shows the colour nowhere looks exactly like one
		-- that was never asked to.
		iconBack = iconBack,
		accentTop = accentTop,
		-- The two things "When someone buffs you" animates: the sweep down the
		-- stripe and the glow round the icon. Each is a frame carrying its own
		-- animation, and whether one played is the only evidence the setting
		-- does anything -- a flash style that plays nothing throws nothing.
		sweep = sweepFrame,
		glow = glowFrame,
		glowStrips = glowHalo and glowHalo.strips,
		glowRound = glowHalo and glowHalo.round,
		burstStrips = burstHalo and burstHalo.strips,
		burstRound = burstHalo and burstHalo.round,
		-- The effects added for the look: each is a frame or a group whose
		-- playing is the only evidence it ran, for the same reason as the two
		-- above. The cooldown is nil on a client without the template.
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
	}
end
