-- A WoW API stand-in, configurable through the global `Mock` so scenarios can
-- make the client behave badly on purpose: withhold values as secrets, remove
-- APIs entirely, put the player in combat or in the graveyard.

Mock = Mock or {}
Mock.now = 1000

-- Forever reports retail's project id -- it is a fork of Midnight, not a
-- project of its own -- so WOW_PROJECT_MAINLINE is what both of them answer.
-- Anything that tries to tell those two apart this way is wrong, and now
-- provably so.
--
-- Declared up here rather than beside the other API stand-ins because
-- Mock.setFlavour assigns one of them, and Mock.reset calls that before this
-- file has finished loading.
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
WOW_PROJECT_MISTS_CLASSIC = 19

-- The five live clients, and the things about each that no other knob can fake.
--
-- A scenario says which one it is standing in for with Mock.setFlavour("mists").
-- Every field is a real difference between the clients rather than a
-- convenience: the number GetBuildInfo reports, the project id sitting beside
-- it, whether COMBAT_LOG_EVENT_UNFILTERED may be registered, whether UnitName's
-- second return is a surname or a realm, whether UnitBuff still exists, and
-- whether a macro conditional naming a player resolves.
--
-- Camelot is the default, applied at the bottom of Mock.reset, because it is the
-- client every scenario written before this existed was implicitly about and the
-- only one anybody here can test. None of them may move.
local FLAVOURS = {
	camelot = {
		build = "1.60.1", interface = 16001, project = WOW_PROJECT_MAINLINE,
		combatLog = false, surnames = true, unitBuff = false,
		-- The assumption Core.lua states and this mirrors: Camelot keeps the
		-- /target route, which is the only shape ever verified in game here.
		conditionalTargeting = false,
	},
	mainline = {
		build = "12.1.5", interface = 120100, project = WOW_PROJECT_MAINLINE,
		combatLog = false, surnames = false, unitBuff = false,
		conditionalTargeting = true,
	},
	mists = {
		build = "5.5.0", interface = 50504, project = WOW_PROJECT_MISTS_CLASSIC,
		combatLog = true, surnames = false, unitBuff = true,
		conditionalTargeting = true,
	},
	tbc = {
		build = "2.5.6", interface = 20506,
		project = WOW_PROJECT_BURNING_CRUSADE_CLASSIC,
		combatLog = true, surnames = false, unitBuff = true,
		conditionalTargeting = true,
	},
	vanilla = {
		build = "1.15.9", interface = 11509, project = WOW_PROJECT_CLASSIC,
		combatLog = true, surnames = false, unitBuff = true,
		conditionalTargeting = true,
	},
}
Mock.FLAVOURS = FLAVOURS

-- UnitBuff and UnitAura, which retail and Forever removed and the three Classic
-- flavours still have.
--
-- Nothing in this addon may call either of them: C_UnitAuras is on all five
-- clients, so a fallback to these would be a second scanner that only ever runs
-- where it is not needed and rots where it does. The only way to prove it is not
-- called is to put a working one where the addon could reach it and count the
-- times it did -- an absent function proves nothing, because not calling a
-- function that is not there is not a choice.
local function mockUnitBuff(unit, index)
	Mock.counts.unitBuff = Mock.counts.unitBuff + 1
	local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	local aura = byIndex and byIndex(unit, index)
	if type(aura) ~= "table" then return nil end
	-- Near enough to the shape Classic returns that a fallback built on it would
	-- appear to work, which is what makes the count worth taking.
	return "Arcane Intellect", 135932, 1, nil, 3600, aura.expirationTime,
		aura.sourceUnit, false, false, aura.spellId
end

-- Become one of the five. Every knob it sets remains a knob: a scenario that
-- wants a client which is one flavour in all respects but one says so
-- afterwards, and a scenario that never calls this is a Camelot client exactly
-- as it always was.
function Mock.setFlavour(name)
	local client = FLAVOURS[name]
	if not client then
		error("Mock.setFlavour: no such client: " .. tostring(name), 2)
	end
	Mock.flavour = name
	Mock.build = client.build
	Mock.interface = client.interface
	Mock.combatLog = client.combatLog
	Mock.surnames = client.surnames
	Mock.conditionalTargeting = client.conditionalTargeting
	WOW_PROJECT_ID = client.project
	_G.UnitBuff = client.unitBuff and mockUnitBuff or nil
	_G.UnitAura = client.unitBuff and mockUnitBuff or nil
end

