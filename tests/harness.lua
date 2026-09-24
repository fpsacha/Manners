-- Minimal WoW API stand-in, enough to load Manners and drive its main paths.
-- The point is to catch what a syntax check cannot: calls to names that do not
-- exist, handlers registered for events that do not exist, and errors on the
-- paths that actually run.

local errors = {}
local function note(msg) errors[#errors + 1] = msg end

-- every frame method we call, as a no-op that returns something plausible
local frameMethods = {
  "SetSize", "SetPoint", "ClearAllPoints", "SetAllPoints", "Show", "Hide",
  "SetScale", "SetAlpha", "SetMovable", "SetClampedToScreen", "RegisterForDrag",
  "RegisterForClicks", "SetAttribute", "SetScript", "CreateTexture", "SetWidth",
  "SetHeight", "SetTexture", "SetVertexColor", "SetColorTexture", "SetTexCoord",
  "SetBlendMode", "CreateFontString", "SetFont", "SetText", "SetTextColor",
  "SetJustifyH", "SetWordWrap", "SetShadowColor", "SetShadowOffset", "SetShown",
  "CreateAnimationGroup", "CreateAnimation", "SetFromAlpha", "SetToAlpha",
  "SetDuration", "SetOrder", "SetSmoothing", "SetOffset", "SetLooping", "Play",
  "Stop", "SetBackdrop", "SetBackdropBorderColor", "RegisterEvent",
  "UnregisterEvent", "SetFrameStrata", "SetHighlightTexture", "EnableMouse",
  "StartMoving", "StopMovingOrSizing", "SetGradient", "CreateMaskTexture",
  "AddMaskTexture", "SetAtlas", "SetCountdownFormatter", "SetUserPlaced",
}

local function newFrame()
  local f = { scripts = {}, attributes = {} }
  for _, name in ipairs(frameMethods) do
    f[name] = function(self, ...) return self end
  end
  f.SetScript = function(self, which, fn) self.scripts[which] = fn return self end
  f.GetScript = function(self, which) return self.scripts[which] end
  f.SetAttribute = function(self, k, v) self.attributes[k] = v return self end
  f.GetAttribute = function(self, k) return self.attributes[k] end
  f.IsShown = function() return true end
  f.IsPlaying = function() return false end
  f.IsOwned = function() return false end
  f.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
  -- The prompt asks where it is on screen to decide which side of itself the
  -- queue list hangs off. Present here so that path runs rather than being
  -- skipped by its own guard.
  f.GetCenter = function() return 400, 500 end
  f.GetHeight = function() return 1000 end
  f.GetHighlightTexture = function() return newFrame() end
  f.CreateTexture = function() return newFrame() end
  f.CreateFontString = function() return newFrame() end
  f.CreateAnimationGroup = function() return newFrame() end
  f.CreateAnimation = function() return newFrame() end
  f.CreateMaskTexture = function() return newFrame() end
  return f
end

_G = _ENV or _G
UIParent = newFrame()
GameTooltip = newFrame()
GameTooltip.AddLine = function() end
GameTooltip.AddDoubleLine = function() end
GameTooltip.SetOwner = function() end
GameTooltip.IsOwned = function() return false end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

function CreateFrame() return newFrame() end

-- Events the client is deemed to have. Registering anything else is exactly
-- the bug that stopped the scanner from ever starting.
local KNOWN_EVENTS = {}
for _, e in ipairs({
  "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_AURA", "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED",
  "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_DEAD",
  "PLAYER_ALIVE", "PLAYER_UNGHOST", "UNIT_SPELLCAST_SENT",
  "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UI_ERROR_MESSAGE",
  "GROUP_ROSTER_UPDATE", "ADDON_LOADED",
}) do KNOWN_EVENTS[e] = true end

-- Ace3 stand-ins
local libs = {}
local function getLibrary(name, silent)
  if libs[name] then return libs[name] end
  local lib = {}
  if name == "AceAddon-3.0" then
    lib.NewAddon = function(_, addonName, ...)
      local a = {}
      a.RegisterEvent = function(self, event)
        if not KNOWN_EVENTS[event] then
          note("registered unknown event: " .. tostring(event))
        end
        self._events = self._events or {}
        self._events[event] = true
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
      local db = { profile = {} }
      local function deepcopy(t)
        local out = {}
        for k, v in pairs(t) do out[k] = type(v) == "table" and deepcopy(v) or v end
        return out
      end
      db.profile = deepcopy(defaults.profile)
      -- AceDB's per-character section, created on first access. Present here so
      -- a write to it during load is a load-time finding rather than a throw
      -- only the scenarios would ever see.
      db.char = {}
      db.RegisterCallback = function() end
      return db
    end
  elseif name == "AceConfig-3.0" then
    lib.RegisterOptionsTable = function() end
  elseif name == "AceConfigDialog-3.0" then
    -- Shut, like the real panel is on login. Every other mock frame answers
    -- "shown", and one that did so here would tell the prompt somebody is
    -- styling it for the whole of the run.
    lib.AddToBlizOptions = function()
      local f = newFrame()
      f.IsShown = function() return false end
      return f
    end
    lib.Open = function() end
    lib.OpenFrames = {}
  elseif name == "AceConfigRegistry-3.0" then
    -- Present so the load-time path that repaints the page is exercised here
    -- too; the harness only cares that calling it does not throw.
    lib.NotifyChange = function() end
  elseif name == "AceDBOptions-3.0" then
    lib.GetOptionsTable = function() return { type = "group", name = "p", args = {} } end
  elseif name == "LibSharedMedia-3.0" then
    -- Register and IsValid have to exist here or the sound registration and
    -- the clamp throw into ns.errors, which the harness reports as a finding.
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
      -- Unknown keys fall back to the type's default, as the real library
      -- does; for sound that default is "None", which plays nothing.
      return t[key] or (not noDefault and t[self.defaults[kind]]) or nil
    end
    lib.HashTable = function(self, kind) return self.media[kind] or {} end
  elseif name == "LibDataBroker-1.1" then
    lib.NewDataObject = function() return {} end
  elseif name == "LibDBIcon-1.0" then
    lib.iconDb = nil
    lib.Register = function(self, _, _, db) self.iconDb = db end
    lib.Refresh = function(self, _, db) if db then self.iconDb = db end end
    lib.IsRegistered = function() return true end
    lib.Show = function() end
    lib.Hide = function() end
  end
  libs[name] = lib
  return lib
end

-- A table with a __call metamethod and a GetLibrary method, which is what the
-- real LibStub is. A plain function here let a caller that only accepts
-- functions pass in the harness and fail in the game.
LibStub = setmetatable({ libs = libs, minors = {}, minor = 2 }, {
  __call = function(_, name, silent) return getLibrary(name, silent) end,
})
function LibStub:GetLibrary(name, silent) return getLibrary(name, silent) end
function LibStub:IterateLibraries() return pairs(libs) end

-- WoW globals the addon touches
function issecretvalue() return false end
function InCombatLockdown() return false end
function GetTime() return 1000 end
-- The wall clock. GetTime() is the machine's uptime and starts again after a
-- reboot, and this does not, so anything
-- written to SavedVariables has to go out in these units.
function time() return 1700000000 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function date(fmt) return "12:00:00" end
function UnitName(u) if u == "player" then return "Mort", "Defrette" end return "Petra", "Stonewell" end
function GetUnitName(u) return "Petra Stonewell" end
function UnitClass() return "Mage", "MAGE" end
function UnitGUID() return "Player-1-ABC" end
function UnitExists() return true end
function UnitIsPlayer() return true end
function UnitIsUnit(a, b) return a == b end
function UnitIsDeadOrGhost() return false end
function UnitCanAssist() return true end
function UnitIsConnected() return true end
function UnitIsCharmed() return false end
function UnitInVehicle() return false end
function UnitOnTaxi() return false end
function UnitLevel() return 12 end
function UnitPowerMax() return 1000 end
function UnitPower() return 500 end
function UnitInParty() return false end
function UnitInRaid() return false end
function UnitPowerType() return 0, "MANA" end
function UnitGroupRolesAssigned() return "NONE" end
function GetNumGroupMembers() return 0 end
function IsInRaid() return false end
function IsSpellKnown(id) return id == 1459 end
function IsPlayerSpell(id) return id == 1459 end
function IsSpellInRange() return 1 end
function GetSpellInfo() return "Arcane Intellect" end
function GetBuildInfo() return "1.60.1", "69893", "date", 16001 end
function GetNumMacros() return 0, 0 end
function GetMacroIndexByName() return 0 end
function CreateMacro() return 1 end
function EditMacro() end
function PlaySoundFile() end
function CombatLogGetCurrentEventInfo()
  return 1, "SPELL_AURA_APPLIED", false, "Player-1-PETRA", "Petra", 0x512, 0, "Player-1-ABC", "Mort", 0, 0, 21562, "PWF", 1, "BUFF", 0
end
-- A name and a class out of a GUID with no unit token. The combat log favour
-- source is built entirely on this call, so the harness has to have it or the
-- path it drives below returns before reaching anything.
function GetPlayerInfoByGUID(guid)
  if guid ~= "Player-1-PETRA" then return nil end
  return "Priest", "PRIEST", "Human", "Human", "2", "Petra", ""
end
function GameTooltip_Hide() end
COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
STANDARD_TEXT_FONT = "font.ttf"
RAID_CLASS_COLORS = { MAGE = { colorStr = "ff40c7eb" }, PRIEST = { colorStr = "ffffffff" } }
bit = { band = function(a, b) return 0x400 end }

C_Timer = { After = function(_, fn) end, NewTicker = function() return {} end }
C_Spell = {
  GetSpellName = function(id) return "Arcane Intellect" end,
  GetSpellTexture = function() return 135932 end,
  GetSpellInfo = function() return { name = "Arcane Intellect" } end,
  IsSpellInRange = function() return true end,
}
C_UnitAuras = {
  GetUnitAuraBySpellID = function() return nil end,
  GetAuraDataByIndex = function(_, i) if i > 2 then return nil end
    return { auraInstanceID = i, spellId = 1459, sourceUnit = "nameplate1", expirationTime = 2000 } end,
}
C_Secrets = {
  ShouldAurasBeSecret = function() return false end,
  ShouldSpellAuraBeSecret = function() return false end,
  GetSpellAuraSecrecy = function() return 0 end,
  HasSecretRestrictions = function() return true end,
}
C_NamePlate = { GetNamePlates = function() return {} end }
C_Texture = { GetAtlasInfo = function() return nil end }
C_RestrictedActions = { GetAddOnRestrictionState = function() return 0 end }
Enum = {
  PowerType = { Mana = 0 },
  SecrecyLevel = { NeverSecret = 0 },
  AddOnRestrictionState = { Inactive = 0, Active = 1, Activating = 2 },
  AddOnRestrictionType = { Map = 1, Combat = 2 },
}
Settings = nil
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
BackdropTemplateMixin = {}

-- ---------------------------------------------------------------- run it
local ADDON, ns = "Manners", {}
local dir = ...

for _, file in ipairs({ "Flavour.lua", "Buffs.lua", "Core.lua", "Ledger.lua", "Prompt.lua", "Options.lua" }) do
  local chunk, err = loadfile(dir .. "/" .. file)
  if not chunk then
    note("LOAD " .. file .. ": " .. tostring(err))
  else
    local ok, runErr = pcall(chunk, ADDON, ns)
    if not ok then note("RUN " .. file .. ": " .. tostring(runErr)) end
  end
end

-- drive the lifecycle
local addon = ns.addon
if not addon then
  note("ns.addon was never set")
else
  local steps = {
    { "OnInitialize", function() addon:OnInitialize() end },
    { "OnEnable", function() addon:OnEnable() end },
    { "PLAYER_ENTERING_WORLD", function() addon:PLAYER_ENTERING_WORLD() end },
    { "ProbeCapabilities", function() ns.ProbeCapabilities() end },
    { "BuildQueue", function() return ns.BuildQueue() end },
    { "Tick", function() addon:Tick() end },
    { "UNIT_AURA player", function() addon:UNIT_AURA(nil, "player") end },
    -- Driven whether or not this client would have registered it. The handler
    -- is reachable code either way, and a call into a name that does not exist
    -- is exactly what this file is for.
    { "COMBAT_LOG_EVENT_UNFILTERED", function() addon:COMBAT_LOG_EVENT_UNFILTERED() end },
    { "ScanOwnBuffs", function() ns.ScanOwnBuffs() end },
    { "Prompt:ApplyStyle", function() ns.Prompt:ApplyStyle() end },
    { "Prompt:Refresh", function() ns.Prompt:Refresh() end },
    { "ResolveBuff", function() return ns.ResolveBuff(true) end },
    { "ClampSettings", function() ns.ClampSettings() end },
    -- Every profile switch, copy and reset comes back through here, so a hop
    -- it makes into a library that is not there is a load-time failure.
    { "RefreshConfig", function() addon:RefreshConfig() end },
    -- Both ends of a fight. The prompt is held and released here, and the
    -- options page is asked to redraw itself so the notice over the frozen
    -- controls comes up and goes away again -- a hop into a library that may
    -- not be there, which is exactly the class of failure this file exists for.
    { "PLAYER_REGEN_DISABLED", function() addon:PLAYER_REGEN_DISABLED() end },
    { "PLAYER_REGEN_ENABLED", function() addon:PLAYER_REGEN_ENABLED() end },
    { "slash debug", function() addon:HandleSlash("debug") end },
    { "slash help", function() addon:HandleSlash("") end },
  }
  for _, step in ipairs(steps) do
    local ok, err = pcall(step[2])
    if not ok then note(step[1] .. ": " .. tostring(err)) end
  end

  -- the errors the addon caught itself are findings too
  for _, e in ipairs(ns.errors or {}) do
    note("guarded error in " .. tostring(e.where) .. ": " .. tostring(e.err))
  end
end

print("=== harness ===")
if #errors == 0 then
  print("addon loaded and every driven path ran clean")
else
  for _, e in ipairs(errors) do print("  " .. e) end
end
print("errors: " .. #errors)
