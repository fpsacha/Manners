-- A WoW API stand-in, configurable through the global `Mock` so scenarios can
-- make the client behave badly on purpose: withhold values as secrets, remove
-- APIs entirely, put the player in combat or in the graveyard.

Mock = Mock or {}
Mock.now = 1000

function Mock.reset()
	Mock.class = "MAGE"
	Mock.dead = false
	Mock.inCombat = false
	Mock.allSecret = false
	Mock.stripped = false
	Mock.unitName = { "Petra", "Stonewell" }
	Mock.nameplates = { "nameplate1", "nameplate2" }
	Mock.now = 1000
	Mock.groupSize = 0
	Mock.held = nil
	Mock.heldFor = nil
	Mock.auraBlackout = false
	Mock.noAuras = false
	Mock.extraAura = false
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
	Mock.inRange = true
	Mock.unitClass = "PRIEST"
	Mock.iconDb = nil
	Mock.sounds = {}
	Mock.printed = {}
	-- Every line the tooltip put up since it was last owned. The tooltip is the
	-- most detailed thing the prompt says and none of it was testable.
	Mock.tooltip = {}
	-- Whether the options window is on screen, which is what decides whether
	-- the preview is allowed to time out. `true` is the standalone AceConfig
	-- dialog and "blizzard" is the interface-options panel; both routes in.
	Mock.optionsOpen = false
	-- How many times the options page has been asked to redraw itself.
	Mock.optionsRepaints = 0
	-- The screen, and where on it the prompt is sitting. The queue list flips
	-- to the other side of the panel when the prompt is low enough that the
	-- rows would hang off the bottom edge.
	Mock.screenHeight = 1000
	Mock.promptCentreY = 500
	-- The wall clock. GetTime() restarts near zero every login and the epoch
	-- does not, which is the whole difficulty with storing a debt.
	Mock.epoch = 1700000000
	-- Stands in for the SavedVariables file: handed to every AceDB the mock
	-- builds, so two successive load()s share it the way two sessions share a
	-- file on disk. Cleared here so one scenario's debts cannot leak into the
	-- next; a scenario that models a reload simply does not reset in between.
	Mock.sv = {}
	Mock.dbCallbacks = {}
	-- How often the addon actually asked the client something. Caching and
	-- deduplication are invisible to every other kind of assertion.
	Mock.counts = { range = 0, auraRead = 0 }