function Mock.reset()
	Mock.class = "MAGE"
	Mock.dead = false
	Mock.inCombat = false
	Mock.allSecret = false
	Mock.stripped = false
	Mock.unitName = { "Petra", "Stonewell" }
	-- Per-token overrides, e.g. { focus = { "Iris", "Quill" } }. Every unit the
	-- scan walks answered with the same name until this existed, so `seen`
	-- collapsed them all into one person and no scenario could tell a token
	-- IterateUnits really visits from one it does not.
	Mock.unitNames = nil
	Mock.nameplates = { "nameplate1", "nameplate2" }
	Mock.now = 1000
	Mock.groupSize = 0
	Mock.held = nil
	Mock.heldFor = nil
	-- Who cast what Mock.held says a unit is carrying, per spell id, as the unit
	-- token the aura names -- e.g. { [20217] = "nameplate2" } for another
	-- paladin's Kings. Absent is the client naming nobody, which is also what
	-- every scenario written before this knob gets.
	Mock.heldSource = nil
	-- Spell ids whose auras the client declares secret, e.g. { [23028] = true }:
	-- one id refused while the rest of the buff stays readable, rather than
	-- Mock.allSecret taking everything with it.
	Mock.secretAuraIds = nil
	-- Spell ids the aura read itself refuses, and how: { [23028] = "throw" } or
	-- { [23028] = "secret" }. A refusal at the moment of reading, where
	-- secretAuraIds is one the probe was told about in advance.
	Mock.auraReadRefuse = nil
	Mock.auraBlackout = false
	Mock.noAuras = false
	Mock.extraAura = false
	-- What the extra aura is, beyond its instance id. Separate knobs because
	-- the addon is not allowed to identify an aura by its number alone: the
	-- client recycles numbers, so a scenario has to be able to hand the same
	-- number to a different spell, or to the same spell as a later cast.
	Mock.extraAuraSpell = nil   -- defaults to the same 1459 the rest carry
	Mock.extraAuraUntil = nil   -- defaults to the same 2000 the rest carry
	-- The unit token the extra aura names as its caster. `nil` is the client
	-- naming nobody, which is a stranger with no nameplate -- unidentifiable,
	-- and a hard limit rather than an oversight.
	Mock.extraAuraSource = "nameplate1"
	Mock.auraIdBase = 0
	-- How many auras the player is carrying, in slots 1..n. Two is what every
	-- scenario written before this knob assumed, so that is the default.
	Mock.auraCount = 2
	-- Slot indices the client refuses individually, e.g. { [4] = true }, which
	-- is a refusal with readable auras still behind it rather than a blackout.
	Mock.auraHidden = nil
	-- The shape a refusal arrives in. Nothing in the addon may depend on which
	-- one a scenario picks: "secret" is a value you are not allowed to look at,
	-- "nil" is silence indistinguishable from an empty slot. Both are the
	-- client refusing, no evidence says which this client uses, and a suite that
	-- only ever models one of them agrees with the code by construction.
	Mock.refuseWith = "secret"
	-- C_UnitAuras present, and the one function inside it the whole favour
	-- source is built on missing. The scan gives up, silently, for good -- the
	-- failure the aura line in /manners debug exists to name.
	Mock.noAuraScanner = false
	-- Whether this client lets an addon register the combat log. False is
	-- Forever and retail 12.0+, where RegisterEvent throws outright rather than
	-- accepting the registration and never firing -- the difference matters,
	-- because trying it is how the capability probe finds out. True models the
	-- three Classic flavours, which still have it.
	--
	-- Set by Mock.setFlavour along with everything else that differs between the
	-- clients, and still settable on its own: "a Mists client that refuses the
	-- log anyway" is a real bug report and has to be expressible.
	Mock.combatLog = false
	-- The line CombatLogGetCurrentEventInfo is to hand back next, as a table of
	-- the fields this addon reads. nil is the default below, which is a priest
	-- called Petra casting Fortitude on you -- the shape every assertion about
	-- the log is written against.
	--
	-- A scenario sets this to be a different line: a debuff, somebody else's
	-- buff, a proc, your own cast, an NPC. The payload is the addon's only
	-- evidence about any of them, so a mock that can only produce one line can
	-- only test the case that was already working.
	Mock.cleu = nil
	-- Players the client can name from a GUID alone, guid -> { class, name,
	-- realm }. This is the whole of what the combat log source has over the aura
	-- scan, so it has to be possible for a scenario to be a client that cannot
	-- answer -- an unknown GUID gets nothing back, exactly as the real call does
	-- for an NPC, a pet or a totem.
	Mock.guids = nil
	-- Every event the addon asked the Ace object to register, so a scenario can
	-- assert an event was never asked for rather than only that nothing threw.
	Mock.registeredEvents = {}
	-- Whether a player from another realm is standing in front of us.
	--
	-- Only meaningful off Camelot, where UnitName's second return is the realm
	-- and the client gives it for a player from another one and for nobody else.
	-- Same-realm is the ordinary case, so it is the default: a mock that handed
	-- back a realm for everybody would make "Mort-Ravencrest" the normal spelling
	-- and hide every bug in the same-realm path, which is nearly every player.
	--
	-- Ignored where the second return is a surname, because there every player
	-- has one.
	Mock.crossRealm = false
	-- Who is in the player's party or raid, by name, e.g. { Petra = true }.
	--
	-- A macro conditional naming a player resolves for group members and for
	-- nobody else, on every one of the five clients, so this is what decides
	-- whether [@Petra,help] finds anybody. Empty by default: the person this
	-- addon exists for is a stranger.
	Mock.groupNames = nil
	-- What C_Secrets.HasSecretRestrictions answers. Separate from the namespace
	-- existing, because those are different questions: C_Secrets is present on
	-- clients where nothing is being withheld at the moment, and an addon that
	-- reads the table's presence as "I am being kept out of things" is asking
	-- the wrong one.
	Mock.secretRestrictions = true
	-- A raid, as { size = 40, player = 1 }: how many are in it and which raid
	-- index is the player. nil is not being in one, which is what every
	-- scenario written before this assumed. Five to a subgroup in index order,
	-- unless `subgroups` says otherwise by index.
	--
	-- Modelled because the difference between the raid and your party within
	-- it is the whole of what a shout reaches. UnitInRaid answers with an index
	-- for every member of the raid; UnitInParty and UnitInSubgroup answer only
	-- for your own subgroup. A mock with one idea of "the group" made a warrior
	-- in a forty-man raid look exactly like one in a party of five.
	Mock.raid = nil
	-- Spell ids IsSpellInRange has nothing to say about, e.g. { [6673] = true },
	-- asked by id or by the name the id resolves to. A shout is cast on
	-- yourself and has no range to anybody, and the client answers nil for it;
	-- the mock answering 1 for every spell is what hid a warrior being offered
	-- people sixty yards away.
	Mock.rangeless = nil
	Mock.inRange = true
	-- How far away everybody is, and the exceptions by unit token. Five yards
	-- is close enough for every proximity setting, so a scenario that says
	-- nothing about distance is a scenario where nobody is dropped for it --
	-- which is how every scenario written before this behaved.
	Mock.yardsDefault = 5
	Mock.yards = nil
	-- Whether CheckInteractDistance answers about a stranger. Guarded because
	-- Mock.setInteract is declared further down this file, beside the function
	-- it switches, and reset runs once while the file is still loading.
	if Mock.setInteract then Mock.setInteract("on") end
	-- LibRangeCheck, which the user may simply not have: nil is a client with
	-- no such library, and a table is one that does.
	--
	--   { buckets = { 30, 28, 8 } }   the checker ranges this class and client
	--                                 happen to have, largest first
	--   { buckets = ..., throws = true }
	--                                 the library is there and its estimate
	--                                 blows up -- the shape a secret unit GUID
	--                                 takes on this client, where the library
	--                                 builds a cache key by concatenating one
	--   { buckets = ..., silentFor = { nameplate2 = true } }
	--                                 the estimate comes back empty for those
	--                                 units and works for the rest
	--   { partial = true }            loaded, but not the methods we need
	--
	-- An edge equal to the duel or follow prompt is answered through
	-- CheckInteractDistance, as the real library answers it; see LibStub.
	Mock.rangeCheck = nil
	Mock.unitClass = "PRIEST"
	-- The player's race, by the file name UnitRace hands back second. It moves
	-- the duel prompt: six yards for a tauren, seven for the undead, eight for
	-- everybody else. Human is what every scenario written before this assumed.
	Mock.playerRace = "Human"
	Mock.iconDb = nil
	-- The launcher's data object, once SetupOptions has made one. Everything
	-- the addon puts on a broker display -- its text, its click handler, its
	-- tooltip -- lives on this table and nowhere else, so without a handle on
	-- it none of that was reachable from a test.
	Mock.broker = nil
	Mock.sounds = {}
	Mock.printed = {}
	-- Every line the tooltip put up since it was last owned. The tooltip is the
	-- most detailed thing the prompt says and none of it was testable.
	Mock.tooltip = {}
	-- Whether the options window is on screen, which is what decides whether
	-- the preview is allowed to time out. `true` is the standalone AceConfig
	-- dialog. The other route in, the game's own Settings window, is
	-- Mock.openSettings and Mock.closeSettings below.
	Mock.optionsOpen = false
	-- Whether the game's Settings window is up, and the canvas AddToBlizOptions
	-- made for Manners inside it. Kept apart because the client keeps them
	-- apart: shutting the window hides the window, and the canvas keeps its own
	-- shown flag until another page replaces it.
	Mock.settingsPanelShown = false
	Mock.blizCanvas = nil
	-- The category ID AddToBlizOptions hands back as its second value, which is
	-- the only thing Settings.OpenToCategory can find the page by.
	Mock.blizCategoryID = 17
	-- How many times the options page has been asked to redraw itself.
	Mock.optionsRepaints = 0
	-- The screen, and where on it the prompt is sitting. The queue list flips
	-- to the other side of the panel when the prompt is low enough that the
	-- rows would hang off the bottom edge.
	Mock.screenHeight = 1000
	Mock.promptCentreY = 500
	-- Off by default, so everything written against the hand-set centre above
	-- goes on reading it. See GetCenter.
	Mock.geometry = nil
	-- The wall clock. GetTime() is the machine's uptime, so it starts again
	-- near zero after a reboot and the epoch does not, which is the whole
	-- difficulty with storing a debt.
	Mock.epoch = 1700000000
	-- Stands in for the SavedVariables file: handed to every AceDB the mock
	-- builds, so two successive load()s share it the way two sessions share a
	-- file on disk. Cleared here so one scenario's debts cannot leak into the
	-- next; a scenario that models a reload simply does not reset in between.
	Mock.sv = {}
	-- Who is logged in, as far as the saved file is concerned. Only a key:
	-- nothing else in the mock reads it. It exists so a scenario can log an alt
	-- in on the same account, which is the only way to tell a thing stored per
	-- character from a thing stored in the one shared profile.
	Mock.character = "Mort Defrette"
	Mock.dbCallbacks = {}
	-- Everything parked on C_Timer.After and not yet run. Cleared here so one
	-- scenario's timers cannot fire inside the next one.
	Mock.timers = {}
	-- How often the addon actually asked the client something. Caching and
	-- deduplication are invisible to every other kind of assertion.
	Mock.counts = { range = 0, auraRead = 0, unitBuff = 0, interact = 0, proximity = 0 }
	-- Every protected method the addon called on a frame a scenario marked
	-- secure while the fight was on. In the game each of these is a refusal
	-- nothing reports; here they are a list.
	Mock.protectedCalls = {}
	-- Spell ids this client has never heard of, e.g. { [462854] = true }. A
	-- name that will not resolve is the only evidence an addon has that its own
	-- data is wrong for the client it is running on, and four of the five
	-- clients cannot be tested by anybody here -- so the mock has to be able to
	-- be a client that does not have a spell. nil is every id resolving, which
	-- is what every scenario written before this assumed.
	Mock.unknownSpells = nil
	-- Libraries LibStub is to behave as though the user does not have, keyed by
	-- name. One of ours is fetched with the silent flag precisely because it may
	-- be absent, and until this existed every scenario ran with all of them
	-- present -- so the absence the flag is there for was never once modelled,
	-- and the readers that forgot to check could not be told from the ones that
	-- remembered.
	Mock.missingLibs = nil
	-- A cast with a cast time the player is part-way through, as
	-- { spellId, startsAt, endsAt } on the GetTime() clock. nil is standing
	-- still, which is what every scenario written before this assumed. The
	-- global cooldown was the only lockout the mock knew, so a press made
	-- half-way through a three-second conjure could not be told from a free one.
	Mock.casting = nil
	-- What C_Spell.GetSpellCooldown reports for a spell, by id. A number is a
	-- duration starting at the moment of asking, which is all the addon read
	-- when this was written. A table is the whole reading -- startTime,
	-- duration, isActive, isOnGCD -- which is what the global cooldown (61304)
	-- needs, since how much of it is left depends on when it started, and what
	-- a spell off the global cooldown needs to say so. nil is the function
	-- answering nothing, which leaves the addon on its own one-and-a-half-second
	-- fallback exactly as before this existed.
	Mock.spellCooldowns = nil

	-- Last, because it writes several of the knobs above. Camelot is what every
	-- scenario written before this existed assumed, so resetting to it is what
	-- keeps all of them behaving exactly as they did.
	Mock.setFlavour("camelot")
