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
end
Mock.reset()

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

-- A secret value is returned in place of the real one; the addon is expected
-- to route everything it branches on through its own plain() first.
local function maybeSecret(value)
	if Mock.allSecret then return SECRET end
	return value
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
	local f = { scripts = {}, attributes = {} }
	for _, name in ipairs(frameMethods) do f[name] = function(self) return self end end
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
GameTooltip.AddLine = function() end
GameTooltip.AddDoubleLine = function() end
GameTooltip.SetOwner = function() end
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
			a.Print = function() end
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
			db.RegisterCallback = function() end
			return db
		end
	elseif name == "AceConfig-3.0" then lib.RegisterOptionsTable = function() end
	elseif name == "AceConfigDialog-3.0" then
		lib.AddToBlizOptions = function() return newFrame() end
		lib.Open = function() end
	elseif name == "AceDBOptions-3.0" then
		lib.GetOptionsTable = function() return { type = "group", name = "p", args = {} } end
	elseif name == "LibSharedMedia-3.0" then
		lib.Fetch = function() return "font.ttf" end
		lib.HashTable = function() return {} end
	elseif name == "LibDataBroker-1.1" then lib.NewDataObject = function() return {} end
	elseif name == "LibDBIcon-1.0" then
		lib.Register = function() end
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
function Mock.advance(seconds) Mock.now = Mock.now + seconds end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function date() return "12:00:00" end

function UnitName(u)
	if u == "player" then return "Mort", "Defrette" end
	return maybeSecret(Mock.unitName[1]), maybeSecret(Mock.unitName[2])
end
function GetUnitName() return "Petra Stonewell" end
function UnitClass(u)
	if u == "player" then return "Mage", Mock.class end
	return "Priest", maybeSecret("PRIEST")
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
function IsSpellInRange() return 1 end
function GetSpellInfo() return "Arcane Intellect" end
function GetBuildInfo() return "1.60.1", "69893", "d", 16001 end
function GetNumMacros() return 0, 0 end
function GetMacroIndexByName() return 0 end
function CreateMacro() return 1 end
function EditMacro() end
function PlaySoundFile() end
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

setmetatable(_G, { __index = function(_, key)
	if key == "C_Spell" then
		return ns_or_nil({
			GetSpellName = function() return "Arcane Intellect" end,
			GetSpellTexture = function() return 135932 end,
			GetSpellInfo = function() return { name = "Arcane Intellect" } end,
			IsSpellInRange = function() return true end,
		})
	elseif key == "C_UnitAuras" then
		return ns_or_nil({
			GetUnitAuraBySpellID = function() return nil end,
			GetAuraDataByIndex = function(_, i)
				if i > 2 then return nil end
				return { auraInstanceID = i, spellId = 1459,
					sourceUnit = maybeSecret("nameplate1"), expirationTime = 2000 }
			end,
		})
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