end
Mock.reset()

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
	f.SetShown = function(self, shown) self._shown = shown and true or false return self end
	-- Kept as the raw argument list: SetPoint is called with three arguments in
	-- some places and five in others, and which anchor a queue row hangs from
	-- is the whole of what the flip test reads.
	f.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } return self end
	f.ClearAllPoints = function(self) self.points = {} return self end
	f.GetCenter = function() return 400, Mock.promptCentreY end
	f.GetHeight = function() return Mock.screenHeight end

	f.SetScript = function(self, which, fn) self.scripts[which] = fn return self end
	f.GetScript = function(self, which) return self.scripts[which] end
	f.SetAttribute = function(self, k, v) self.attributes[k] = v return self end
	f.GetAttribute = function(self, k) return self.attributes[k] end
	f.IsShown = function(self) return self._shown ~= false end
	f.Show = function(self) self._shown = true return self end
	f.Hide = function(self) self._shown = false return self end
	f.IsPlaying = function() return false end
	f.IsOwned = function() return false end
	f.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
	f.GetHighlightTexture = function() return newFrame() end
	f.CreateTexture = function() return newFrame() end
	f.CreateFontString = function() return newFrame() end
	f.CreateAnimationGroup = function() return newFrame() end
	f.CreateAnimation = function() return newFrame() end
	f.CreateMaskTexture = function() return newFrame() end
	f.RegisterEvent = function(self, event)
		if not KNOWN_EVENTS[event] then Mock.badEvents[#Mock.badEvents + 1] = event end
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
function LibStub(name)
	if libs[name] then return libs[name] end
	local lib = {}
	if name == "AceAddon-3.0" then
		lib.NewAddon = function(_, addonName)
			local a = {}
			a.RegisterEvent = function(self, event)
				if not KNOWN_EVENTS[event] then
					error("registered unknown event: " .. tostring(event), 0)
				end
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
			local db = { profile = deepcopy(defaults.profile) }
			-- AceDB's per-character section, created on first access and kept
			-- in the one saved file. Backed by Mock.sv so it survives a load().
			Mock.sv.char = Mock.sv.char or {}
			db.char = Mock.sv.char
			-- Recorded rather than dropped: OnDatabaseShutdown is the only hook
			-- the logout flush hangs on, and a scenario has to be able to fire
			-- it the way the real library does.
			db.RegisterCallback = function(target, event, method)
				Mock.dbCallbacks[event] = { target = target, method = method }
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
			f.IsShown = function() return Mock.optionsOpen == "blizzard" end
			return f
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
	elseif name == "LibDataBroker-1.1" then lib.NewDataObject = function() return {} end
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

function UnitName(u)
	if u == "player" then return "Mort", "Defrette" end
	return maybeSecret(Mock.unitName[1]), maybeSecret(Mock.unitName[2])
end
function GetUnitName() return "Petra Stonewell" end
function UnitClass(u)
	if u == "player" then return "Mage", Mock.class end
	return "Priest", maybeSecret(Mock.unitClass)
end
function UnitGUID(u) return maybeSecret("Player-1-" .. tostring(u)) end
function UnitExists() return maybeSecret(true) end
function UnitIsPlayer() return maybeSecret(true) end
function UnitIsUnit(a, b) return a == b end
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
local MANA_CLASSES = {
	MAGE = true, PRIEST = true, WARLOCK = true,
	DRUID = true, PALADIN = true, HUNTER = true, SHAMAN = true,
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
function UnitInParty() return maybeSecret(Mock.groupSize > 0) end
function UnitInRaid() return maybeSecret(false) end
function UnitPowerType() return 0, "MANA" end
function GetNumGroupMembers() return Mock.groupSize end
function IsInRaid() return false end
function IsSpellKnown(id) return id == 1459 end
function IsPlayerSpell(id) return id == 1459 end
function IsSpellInRange()
	Mock.counts.range = Mock.counts.range + 1
	return Mock.inRange and 1 or 0
end
function GetSpellInfo() return "Arcane Intellect" end
function GetBuildInfo() return "1.60.1", "69893", "d", 16001 end
function GetNumMacros() return 0, 0 end
function GetMacroIndexByName() return 0 end
function CreateMacro() return 1 end
function EditMacro() end
-- Recorded rather than dropped: "the toggle is on and nothing is audible" is
-- only testable if the test can see what was handed to the client.
function PlaySoundFile(file) Mock.sounds[#Mock.sounds + 1] = file end
function CombatLogGetCurrentEventInfo()
	return 1, "SPELL_AURA_APPLIED", false, "src", "Petra", 0x400, 0,
		"Player-1-player", "Mort", 0, 0, 1459, "AI", 1, "BUFF"
end

COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
STANDARD_TEXT_FONT = "font.ttf"
RAID_CLASS_COLORS = { MAGE = { colorStr = "ff40c7eb" }, PRIEST = { colorStr = "ffffffff" } }
bit = { band = function() return 0x400 end }
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end

C_Timer = { After = function() end, NewTicker = function() return {} end }

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
}

setmetatable(_G, { __index = function(_, key)
	if key == "C_Spell" then
		return ns_or_nil({
			GetSpellName = function(id) return SPELL_NAMES[id] or "Arcane Intellect" end,
			GetSpellTexture = function() return 135932 end,
			GetSpellInfo = function() return { name = "Arcane Intellect" } end,
			IsSpellInRange = function()
				Mock.counts.range = Mock.counts.range + 1
				return Mock.inRange
			end,
		})
	elseif key == "C_UnitAuras" then
		local api = {
			-- Mock.held is a set of spell ids the unit is carrying, so a
			-- scenario can put somebody halfway through a buff set.
			GetUnitAuraBySpellID = function(_, spellId)
				Mock.counts.auraRead = Mock.counts.auraRead + 1
				if Mock.held and Mock.held[spellId] then
					return { spellId = spellId, expirationTime = Mock.now + (Mock.heldFor or 3600) }
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
						spellId = 1459,
						sourceUnit = maybeSecret("nameplate1"), expirationTime = 2000 }
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
			ShouldSpellAuraBeSecret = function() return Mock.allSecret end,
			GetSpellAuraSecrecy = function() return 0 end,
			HasSecretRestrictions = function() return true end,
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