end
Mock.reset()

-- "There is genuinely nothing here", said in a table whose absent fields mean
-- "leave the default alone". Without it a scenario cannot ask for a combat log
-- line with no source GUID, which is one of the shapes the addon has to survive.
Mock.NONE = setmetatable({}, { __tostring = function() return "<none>" end })

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
-- Exposed so a scenario can withhold one value rather than all of them. Turning
-- Mock.allSecret on to hide a single answer hides UnitExists with it, and the
-- unit is then rejected before the code under test is ever reached.
Mock.SECRET = SECRET

-- A secret value is returned in place of the real one; the addon is expected
-- to route everything it branches on through its own plain() first.
local function maybeSecret(value)
	if Mock.allSecret then return SECRET end
	return value
end

-- The client declining to answer, in whichever shape the scenario asked for.
-- A withheld value and a plain nil are the same refusal wearing different
-- clothes, and the addon is not allowed to tell them apart -- a plain nil is
-- also exactly what an empty slot looks like, which is the whole difficulty.
local function refuseAura()
	if Mock.refuseWith == "nil" then return nil end
	return SECRET
end

local frameMethods = {
	"SetSize", "SetPoint", "ClearAllPoints", "SetAllPoints", "Show", "Hide",
	"SetScale", "SetAlpha", "SetMovable", "SetClampedToScreen", "RegisterForDrag",
	"SetWidth", "SetHeight", "SetTexture", "SetVertexColor", "SetColorTexture",
	"SetTexCoord", "SetBlendMode", "SetFont", "SetText", "SetTextColor",
	"SetJustifyH", "SetWordWrap", "SetShadowColor", "SetShadowOffset", "SetShown",
	"SetFromAlpha", "SetToAlpha", "SetDuration", "SetOrder", "SetSmoothing",
	"SetOffset", "SetLooping", "Play", "Stop", "SetBackdrop",
	"SetBackdropBorderColor", "UnregisterEvent", "SetFrameStrata",
	"SetHighlightTexture", "EnableMouse", "StartMoving", "StopMovingOrSizing",
	"SetGradient", "AddMaskTexture", "SetAtlas", "SetUserPlaced",
	"RegisterForClicks", "SetGradientAlpha",
}

local KNOWN_EVENTS = {}
for _, e in ipairs({
	"COMBAT_LOG_EVENT_UNFILTERED", "UNIT_AURA", "PLAYER_ENTERING_WORLD",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED",
	"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_DEAD",
	"PLAYER_ALIVE", "PLAYER_UNGHOST", "UNIT_SPELLCAST_SENT",
	"UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UI_ERROR_MESSAGE",
	"GROUP_ROSTER_UPDATE", "ADDON_LOADED",
}) do KNOWN_EVENTS[e] = true end
Mock.KNOWN_EVENTS = KNOWN_EVENTS
Mock.badEvents = {}

-- The methods Blizzard refuses on a protected frame while the player is in
-- combat. Nothing about a refused call is visible from Lua -- it does not
-- throw, it does not return anything, the frame simply does not change -- so a
-- mock that performs them all regardless is a client that never locks down, and
-- the addon's rule for combat (paint art, never touch the button) cannot be
-- tested against it at all.
--
-- The call is still performed, and also written down. Recording rather than
-- refusing leaves every scenario written before this behaving exactly as it
-- did; what is new is that a scenario can ask what the addon tried to do to a
-- secure frame while the lockdown was on. SetAlpha is deliberately absent: it
-- is allowed in combat, which is the whole reason the panel dims instead of
-- hiding.
local PROTECTED_METHODS = {
	"Show", "Hide", "SetShown", "SetAttribute", "SetPoint", "ClearAllPoints",
	"SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale", "SetParent",
	"EnableMouse", "SetFrameStrata", "RegisterForClicks",
	-- Moving the frame is as protected as placing it: OnDragStop used to end a
	-- move on the secure button in combat, and against a mock that did not
	-- write these down it looked exactly like a drag that behaved.
	"StartMoving", "StopMovingOrSizing",
}

-- Which frame is the secure one is the addon's business, not the mock's, so a
-- scenario says: Mock.protect(ns.Prompt:GetButton()).
function Mock.protect(frame)
	frame._protected = true
	return frame
end

-- Where on the screen a frame anchored to UIParent sits, in UIParent's units:
-- left, bottom, right, top. Only answered with Mock.geometry set. The client's
-- rules, as far as the prompt needs them: the anchor's offsets are in the
-- frame's own scaled units, so they are multiplied by its scale, and a frame
-- clamped to the screen is pushed back inside it whole.
local function fraction(anchor)
	local fx, fy = 0.5, 0.5
	if anchor:find("LEFT", 1, true) then fx = 0 elseif anchor:find("RIGHT", 1, true) then fx = 1 end
	if anchor:find("BOTTOM", 1, true) then fy = 0 elseif anchor:find("TOP", 1, true) then fy = 1 end
	return fx, fy
end

function Mock.rectUI(frame)
	local g = Mock.geometry
	local anchor = frame.points[1]
	local s = frame._scale or 1
	local w, h = (frame._width or 0) * s, (frame._height or 0) * s
	local rx, ry = fraction(anchor[3] or anchor[1])
	local px, py = fraction(anchor[1])
	local left = rx * g.width + (anchor[4] or 0) * s - px * w
	local bottom = ry * g.height + (anchor[5] or 0) * s - py * h
	if frame._clamped then
		left = math.max(0, math.min(left, g.width - w))
		bottom = math.max(0, math.min(bottom, g.height - h))
	end
	return left, bottom, left + w, bottom + h
end

local function newFrame()
	local f = { scripts = {}, attributes = {}, points = {} }
	for _, name in ipairs(frameMethods) do f[name] = function(self) return self end end

	-- Recorded rather than dropped, and defined after the loop above so they
	-- replace the no-ops in it. Several guarantees here are about what ends up
	-- on the panel -- a tick over an unconfirmed cast, a queue row with no
	-- background, a prompt that looks live while it is frozen -- and against a
	-- no-op setter the only thing a scenario can prove is that nothing threw.
	f.SetText = function(self, text) self._text = text return self end
	f.GetText = function(self) return self._text end
	f.SetAlpha = function(self, alpha) self._alpha = alpha return self end
	f.GetAlpha = function(self) return self._alpha or 1 end
	f.SetVertexColor = function(self, r, g, b, a) self._color = { r, g, b, a } return self end
	-- The text colour too. A line recoloured for one message and never put back
	-- reads the same to every assertion as one that was, against a no-op.
	f.SetTextColor = function(self, r, g, b, a) self._textColor = { r, g, b, a } return self end
	-- Size and font, for the same reason the colour above is kept. Several
	-- pieces of the panel are sized from the font slider and have to stay in
	-- step with the text inside them; against a no-op setter, a box drawn
	-- smaller than its own digits is indistinguishable from one drawn right.
	f.SetSize = function(self, w, h) self._width, self._height = w, h return self end
	f.SetWidth = function(self, w) self._width = w return self end
	f.SetHeight = function(self, h) self._height = h return self end
	f.SetFont = function(self, path, size, flags)
		self._font = { path = path, size = size, flags = flags }
		return self
	end
	f.SetShown = function(self, shown) self._shown = shown and true or false return self end
	-- Kept as the raw argument list: SetPoint is called with three arguments in
	-- some places and five in others, and which anchor a queue row hangs from
	-- is the whole of what the flip test reads.
	f.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } return self end
	f.ClearAllPoints = function(self) self.points = {} return self end
	-- The scale too, because the client reads a frame's SetPoint offsets in the
	-- frame's own scaled units. A no-op here made every scale the same scale,
	-- and a prompt placed at twice the distance it was asked for looked right.
	f.SetScale = function(self, s) self._scale = s return self end
	f.GetScale = function(self) return self._scale or 1 end
	-- Every frame here hangs straight off UIParent, whose own scale is 1, so a
	-- frame's effective scale is its own.
	f.GetEffectiveScale = function(self) return self._scale or 1 end
	f.SetClampedToScreen = function(self, clamped) self._clamped = clamped and true or false return self end
	-- Two ways to answer where a frame is. By default, a centre the scenario
	-- sets by hand in the frame's own units, as it always was. With
	-- Mock.geometry set to a screen ({ width =, height = }), the answer is
	-- worked out from the frame's anchor, size, scale and clamping the way
	-- the client does, so a scenario can ask where a prompt actually landed.
	f.GetCenter = function(self)
		if Mock.geometry and self.points[1] and type(self.points[1][2]) == "table" then
			local left, bottom, right, top = Mock.rectUI(self)
			local s = self._scale or 1
			return (left + right) / 2 / s, (bottom + top) / 2 / s
		end
		return 400, Mock.promptCentreY
	end
	f.GetHeight = function(self)
		if Mock.geometry and self == UIParent then return Mock.geometry.height end
		return Mock.screenHeight
	end

	f.SetScript = function(self, which, fn) self.scripts[which] = fn return self end
	f.GetScript = function(self, which) return self.scripts[which] end
	-- Runs after whatever script is already there, as the client's does.
	f.HookScript = function(self, which, fn)
		local prior = self.scripts[which]
		self.scripts[which] = prior and function(...) prior(...) return fn(...) end or fn
		return self
	end
	f.SetAttribute = function(self, k, v) self.attributes[k] = v return self end
	f.GetAttribute = function(self, k) return self.attributes[k] end
	f.IsShown = function(self) return self._shown ~= false end
	f.Show = function(self) self._shown = true return self end
	f.Hide = function(self) self._shown = false return self end
	f.IsPlaying = function() return false end
	f.IsOwned = function() return false end
	-- With a screen modelled, the anchor the frame was last given, which is
	-- what the client hands back after a drag: offsets in the frame's own
	-- scaled units. A scenario models the drag by writing the anchor the
	-- client would have left behind.
	f.GetPoint = function(self)
		if Mock.geometry and self.points[1] then return table.unpack(self.points[1], 1, 5) end
		return "CENTER", nil, "CENTER", 0, 0
	end
	f.GetHighlightTexture = function() return newFrame() end
	f.CreateTexture = function() return newFrame() end
	f.CreateFontString = function() return newFrame() end
	f.CreateAnimationGroup = function() return newFrame() end
	f.CreateAnimation = function() return newFrame() end
	f.CreateMaskTexture = function() return newFrame() end
	f.RegisterEvent = function(self, event)
		if not KNOWN_EVENTS[event] then Mock.badEvents[#Mock.badEvents + 1] = event end
		-- Forever and retail 12.0+ refuse the combat log by throwing here,
		-- rather than by accepting the registration and staying quiet. Modelled
		-- because the capability probe's whole method is to try it and see: a
		-- mock that accepts it answers "the log is available" for the one
		-- client this addon is actually verified on.
		if event == "COMBAT_LOG_EVENT_UNFILTERED" and not Mock.combatLog then
			error("COMBAT_LOG_EVENT_UNFILTERED is not available to addons", 0)
		end
	end
	f.UnregisterEvent = function() end

	-- Last, so it wraps whatever the two loops above left behind rather than
	-- being overwritten by them.
	for _, name in ipairs(PROTECTED_METHODS) do
		local inner = f[name]
		f[name] = function(self, ...)
			if Mock.inCombat and self._protected then
				Mock.protectedCalls[#Mock.protectedCalls + 1] = name
			end
			return inner(self, ...)
		end
	end
	return f
end
Mock.newFrame = newFrame

UIParent = newFrame()
GameTooltip = newFrame()
-- Recorded so a scenario can read what the tooltip said, and cleared by
-- SetOwner the way the real one is -- otherwise a second hover reads back the
-- first one's lines and every assertion about the tooltip is about history.
GameTooltip.AddLine = function(_, text)
	Mock.tooltip[#Mock.tooltip + 1] = tostring(text)
end
GameTooltip.AddDoubleLine = function(_, left, right)
	Mock.tooltip[#Mock.tooltip + 1] = tostring(left) .. "\t" .. tostring(right)
end
GameTooltip.SetOwner = function() Mock.tooltip = {} end
GameTooltip.IsOwned = function() return false end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

function CreateFrame() return newFrame() end
function GameTooltip_Hide() end

local libs = {}
local function getLibrary(name, silent)
	-- Ahead of the cache, so a scenario can withhold a library an earlier one
	-- already built. The real LibStub throws for a library that is not there
	-- unless the caller passes the silent flag, and that difference is the whole
	-- contract: a caller who passed it has promised to cope with nil.
	if Mock.missingLibs and Mock.missingLibs[name] then
		if silent then return nil end
		error("Cannot find a library instance of " .. tostring(name) .. ".", 2)
	end

	-- Ahead of the cache as well, and not cached itself, because what this
	-- library is differs per scenario: absent, present and working, present and
	-- throwing, present with the methods we want missing. A library built once
	-- and kept would be whichever of those the first scenario asked for.
	--
	-- Absent is the default and it is modelled the way the real LibStub models
	-- it -- nil to a caller who passed the silent flag -- rather than by the
	-- empty table every other unknown name gets here. An empty table is not
	-- what a missing library looks like, and a reader that tested the table
	-- rather than the method would pass against one.
	if name == "LibRangeCheck-3.0" then
		local want = Mock.rangeCheck
		if not want then
			if silent then return nil end
			error("Cannot find a library instance of " .. tostring(name) .. ".", 2)
		end
		local rc = { initialized = false }
		rc.init = function(self) self.initialized = true end
		if want.partial then return rc end

		local buckets = want.buckets or { 30, 28, 8 }
		-- The checker list, largest first, kept where the library keeps it and
		-- labelled the way it labels it. The two edges the library fills from
		-- the interact prompts -- the duel prompt and follow -- ask
		-- CheckInteractDistance exactly as it does, `and true or false`, so a
		-- client that refuses a stranger reads as "outside" and a value it
		-- withholds reads as "inside". Everything else stands in for a spell
		-- that answers. This mock used to measure every edge straight off
		-- Mock.yardsFor, which made the library immune to Mock.interact and hid
		-- the one way it gets a stranger wrong.
		local interact = Mock.interactYards and Mock.interactYards() or {}
		local list = {}
		for i, range in ipairs(buckets) do
			local index = (range == interact[3] and 3) or (range == interact[4] and 4) or nil
			local entry = { range = range }
			if index then
				entry.info = "interact:" .. index
				entry.checker = function(unit)
					local check = _G.CheckInteractDistance
					return (check and check(unit, index)) and true or false
				end
			else
				entry.info = "spell:0:mock"
				entry.checker = function(unit) return Mock.yardsFor(unit) <= range end
			end
			list[i] = entry
		end
		rc.friendRC = list
		-- The tightest checker at or under what was asked for, which is what
		-- decides the distance the addon really ends up filtering on.
		rc.GetFriendMaxChecker = function(_, range)
			for _, entry in ipairs(list) do
				if entry.range <= range then return entry.checker, entry.range end
			end
		end
		-- The library's own search over that list: the number of checkers that
		-- say yes decides which pair of edges comes back, and one that says
		-- nothing counts as a no.
		rc.GetRange = function(_, unit)
			Mock.counts.proximity = Mock.counts.proximity + 1
			if want.throws then
				error("attempt to concatenate a secret value", 0)
			end
			if want.silentFor and want.silentFor[unit] then return nil end
			local lo, hi = 1, #list
			while lo <= hi do
				local mid = math.floor((lo + hi) / 2)
				if list[mid].checker(unit) then lo = mid + 1 else hi = mid - 1 end
			end
			if #list == 0 then return nil end
			if lo > #list then return 0, list[#list].range end
			if lo <= 1 then return list[1].range, nil end
			return list[lo].range, list[lo - 1].range
		end
		return rc
	end

	if libs[name] then return libs[name] end
	local lib = {}
	if name == "AceAddon-3.0" then
		lib.NewAddon = function(_, addonName)
			local a = {}
			a.RegisterEvent = function(self, event)
				if not KNOWN_EVENTS[event] then
					error("registered unknown event: " .. tostring(event), 0)
				end
				-- The same refusal the frame's RegisterEvent models, on the
				-- other route into it. One of the two accepting the combat log
				-- would let the addon come to depend on it by the back door.
				if event == "COMBAT_LOG_EVENT_UNFILTERED" and not Mock.combatLog then
					error("COMBAT_LOG_EVENT_UNFILTERED is not available to addons", 0)
				end
				-- Written down, so "this event was never asked for" can be told
				-- from "it was asked for and the client refused". Those are the
				-- same silence from outside, and only one of them is the addon's
				-- doing.
				Mock.registeredEvents[event] = true
			end
			a.UnregisterEvent = function() end
			a.RegisterChatCommand = function() end
			-- Several guarantees are about what the addon says, not what it
			-- does: a prompt with nobody on it has to be told apart from a
			-- keybinding that never worked.
			a.Print = function(_, ...)
				local parts = {}
				for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
				Mock.printed[#Mock.printed + 1] = table.concat(parts, " ")
			end
			a.ScheduleRepeatingTimer = function() return {} end
			a.CancelTimer = function() end
			a.ScheduleTimer = function() return {} end
			return a
		end
	elseif name == "AceDB-3.0" then
		lib.New = function(_, _, defaults)
			local function deepcopy(t)
				local out = {}
				for k, v in pairs(t) do out[k] = type(v) == "table" and deepcopy(v) or v end
				return out
			end
			-- One profile for the whole account, kept in the saved file.
			--
			-- Not a simplification of AceDB but a copy of what this addon asks
			-- it for: OnInitialize passes `true` as the third argument, which
			-- is the library's "every character starts on the profile named
			-- Default". And backed by Mock.sv, because without that a setting
			-- kept in the profile and a setting kept per character behave
			-- identically across a reload -- so the difference between them,
			-- which this addon has now had to decide twice, was untestable.
			Mock.sv.profile = Mock.sv.profile or deepcopy(defaults.profile)

			-- AceDB's per-character section, created on first access and kept
			-- in the same one file. Keyed by who is logged in, so an alt is a
			-- different table out of the same file -- and Mock.sv.char stays
			-- pointed at whoever that is, which is what every scenario written
			-- before alts existed reads.
			Mock.sv.chars = Mock.sv.chars or {}
			-- A scenario that wrote Mock.sv.char before the first load is
			-- describing the file this character left behind last session, so
			-- it is adopted as theirs. Only before the first load: after that
			-- the field is a pointer and adopting it would hand an alt the
			-- previous character's file.
			if next(Mock.sv.chars) == nil and type(Mock.sv.char) == "table" then
				Mock.sv.chars[Mock.character] = Mock.sv.char
			end
			Mock.sv.chars[Mock.character] = Mock.sv.chars[Mock.character] or {}
			Mock.sv.char = Mock.sv.chars[Mock.character]

			local db = { profile = Mock.sv.profile, char = Mock.sv.char }
			-- Recorded rather than dropped: OnDatabaseShutdown is the only hook
			-- the logout flush hangs on, and a scenario has to be able to fire
			-- it the way the real library does.
			db.RegisterCallback = function(target, event, method)
				Mock.dbCallbacks[event] = { target = target, method = method }
			end

			-- AceDB's SetProfile, reduced to what it does to the tables: the
			-- profile being left has every value equal to its default stripped
			-- -- compared against the very table handed to New, and a sub-table
			-- emptied by that is dropped -- and the one arrived at is filled from
			-- that same defaults table. Both walks are the library's own. A
			-- profile that shares a table with the defaults instead of copying
			-- it has that table stripped against itself, which empties the
			-- default for the rest of the session; a scenario that only swaps
			-- sub-tables by hand can never see that.
			local function removeDefaults(tbl, defs)
				for k, v in pairs(defs) do
					if type(v) == "table" and type(tbl[k]) == "table" then
						removeDefaults(tbl[k], v)
						if next(tbl[k]) == nil then tbl[k] = nil end
					elseif tbl[k] == defs[k] then
						tbl[k] = nil
					end
				end
			end
			local function copyDefaults(dest, src)
				for k, v in pairs(src) do
					if type(v) == "table" then
						if rawget(dest, k) == nil then rawset(dest, k, {}) end
						if type(dest[k]) == "table" then copyDefaults(dest[k], v) end
					elseif rawget(dest, k) == nil then
						rawset(dest, k, v)
					end
				end
			end
			Mock.sv.profiles = Mock.sv.profiles or {}
			db.SetProfile = function(self, name)
				local current = Mock.sv.profileName or "Default"
				if name == current then return end
				removeDefaults(self.profile, defaults.profile)
				Mock.sv.profiles[current] = self.profile
				local arrived = Mock.sv.profiles[name] or {}
				copyDefaults(arrived, defaults.profile)
				Mock.sv.profiles[name] = arrived
				Mock.sv.profileName = name
				Mock.sv.profile = arrived
				self.profile = arrived
				local changed = Mock.dbCallbacks["OnProfileChanged"]
				if changed then
					changed.target[changed.method](changed.target, "OnProfileChanged", self, name)
				end
			end
			return db
		end
	elseif name == "AceConfig-3.0" then lib.RegisterOptionsTable = function() end
	elseif name == "AceConfigDialog-3.0" then
		lib.AddToBlizOptions = function()
			local f = newFrame()
			-- The Blizzard panel starts shut. Every other mock frame answers
			-- "shown" by default, and one that did so here would make the
			-- preview immortal for a reason that has nothing to do with the
			-- rule being tested.
			f._shown = false
			-- Two answers, as the client gives them. IsShown is the canvas's
			-- own flag, which the Settings window sets when it shows the page
			-- and only clears when another page takes its place -- so it stays
			-- set after the window is shut. IsVisible is the one that also
			-- asks the window.
			f.IsShown = function(self) return self._shown == true end
			f.IsVisible = function(self) return self._shown == true and Mock.settingsPanelShown == true end
			-- A plain frame's ID, which nobody sets on this one: it is not the
			-- category's.
			f.GetID = function() return 0 end
			Mock.blizCanvas = f
			-- The library returns the frame and the category ID, in that order.
			return f, Mock.blizCategoryID
		end
		lib.Open = function() end
		-- The real library keeps the frames it has open in here, keyed by addon
		-- name, and that table is how the addon asks whether somebody is
		-- looking at the options right now.
		lib.OpenFrames = setmetatable({}, { __index = function(_, key)
			if key == "Manners" and Mock.optionsOpen == true then return {} end
			return nil
		end })
	elseif name == "AceConfigRegistry-3.0" then
		-- What the page calls to make an already-open window redraw itself.
		-- Counted rather than ignored: three things on that page are answers to
		-- questions with a current answer -- are we in combat, what has broken,
		-- is the report box open -- and AceConfig only asks them while it is
		-- drawing, so the call is the whole of the guarantee.
		lib.NotifyChange = function()
			Mock.optionsRepaints = (Mock.optionsRepaints or 0) + 1
		end
	elseif name == "AceDBOptions-3.0" then
		lib.GetOptionsTable = function() return { type = "group", name = "p", args = {} } end
	elseif name == "LibSharedMedia-3.0" then
		-- Real enough to tell a registered sound from a missing one. The
		-- shipped library has exactly one sound, "None", whose value is the
		-- number 1, so the mock starts where a bare client does.
		lib.media = { sound = { None = 1 }, font = { ["font.ttf"] = "font.ttf" } }
		lib.defaults = { sound = "None", font = "font.ttf" }
		lib.Register = function(self, kind, key, data)
			self.media[kind] = self.media[kind] or {}
			self.media[kind][key] = data
			return true
		end
		lib.IsValid = function(self, kind, key) return (self.media[kind] or {})[key] ~= nil end
		lib.Fetch = function(self, kind, key, noDefault)
			local t = self.media[kind] or {}
			-- The fallback is the trap, not a convenience: a key whose addon
			-- is gone resolves to the type's default, and for sound that is
			-- "None" -- the number 1, which plays nothing.
			return t[key] or (not noDefault and t[self.defaults[kind]]) or nil
		end
		lib.HashTable = function(self, kind) return self.media[kind] or {} end
	elseif name == "LibDataBroker-1.1" then
		-- The real library keeps the table it is handed and hands that same
		-- table back, with a metatable that files every field away and fires a
		-- callback at each display when one is assigned. Only the first half is
		-- modelled -- what a display does with the callback is not this addon's
		-- code -- but the first half is the half that was missing: returning a
		-- fresh empty table threw the addon's own object away, so the text, the
		-- click handler and the tooltip all went into a table nothing could
		-- reach, and a launcher that says which state it is in was
		-- indistinguishable from one that says nothing at all.
		lib.NewDataObject = function(_, _, obj)
			Mock.broker = obj
			return obj
		end
	elseif name == "LibDBIcon-1.0" then
		-- Records which table the button is bound to. The real library keeps
		-- the one it was handed and never re-reads it, which is the whole bug.
		lib.Register = function(_, _, _, db) Mock.iconDb = db end
		lib.Refresh = function(_, _, db) if db then Mock.iconDb = db end end
		lib.IsRegistered = function() return true end
		lib.Show = function() end
		lib.Hide = function() end
	end
	libs[name] = lib
	return lib
end

-- LibStub in the shape the real one has: a table, made callable by a __call
-- metamethod, with GetLibrary as a method on it. This was a plain function, and
-- the difference is not cosmetic -- type(LibStub) is "table" in the game and
-- "function" was all this mock ever showed. Core.lua fetched LibRangeCheck
-- through a helper that refuses anything that is not a function, so in the game
-- the library was never once consulted while every scenario here consulted it.
LibStub = setmetatable({ libs = libs, minors = {}, minor = 2 }, {
	__call = function(_, name, silent) return getLibrary(name, silent) end,
})
function LibStub:GetLibrary(name, silent) return getLibrary(name, silent) end
function LibStub:IterateLibraries() return pairs(libs) end

function issecretvalue(v) return v == SECRET end
function InCombatLockdown() return Mock.inCombat end
-- A frozen clock silently broke several scenarios: PostClick puts a candidate
-- into the retry cooldown, and with time standing still that cooldown never
-- expires, so every later BuildQueue came back empty and the assertions that
-- depended on it skipped while reporting green.
function GetTime() return Mock.now end
-- Seconds since the epoch, which is what SavedVariables have to be written in:
-- it is the only clock that means the same thing after a reload.
function time() return Mock.epoch end
function Mock.advance(seconds)
	Mock.now = Mock.now + seconds
	Mock.epoch = Mock.epoch + seconds
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function date() return "12:00:00" end

-- Who has a second return at all, which is the whole of the difference between
-- the clients here.
--
-- The value itself gives nothing away: a surname and a realm are both plain
-- strings and neither says which it is. What differs is who gets one. Every
-- Camelot player has a surname; off Camelot the realm is handed over only for a
-- player from another one, and everybody else's second return is empty. A mock
-- that always answered both would make the cross-realm spelling the normal one
-- and hide every bug in the path nearly every player takes.
local function secondName(second)
	if Mock.surnames or Mock.crossRealm then return second end
	return nil
end

function UnitName(u)
	if u == "player" then return "Mort", secondName("Defrette") end
	local named = Mock.unitNames and Mock.unitNames[u]
	if named then return maybeSecret(named[1]), maybeSecret(secondName(named[2])) end
	return maybeSecret(Mock.unitName[1]), maybeSecret(secondName(Mock.unitName[2]))
end
function GetUnitName() return "Petra Stonewell" end
function UnitClass(u)
	if u == "player" then return "Mage", Mock.class end
	return "Priest", maybeSecret(Mock.unitClass)
end
-- The player's race, as the display name and the file name the client keys its
-- tables on. Only the player's is modelled: the interact prompts measure from
-- the player, and it is the player's race that moves them.
local RACE_NAMES = { Scourge = "Undead" }
function UnitRace(u)
	if u ~= "player" then return nil end
	local race = Mock.playerRace or "Human"
	return RACE_NAMES[race] or race, race, 1
end
function UnitGUID(u) return maybeSecret("Player-1-" .. tostring(u)) end
function UnitExists() return maybeSecret(true) end
function UnitIsPlayer() return maybeSecret(true) end
-- In a raid the player is one of the raid tokens as well, and the scan walks
-- all of them -- so "is raid1 me" has to come back yes for the right one, or the
-- player is offered their own buff.
local function canonicalUnit(u)
	if Mock.raid and u == "raid" .. tostring(Mock.raid.player or 1) then return "player" end
	return u
end
function UnitIsUnit(a, b) return canonicalUnit(a) == canonicalUnit(b) end
function UnitIsDeadOrGhost(u)
	if u == "player" then return Mock.dead end
	return maybeSecret(false)
end
function UnitCanAssist() return maybeSecret(true) end
function UnitIsConnected() return maybeSecret(true) end
function UnitIsCharmed() return false end
function UnitInVehicle() return false end
function UnitOnTaxi() return false end
function UnitLevel() return maybeSecret(12) end
-- Classes without a mana bar really do report zero, and the mock claiming
-- otherwise is what let a bug through that offered warriors nobody at all.
--
-- The four classes below the vanilla seven are the ones only the later flavours
-- have. A monk and an evoker have a mana bar; a death knight runs on runic power
-- and a demon hunter on fury, so both are absent here and really do report zero.
local MANA_CLASSES = {
	MAGE = true, PRIEST = true, WARLOCK = true,
	DRUID = true, PALADIN = true, HUNTER = true, SHAMAN = true,
	MONK = true, EVOKER = true,
}

function UnitPowerMax(unit)
	if unit == "player" and not MANA_CLASSES[Mock.class] then return 0 end
	return maybeSecret(1000)
end

function UnitPower(unit)
	if unit == "player" and not MANA_CLASSES[Mock.class] then return 0 end
	return maybeSecret(500)
end
-- Party membership drives the partyOnly buffs -- Battle Shout reaches your
-- party and nobody else, so a solo warrior legitimately has nothing to offer.
--
-- In a raid, see Mock.raid: the raid tokens are its members, and a name finds
-- whichever of them Mock.unitNames gives it to.
local function raidIndex(unit)
	local raid = Mock.raid
	if not raid or type(unit) ~= "string" then return nil end
	if unit == "player" then return raid.player or 1 end
	local n = tonumber(unit:match("^raid(%d+)$"))
	if n then
		if n >= 1 and n <= raid.size then return n end
		return nil
	end
	for i = 1, raid.size do
		local named = Mock.unitNames and Mock.unitNames["raid" .. i]
		if named and (unit == named[1] or unit == named[1] .. " " .. tostring(named[2])) then
			return i
		end
	end
	return nil
end

function Mock.subgroupOf(index)
	local raid = Mock.raid
	return (raid.subgroups and raid.subgroups[index]) or math.ceil(index / 5)
end

local function inOwnSubgroup(unit)
	local index = raidIndex(unit)
	if not index then return false end
	return Mock.subgroupOf(index) == Mock.subgroupOf(Mock.raid.player or 1)
end

function UnitInParty(unit)
	if Mock.raid then return maybeSecret(inOwnSubgroup(unit)) end
	return maybeSecret(Mock.groupSize > 0)
end
-- An index for every member of the raid, which is the trap: it is a true
-- answer to "are they in my raid" and no answer at all to "does my shout reach
-- them".
function UnitInRaid(unit)
	if Mock.raid then return maybeSecret(raidIndex(unit)) end
	return maybeSecret(false)
end
function UnitInSubgroup(unit)
	if Mock.raid then return maybeSecret(inOwnSubgroup(unit)) end
	return maybeSecret(Mock.groupSize > 0)
end
-- name, rank, subgroup, and the rest nobody here reads.
function GetRaidRosterInfo(index)
	local raid = Mock.raid
	if not raid or type(index) ~= "number" or index < 1 or index > raid.size then return nil end
	local named = Mock.unitNames and Mock.unitNames["raid" .. index]
	return named and named[1] or ("Raider" .. index), 0, Mock.subgroupOf(index)
end
function UnitPowerType() return 0, "MANA" end
function GetNumGroupMembers()
	if Mock.raid then return Mock.raid.size end
	return Mock.groupSize
end
function IsInRaid() return Mock.raid ~= nil end
function IsSpellKnown(id) return id == 1459 end
function IsPlayerSpell(id) return id == 1459 end
function IsSpellInRange(spell)
	Mock.counts.range = Mock.counts.range + 1
	if Mock.isRangeless(spell) then return nil end
	return Mock.inRange and 1 or 0
end

-- The player's own cast, from Mock.casting. The real call hands back nine
-- values with the two times in milliseconds on the GetTime() clock, and nothing
-- at all once the cast is over -- which is the shape modelled here, so a reader
-- that took the wrong return, or forgot the milliseconds, is wrong against it.
function UnitCastingInfo(unit)
	local c = Mock.casting
	if unit ~= "player" or not c then return nil end
	if Mock.now >= c.endsAt then return nil end
	return "Conjure Water", "", 132793, c.startsAt * 1000, c.endsAt * 1000,
		false, "Cast-mock", false, c.spellId
end

---------------------------------------------------------------------------
-- how far away people are
--
-- No client API answers this. Every proximity signal the addon has is an
-- approximation of it with its own blind spot, so the mock keeps the truth in
-- one place -- Mock.yardsFor -- and lets each signal approximate it the way the
-- real one does. A mock that let a scenario feed an answer straight to the
-- addon would agree with whatever the addon did with it.
---------------------------------------------------------------------------

-- How far away a unit is, in yards.
function Mock.yardsFor(unit)
	return (Mock.yards and Mock.yards[unit]) or Mock.yardsDefault
end

-- The interact prompts, which are the only fixed distance thresholds an addon
-- can ask about without a library. The numbers are the ones measured by the
-- people who maintain LibRangeCheck -- its DefaultInteractList, with the two it
-- comments out -- and this addon only reaches for index 3. They said ten and
-- eleven here while claiming that source, which says eight and nine, and the
-- addon then reported one client call at two different distances.
local INTERACT_YARDS = { [1] = 28, [2] = 9, [3] = 8, [4] = 28 }
-- The same library's InteractLists: two races stand at a different distance
-- from the duel and follow prompts. The library swaps its whole list for these;
-- the client still answers the other two indexes, so here they are laid over
-- the default rather than replacing it.
local INTERACT_RACE = {
	Tauren = { [3] = 6, [4] = 25 },
	Scourge = { [3] = 7, [4] = 27 },
}

-- The prompts' distances for the race being played. Read by the mock
-- LibRangeCheck, which is built further up this file than the locals above are
-- declared, and by the client call below, so the two cannot disagree.
function Mock.interactYards()
	local over = INTERACT_RACE[Mock.playerRace or "Human"]
	if not over then return INTERACT_YARDS end
	local out = {}
	for index, yards in pairs(INTERACT_YARDS) do out[index] = over[index] or yards end
	return out
end

-- Present by default, because every client this addon supports has the
-- function. What differs between them is whether it answers about a player who
-- is not in your group, and that is Mock.interact:
--
--   "on"         -- answers, which is the Classic flavours and the optimistic
--                   reading of Forever
--   "restricted" -- the function is there and returns nothing for a stranger,
--                   which is what modern clients do and the reason the addon
--                   may not simply trust it
--   "secret"     -- it answers with a value we are not allowed to look at,
--                   which is the same refusal in this client's own clothes
--   "gone"       -- no such function
local function mockInteract(unit, index)
	Mock.counts.interact = Mock.counts.interact + 1
	if Mock.interact == "restricted" then return nil end
	if Mock.interact == "secret" then return SECRET end
	local limit = Mock.interactYards()[index]
	if not limit then return nil end
	return Mock.yardsFor(unit) <= limit
end

-- "gone" has to take the global away rather than answer nothing, because the
-- addon tests for the function before it ever calls it, and a mock that only
-- ever returned nil would leave that test unexercised.
function Mock.setInteract(mode)
	Mock.interact = mode
	_G.CheckInteractDistance = (mode ~= "gone") and mockInteract or nil
end
Mock.setInteract("on")

-- LibRangeCheck's estimate lives with the rest of the mock library, in LibStub:
-- it is the library's own search over its checker list now, rather than
-- arithmetic on the true distance, so it goes wrong in the ways the real one
-- does. The buckets are the whole of what makes this library worth having and
-- the whole of its weakness: it answers "between eight and twenty-eight yards",
-- never "nineteen".
function GetSpellInfo(id)
	if Mock.unknownSpells and Mock.unknownSpells[id] then return nil end
	return "Arcane Intellect"
end
function GetBuildInfo()
	return Mock.build or "1.60.1", "69893", "d", Mock.interface or 16001
end

-- The project constants live at the top of this file, because Mock.setFlavour
-- assigns WOW_PROJECT_ID and Mock.reset calls it while this file is still
-- loading.

-- The client's own macro-conditional parser, and the two targeting commands.
-- Not APIs an addon may call for its own purposes -- they are here so a
-- capability probe can find out whether the client understands the syntax the
-- armed macro is written in.
--
-- It answers for real rather than echoing its argument, because the reason this
-- addon ships one targeting strategy rests entirely on what a conditional does
-- NOT resolve to, and an echo agrees with every claim anybody makes about it.
-- Two rules, both established and both universal:
--
--   * [@PlayerName] resolves only for a player in your party or raid. A
--     stranger -- the person this addon exists for -- never resolves, on any of
--     the five.
--   * a client that does not resolve unit conditionals at all resolves nobody,
--     group member or not.
--
-- A clause that resolves to nothing is handed back as nothing, which is exactly
-- the silent failure that keeps the conditional route out of the macro: it
-- casts nothing and says nothing.
function SecureCmdOptionParse(msg)
	local text = tostring(msg)
	local conditional, rest = text:match("^%s*%[([^%]]*)%]%s*(.*)$")
	if not conditional then return text end

	local who = conditional:match("@([^,%]]+)")
	-- No unit named, so this is an ordinary conditional and not our question.
	if not who then return rest end

	if Mock.conditionalTargeting == false then return nil end
	if Mock.groupNames and Mock.groupNames[who] then return rest end
	return nil
end
SecureCmdList = {
	TARGET = function() end,
	TARGET_EXACT = function() end,
}
SLASH_TARGET_EXACT1 = "/targetexact"
function GetNumMacros() return 0, 0 end
function GetMacroIndexByName() return 0 end
function CreateMacro() return 1 end
function EditMacro() end
-- Recorded rather than dropped: "the toggle is on and nothing is audible" is
-- only testable if the test can see what was handed to the client.
function PlaySoundFile(file) Mock.sounds[#Mock.sounds + 1] = file end
-- One combat log line, in the order every flavour that has a log reports it.
--
-- The default is the case the whole source exists for: somebody else putting a
-- real class buff on you. A scenario overrides whichever fields it is about and
-- the rest stay as they are, so a test for "a debuff is not a favour" says
-- auraType and nothing else, and cannot accidentally pass because it changed
-- something it did not mention.
local CLEU_DEFAULT = {
	subevent = "SPELL_AURA_APPLIED",
	sourceGUID = "Player-1-PETRA",
	sourceName = "Petra",
	sourceFlags = 0x400,
	destGUID = "Player-1-player",
	destName = "Mort",
	-- The raid-wide Fortitude, which is the one id in every one of the three
	-- buff sets: a default that only existed on the vanilla tables would make
	-- every assertion here about the flavour rather than about the log.
	spellId = 21562,
	spellName = "Power Word: Fortitude",
	auraType = "BUFF",
}

function CombatLogGetCurrentEventInfo()
	local e = Mock.cleu or {}
	local function field(name)
		local value = e[name]
		if value == nil then return CLEU_DEFAULT[name] end
		-- A scenario saying "there is no source GUID at all" needs a way to say
		-- it that is not the same as saying nothing, since nothing means the
		-- default. Mock.NONE is that way.
		if value == Mock.NONE then return nil end
		return value
	end
	return 1, field("subevent"), false, field("sourceGUID"), field("sourceName"),
		field("sourceFlags"), 0, field("destGUID"), field("destName"), 0, 0,
		field("spellId"), field("spellName"), 1, field("auraType"), 0
end

-- Who the client can name from a GUID alone, with no unit token anywhere. This
-- is the entire reason the combat log is worth registering, so the mock answers
-- it the way the real call does: seven returns, and nothing at all for a GUID
-- that does not belong to a player it knows.
local GUIDS_DEFAULT = {
	["Player-1-PETRA"] = { class = "PRIEST", name = "Petra", realm = "" },
	["Player-1-IRIS"] = { class = "DRUID", name = "Iris", realm = "Ravencrest" },
}

function GetPlayerInfoByGUID(guid)
	local who = (Mock.guids or GUIDS_DEFAULT)[guid]
	if not who then return nil end
	-- The first return is the localized class and the second is the English
	-- one, and they are deliberately different strings here. Everything in this
	-- addon keys on the English one, so a reader that took the first would be
	-- indistinguishable from a correct one if the mock answered both the same.
	local localized = who.class:sub(1, 1) .. who.class:sub(2):lower()
	return localized, who.class, "Human", "Human", "2", who.name, who.realm
end

COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
STANDARD_TEXT_FONT = "font.ttf"
RAID_CLASS_COLORS = { MAGE = { colorStr = "ff40c7eb" }, PRIEST = { colorStr = "ffffffff" } }
bit = { band = function() return 0x400 end }
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end

-- Callbacks the addon has parked on the clock, and a way to let the clock
-- reach them. A no-op C_Timer.After made anything scheduled untestable, which
-- is how a baseline that settles on a timer rather than on the next event would
-- have gone unchecked.
--
-- Nothing fires on its own: Mock.advance moves the clock without running these,
-- so every scenario written before this one behaves exactly as it did. A
-- scenario that wants the callbacks asks for them.
C_Timer = {
	After = function(delay, fn)
		Mock.timers[#Mock.timers + 1] = { at = Mock.now + (tonumber(delay) or 0), fn = fn }
	end,
	NewTicker = function() return {} end,
}

-- Advance the clock and run whatever falls due, including anything the
-- callbacks schedule on their way past -- which is the whole point here, since
-- a settling baseline asks for its next reading from inside the last one. The
-- cap is a runaway guard: a chain that never stops is a bug in the addon, and
-- the scenario should fail rather than hang.
function Mock.runTimers(seconds)
	if seconds then Mock.advance(seconds) end
	for _ = 1, 200 do
		local due
		for i = 1, #Mock.timers do
			if Mock.timers[i].at <= Mock.now then due = i break end
		end
		if not due then return true end
		table.remove(Mock.timers, due).fn()
	end
	return false
end

-- The game's Settings window, opened on Manners' page and shut again.
--
-- OnShow and OnHide fire on the canvas when it starts and stops being visible,
-- whichever of it or the window did the moving -- which is how AceConfigDialog
-- knows to draw and clear the page. Shutting the window leaves the canvas's own
-- shown flag set, as the client does.
function Mock.openSettings()
	local canvas = Mock.blizCanvas
	local was = canvas and canvas:IsVisible()
	Mock.settingsPanelShown = true
	if canvas then
		canvas._shown = true
		if not was and canvas.scripts.OnShow then canvas.scripts.OnShow(canvas) end
	end
end
function Mock.closeSettings()
	local canvas = Mock.blizCanvas
	local was = canvas and canvas:IsVisible()
	Mock.settingsPanelShown = false
	if was and canvas.scripts.OnHide then canvas.scripts.OnHide(canvas) end
end

-- Namespaces are rebuilt on each access so `stripped` can remove them.
local function ns_or_nil(t) if Mock.stripped then return nil end return t end

-- One name per spell rather than one name for every spell in the game.
--
-- The probe asks for the first rank's name and every rank shares it, so this
-- only needs the top of each list. It used to answer "Arcane Intellect" to
-- everything, which was harmless while nothing displayed more than one buff at
-- a time -- and useless the moment the options page started listing a class's
-- whole walk, because a page naming three spells and a page naming one spell
-- three times read identically.
--
-- The lists below the vanilla ones are the other flavours' spells. A mock that
-- named every id "Arcane Intellect" could not tell a Mists monk's two Legacies
-- apart, and -- now that a name which does not resolve is how the addon finds
-- out its data is wrong for this client -- one that names an id no client has
-- would hide exactly the failure that check exists for.
local SPELL_NAMES = {
	[10157] = "Arcane Intellect",
	[10938] = "Power Word: Fortitude",
	[27841] = "Divine Spirit",
	[10958] = "Shadow Protection",
	[9885] = "Mark of the Wild",
	[9910] = "Thorns",
	[25290] = "Blessing of Wisdom",
	[25291] = "Blessing of Might",
	[20217] = "Blessing of Kings",
	[1038] = "Blessing of Salvation",
	[19979] = "Blessing of Light",
	[20914] = "Blessing of Sanctuary",
	[5697] = "Unending Breath",
	[25289] = "Battle Shout",

	-- Mists of Pandaria
	[61316] = "Dalaran Brilliance",
	[19740] = "Blessing of Might",
	[115921] = "Legacy of the Emperor",
	[116781] = "Legacy of the White Tiger",
	[109773] = "Dark Intent",
	[6673] = "Battle Shout",
	[57330] = "Horn of Winter",

	-- Retail
	[1459] = "Arcane Intellect",
	[21562] = "Power Word: Fortitude",
	[1126] = "Mark of the Wild",
	[462854] = "Skyfury",
	[364342] = "Blessing of the Bronze",
	[369459] = "Source of Magic",

	-- Not buffs: what a mage casts by hand between presses. Named because a
	-- line that has to say which spell went out instead needs the mock to
	-- know one that is not Arcane Intellect.
	[116] = "Frostbolt",
	[5504] = "Conjure Water",
}

-- Whether IsSpellInRange has nothing to say about this spell, asked by id or by
-- the name one of the listed ids resolves to: the addon asks both ways.
function Mock.isRangeless(spell)
	local list = Mock.rangeless
	if not list then return false end
	if list[spell] then return true end
	if type(spell) == "string" then
		for id in pairs(list) do
			if SPELL_NAMES[id] == spell then return true end
		end
	end
	return false
end

setmetatable(_G, { __index = function(_, key)
	if key == "C_Spell" then
		return ns_or_nil({
			GetSpellName = function(id)
				if Mock.unknownSpells and Mock.unknownSpells[id] then return nil end
				return SPELL_NAMES[id] or "Arcane Intellect"
			end,
			GetSpellTexture = function() return 135932 end,
			GetSpellInfo = function() return { name = "Arcane Intellect" } end,
			IsSpellInRange = function(spell)
				Mock.counts.range = Mock.counts.range + 1
				if Mock.isRangeless(spell) then return nil end
				return Mock.inRange
			end,
			GetSpellCooldown = function(id)
				local entry = Mock.spellCooldowns and Mock.spellCooldowns[id]
				if not entry then return nil end
				if type(entry) ~= "table" then
					return { startTime = Mock.now, duration = entry, isEnabled = true, modRate = 1 }
				end
				return { startTime = entry.startTime or Mock.now, duration = entry.duration or 0,
					isEnabled = true, modRate = 1, isActive = entry.isActive, isOnGCD = entry.isOnGCD }
			end,
		})
	elseif key == "C_UnitAuras" then
		local api = {
			-- Mock.held is a set of spell ids the unit is carrying, so a
			-- scenario can put somebody halfway through a buff set.
			GetUnitAuraBySpellID = function(_, spellId)
				Mock.counts.auraRead = Mock.counts.auraRead + 1
				local refuse = Mock.auraReadRefuse and Mock.auraReadRefuse[spellId]
				if refuse == "throw" then error("aura read refused for " .. tostring(spellId)) end
				if refuse == "secret" then return SECRET end
				if Mock.held and Mock.held[spellId] then
					return { spellId = spellId, expirationTime = Mock.now + (Mock.heldFor or 3600),
						sourceUnit = Mock.heldSource and Mock.heldSource[spellId] or nil }
				end
				return nil
			end,
			GetAuraDataByIndex = function(_, i)
				-- A loading screen hands back a list that is not readable yet,
				-- which is not the same as an empty one. Whether this client
				-- says so with a value you are not allowed to look at or with
				-- plain silence is established nowhere, so the shape is a knob
				-- and both are modelled: picking one and writing the addon
				-- against it is how the suite came to agree with the code by
				-- construction rather than by evidence.
				if Mock.auraBlackout then return refuseAura() end
				-- A refusal with readable auras still behind it: the
				-- transitional scan rather than the blackout.
				if Mock.auraHidden and Mock.auraHidden[i] then return refuseAura() end
				local count = Mock.auraCount or 2
				-- A character carrying nothing at all: every slot answers, and
				-- answers "there is nothing here". The opposite of a blackout,
				-- and the case a scan that reads nothing must not be mistaken
				-- for.
				if Mock.noAuras then count = 0 end
				-- A buff that has just landed, so a scenario can produce a
				-- favour without renumbering the ones already there. It takes
				-- the first free slot rather than a fixed one: the client hands
				-- this list over packed from slot one, and a mock that left a
				-- gap in front of the new aura was modelling a list no client
				-- produces -- and asking the addon to treat it as ordinary.
				if Mock.extraAura and i == count + 1 then
					return { auraInstanceID = Mock.extraAura == true and 3003 or Mock.extraAura,
						spellId = Mock.extraAuraSpell or 1459,
						sourceUnit = Mock.extraAuraSource
							and maybeSecret(Mock.extraAuraSource) or nil,
						expirationTime = Mock.extraAuraUntil or 2000 }
				end
				if i > count then return nil end
				-- auraIdBase renumbers the same auras, which is what a zone
				-- change does to instance ids.
				return { auraInstanceID = i + Mock.auraIdBase, spellId = 1459,
					sourceUnit = maybeSecret("nameplate1"), expirationTime = 2000 }
			end,
		}
		-- Removed rather than made to fail: this is the namespace being there
		-- and the function not, which is what the scan's own gate tests for.
		if Mock.noAuraScanner then api.GetAuraDataByIndex = nil end
		return ns_or_nil(api)
	elseif key == "C_Secrets" then
		return ns_or_nil({
			ShouldAurasBeSecret = function() return Mock.allSecret end,
			ShouldSpellAuraBeSecret = function(spellId)
				if Mock.allSecret then return true end
				return (Mock.secretAuraIds and Mock.secretAuraIds[spellId]) == true
			end,
			GetSpellAuraSecrecy = function() return 0 end,
			HasSecretRestrictions = function() return Mock.secretRestrictions end,
		})
	elseif key == "C_NamePlate" then
		return ns_or_nil({ GetNamePlates = function() return {} end })
	elseif key == "C_Texture" then
		return ns_or_nil({ GetAtlasInfo = function() return nil end })
	elseif key == "C_RestrictedActions" then
		return ns_or_nil({ GetAddOnRestrictionState = function() return 0 end })
	elseif key == "Enum" then
		return {
			PowerType = { Mana = 0 },
			SecrecyLevel = { NeverSecret = 0 },
			AddOnRestrictionState = { Inactive = 0, Active = 1, Activating = 2 },
			AddOnRestrictionType = { Map = 1, Combat = 2 },
		}
	end
	return nil
end })
