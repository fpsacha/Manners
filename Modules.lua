-- Manners -- the small public surface optional addon folders may use.
--
-- A module is a separate addon with no access to the private `ns` table. Keep
-- its SavedVariables in MannersDB so a feature moved out of the core keeps its
-- old choices, and keep everything else behind this explicit API.

local ns = select(2, ...)

local api = {}
local callbacks, options, loaded, optionExtensions, ledgerTabs = {}, {}, {}, {}, {}
local lifecycles = {}
local moduleContexts = {}
local attached, coreReady = {}, false
local pendingReload = {}
local moduleWelcomeOpen = false
local moduleWelcomeToken

local KNOWN = {
	{ id = "combat", title = "Manners: Combat" },
	{ id = "achievements", title = "Manners: Achievements" },
	{ id = "pets", title = "Manners: Pets" },
	{ id = "mybuffs", title = "Manners: My Buffs" },
	{ id = "services", title = "Manners: Services" },
}

_G.MannersAPI = api

function api:GetDB()
	return ns.db
end

function api:GetProfile()
	return ns.db and ns.db.profile or nil
end

function api:GetFlavour()
	return ns.Flavour and ns.Flavour.flavour or nil
end

function api:Plain(value)
	return ns.plain(value)
end

function api:Guard(label, fn, ...)
	return ns.Guard(label, fn, ...)
end

function api:Trail(kind, text, name)
	return ns.Trail(kind, text, name)
end

function api:RefreshPrompt()
	if ns.Prompt then return ns.Guard("module prompt refresh", ns.Prompt.Refresh, ns.Prompt) end
end

function api:OpenLedger(tab)
	if not ns.Ledger or type(ns.Ledger.Show) ~= "function" then return false end
	ns.Guard("module ledger", ns.Ledger.Show, tab)
	return true
end

-- `callback` is a function. `owner` is the module table it should receive as
-- its first argument, or nil for a plain function.
function api:RegisterCallback(event, callback, owner)
	if type(event) ~= "string" or event == "" or type(callback) ~= "function" then return false end
	local list = callbacks[event]
	if not list then
		list = {}
		callbacks[event] = list
	end
	list[#list + 1] = { callback = callback, owner = owner }
	return true
end

function api:UnregisterCallback(event, callback, owner)
	local list = callbacks[event]
	if type(list) ~= "table" then return end
	for i = #list, 1, -1 do
		local one = list[i]
		if one.callback == callback and one.owner == owner then table.remove(list, i) end
	end
end

-- One suspend/resume pair per loaded optional addon. Secure-frame creation and
-- destruction still belong to login/reload; these callbacks stop runtime work
-- and hide/disarm the frames that already exist.
function api:RegisterModuleLifecycle(id, suspend, resume)
	if type(id) ~= "string" or id == "" or type(suspend) ~= "function" or type(resume) ~= "function" then
		return false
	end
	lifecycles[id] = { suspend = suspend, resume = resume }
	return true
end

local function SetModuleActive(id, active)
	local lifecycle = lifecycles[id]
	if lifecycle then
		local where = active and "resume " or "suspend "
		ns.Guard(where .. id, active and lifecycle.resume or lifecycle.suspend)
	end
	api:Fire("ModuleStateChanged", id, active)
	api:RefreshPrompt()
end

function api:Fire(event, ...)
	if event == "CoreReady" then coreReady = true end
	local list = callbacks[event]
	if type(list) ~= "table" then return end
	for i = 1, #list do
		local one = list[i]
		local args = { ... }
		ns.Guard("module callback " .. event, function()
			one.callback(one.owner, unpack(args))
		end)
	end
end

local COMBAT_KEYS = {
	L = true, Prompt = true, Flavour = true, caps = true,
	plain = true, safecall = true, safecallok = true, Guard = true, Trail = true, db = true,
	addon = true, pendingClick = true, ExpirePendingClick = true,
	ProbeCapabilities = true, SpellKnown = true, SpellNameFor = true,
	CastReady = true,
	AddSettingsLine = true, MACRO_LIMIT = true, InRange = true,
	IsTankUnit = true, ShortName = true, UnitFullName = true,
	BuffInfo = true, CanCastAnything = true, DebtExpiry = true,
	Ignored = true, IsBlocked = true, IsNeverOffered = true,
	MuteListed = true, PastFollowReach = true, PvPHoldsBack = true,
	SafeForMacro = true, TargetName = true, TimeText = true,
	owed = true, zonedAt = true,
	ClassHasCures = true, CureFightKnown = true, CureFightRead = true,
	CureFightSpells = true, CureReason = true, CureLearned = true,
	CureInfo = true, CureSummary = true, CuresWanted = true,
	CureScan = true, CureScanned = true, CureFor = true, CureSelf = true,
	CuresRemembered = true, CureLines = true, ForgetCureRead = true,
	CureSuspend = true,
	BreakFree = true, MendPet = true, CureFight = true, CureNeed = true,
	CombatLayout = true, ReactiveWards = true,
	CombatActions = true, Moments = true, Sense = true, MomentCard = true,
	Looks = true, LOCALE = true, ReagentCount = true, ReagentName = true, defaults = true,
	MOMENTS = true, MOMENT_KEYS = true, MOMENT_DEFAULTS = true, MOMENT_SETS = true,
	CAST_SCHOOLS = true, CAST_SCHOOLS_BY_CLIENT = true, Setup = true,
	BreakFreeLines = true, MendPetLines = true, CureFightLines = true,
	OptionsPage = true, WindowLayout = true,
	-- The combat prompt's move: the settings put away while it is moved, and
	-- opened again on its page after; repainted as the preview starts and ends.
	RefreshOptionsDisplay = true, OpenOptions = true, CloseOptions = true,
	OptionsOpen = true, OptionsTab = true,
	ContextDecision = true, ContextTarget = true,
	ModuleActive = true,
}
local COMBAT_WRITES = {
	BreakFree = true, MendPet = true, CureFight = true, CureNeed = true,
	CombatLayout = true, ReactiveWards = true,
	CombatActions = true, Moments = true, Sense = true, MomentCard = true,
	MOMENTS = true, MOMENT_KEYS = true, MOMENT_DEFAULTS = true, MOMENT_SETS = true,
	CAST_SCHOOLS = true, CAST_SCHOOLS_BY_CLIENT = true, MomentLines = true,
	BreakFreeLines = true, MendPetLines = true, CureFightLines = true,
	CureFightKnown = true, ProbeCapabilities = true,
	ClassHasCures = true, CureLearned = true, CureInfo = true,
	CureSummary = true, CuresWanted = true, CureScan = true,
	CureScanned = true, CureFor = true, CureSelf = true,
	CuresRemembered = true, CureReason = true, CureLines = true,
	ForgetCureRead = true, CureFightRead = true, CureFightSpells = true,
	CureSuspend = true,
	cureReads = true,
}

local PET_KEYS = {
	L = true, addon = true, db = true, plain = true, safecall = true,
	Guard = true, Trail = true, Flavour = true, caps = true,
	Prompt = true, BuildQueue = true, MendPet = true, InCharacter = true,
	BEAST_FOODS = true, BEAST_DIETS = true, FOODS = true,
	SpellKnown = true, SpellNameFor = true, BuffName = true,
	IsTankUnit = true, Resting = true, InCity = true, InBattleground = true,
	HiddenWhileMounted = true, SnoozeLeft = true, GroupQuiet = true,
	IsBlocked = true, MarkAttempted = true, TimeText = true,
	CHANNEL_COMMANDS = true, MACRO_LIMIT = true, SyncMacroSlot = true,
	lastMacro = true, CanCastAnything = true, LOCALE = true,
	Battle = true, Beast = true, WindowLayout = true,
	ModuleActive = true, BeastArm = true, BeastLines = true,
}
local PET_WRITES = {
	Beast = true, BEAST_FOODS = true, BEAST_DIETS = true,
	BeastClamp = true, BeastArm = true, BeastLines = true,
	BuildQueue = true, lastMacro = true,
}

local MYBUFF_KEYS = {
	L = true, addon = true, db = true, plain = true, safecall = true,
	Guard = true, Trail = true, Flavour = true, Prompt = true,
	BUFF_BY_ID = true, OWN_BUFFS = true, OWN_BY_ID = true,
	BuildOwnLookups = true, FindOwnSpell = true, GetClassBuffs = true,
	BuffName = true, OwnFamilyLabel = true, OwnSpellKnown = true,
	ProbeCapabilities = true, RepaintOptions = true, IsPlayerName = true,
	SpellKnown = true, SpellNameFor = true, GetOwnFamilies = true,
	OwnPick = true, OwnVerdict = true, SelfWhenBuffed = true,
	SnoozeLeft = true, UnitFullName = true, ItemMacro = true,
	ItemsApart = true, SupplyEntry = true, StillCut = true,
	MarkAttempted = true, NoteScrollPress = true, OwnSkipSeconds = true,
	SkipOwn = true, AddSettingsLine = true, Looks = true, PaintedData = true,
	PETS = true, OptionsPage = true, WindowLayout = true,
	ConsumableAuras = true, FindOwnFamily = true, ForgetElixirClash = true,
	ForgetScrolls = true, GetOwnFamilies = true, HandName = true,
	HasScrollFamilies = true, HasShout = true, KnownOwnFamilies = true,
	OwnAutoPick = true, OwnLeaveable = true, ScrollsOff = true,
	SelfBuffs = true, Setup = true,
	OwnSpells = true, OwnSpellLines = true, Pet = true,
	ModuleActive = true,
	ReadPet = true, PetHold = true, PetFromJournal = true,
	PetJournalOwned = true, Supplies = true,
	ContextDecision = true, ContextTarget = true,
}
local MYBUFF_WRITES = {
	OwnSpells = true, OwnSpellLines = true, Pet = true,
	ReadPet = true, PetHold = true, PetFromJournal = true, PetJournalOwned = true,
	Supplies = true, ProbeCapabilities = true,
}

local SERVICE_KEYS = {
	L = true, addon = true, db = true, plain = true, safecall = true,
	Guard = true, Trail = true, Flavour = true, Prompt = true,
	BuffInfo = true, EntrySpellName = true, FirstName = true,
	ShortName = true, SameName = true, Ignored = true, IsBlocked = true,
	IsNeverOffered = true, MuteListed = true, IterateUnits = true,
	MarkAttempted = true, PRIORITY = true, PlayerClass = true,
	ReagentCount = true, ReagentName = true, SnoozeLeft = true,
	SpellKnown = true, SpellNameFor = true, TargetName = true,
	UnitFullName = true, standingRequests = true, WindowLayout = true,
	IsPlayerName = true, SavingMana = true, UnitHasMana = true, Courtesy = true,
	ContextDecision = true, ContextTarget = true,
}
local SERVICE_WRITES = { Courtesy = true }

-- The page draws its rows framed (WindowLayout's notes), repaints the window
-- when a count moves, and names the spells given for Varied Gifts.
local ACHIEVEMENT_KEYS = { L = true, addon = true, WindowLayout = true,
	RefreshOptionsDisplay = true, SpellNameFor = true, Achievements = true, WindowWidgets = true }
-- Its own reading of the list, for the tests and /manners debug.
local ACHIEVEMENT_WRITES = { Achievements = true }

local CONTEXTS = {
	combat = { keys = COMBAT_KEYS, writes = COMBAT_WRITES, title = "Manners: Combat" },
	pets = { keys = PET_KEYS, writes = PET_WRITES, title = "Manners: Pets" },
	mybuffs = { keys = MYBUFF_KEYS, writes = MYBUFF_WRITES, title = "Manners: My Buffs" },
	services = { keys = SERVICE_KEYS, writes = SERVICE_WRITES, title = "Manners: Services" },
	achievements = { keys = ACHIEVEMENT_KEYS, writes = ACHIEVEMENT_WRITES, title = "Manners: Achievements" },
}

-- A module sees a narrow facade of the core, not its private namespace. The
-- Combat facade is the only broad one today because its three secure buttons
-- intentionally share the prompt's layout, regions and click guard.
function api:ModuleContext(id)
	local context = moduleContexts[id]
	if context then return context end
	local spec = CONTEXTS[id]
	if not spec then return nil end
	context = setmetatable({}, {
		__index = function(_, key)
			if spec.keys[key] then return ns[key] end
		end,
		__newindex = function(_, key, value)
			if not spec.writes[key] then
				error(spec.title .. " cannot write core field " .. tostring(key), 2)
			end
			ns[key] = value
		end,
	})
	moduleContexts[id] = context
	return context
end

-- One module page: `build` returns an AceConfig page table; `layout` is the
-- Options/Window/Layout.lua page table. A module owns both, so the core never
-- imports its controls while it is absent.
function api:RegisterOptionsPage(id, build, layout, sidebarGroup)
	if type(id) ~= "string" or id == "" or type(build) ~= "function"
		or type(layout) ~= "table" then return false end
	local page = options[id]
	if page then page.build, page.layout = build, layout
	else page = { id = id, build = build, layout = layout } options[id] = page end
	if ns.WindowLayout and type(ns.WindowLayout.pages) == "table" then
		ns.WindowLayout.pages[id] = layout
		local groups = ns.WindowLayout.groups
		if type(groups) == "table" then
			local moduleGroup
			if sidebarGroup == "modules" then
				for _, group in ipairs(groups) do
					for _, page in ipairs(group) do
						if page == "modules" then moduleGroup = group break end
					end
					if moduleGroup then break end
				end
			end
			local side = sidebarGroup == "modules" and moduleGroup
				or sidebarGroup
			local present = false
			for _, group in ipairs(groups) do
				for _, page in ipairs(group) do
					if page == id then present = true break end
				end
				if present then break end
			end
			if not present then
				local group = type(side) == "table" and side or groups[side]
				if type(group) ~= "table" then
					group = {}
					groups[#groups + 1] = group
				end
				group[#group + 1] = id
			end
		end
		if event == "CoreReady" then
			-- The core's initial ProbeCapabilities just ran after every early-loaded
			-- module installed its wrappers. Mark those attachments without probing
			-- a second time; late addons take the probe branch in RegisterModule.
			for id in pairs(loaded) do attached[id] = true end
		end
	end
	if ns.RefreshModuleOptions then ns.RefreshModuleOptions() end
	return true
end

function api:OptionsPages()
	return options
end

-- Extra controls that belong to a page in the core. The module owns the
-- builder while the core keeps its page model and saved setting paths stable.
function api:RegisterOptionsExtension(tab, build)
	if type(tab) ~= "string" or tab == "" or type(build) ~= "function" then return false end
	optionExtensions[tab] = optionExtensions[tab] or {}
	optionExtensions[tab][#optionExtensions[tab] + 1] = build
	return true
end

function api:OptionsExtensions(tab)
	return optionExtensions[tab] or {}
end

function api:InsertLayoutItems(page, afterPath, items)
	local layout = ns.WindowLayout
	local target = layout and layout.pages and layout.pages[page]
	if type(target) ~= "table" or type(items) ~= "table" then return false end
	for _, section in ipairs(target.sections or {}) do
		for i, raw in ipairs(section.items or {}) do
			local path = type(raw) == "string" and raw or type(raw) == "table" and raw[1] or nil
			if path == afterPath then
				local at = i + 1
				for _, item in ipairs(items) do
					table.insert(section.items, at, item)
					at = at + 1
				end
				if ns.OptionsPage and ns.OptionsPage.ForgetPageMap then ns.OptionsPage.ForgetPageMap() end
				return true
			end
		end
	end
	return false
end

function api:AddLayoutSection(page, section)
	local layout = ns.WindowLayout
	local target = layout and layout.pages and layout.pages[page]
	if type(target) ~= "table" or type(section) ~= "table" then return false end
	for i, old in ipairs(target.sections or {}) do
		if old.key == section.key then
			target.sections[i] = section
			if ns.OptionsPage and ns.OptionsPage.ForgetPageMap then ns.OptionsPage.ForgetPageMap() end
			return true
		end
	end
	target.sections[#target.sections + 1] = section
	return true
end

-- A module may add one read-only tab to the favour ledger. The ledger owns the
-- frame and gives the module only its content area's private overlay contract.
function api:RegisterLedgerTab(id, label, paint)
	if type(id) ~= "string" or id == "" or type(label) ~= "string"
		or type(paint) ~= "function" or ledgerTabs[id] then
		return false
	end
	ledgerTabs[id] = { id = id, label = label, paint = paint }
	return true
end

function api:LedgerTabs()
	return ledgerTabs
end

-- A copy bounded for module consumption: the favour ledger's last N records,
-- never the private store or a live mutable row.
function api:RecentLedgerEntries(limit)
	local ledger = ns.Ledger
	if not (ledger and type(ledger.RecentForModules) == "function") then return {} end
	return ledger.RecentForModules(limit)
end

-- Register one optional class-service buff. Only Services may use this
-- surface, and only on the clients named by the definition.
function api:RegisterServiceBuff(id, definition)
	if id ~= "services" or type(definition) ~= "table" then return false end
	local flavour = ns.Flavour and ns.Flavour.flavour
	local allowed = type(definition.flavours) == "table" and definition.flavours[flavour] == true
	if not allowed or type(definition.class) ~= "string" or type(definition.buff) ~= "table" then return false end
	local buff = definition.buff
	buff.optionalService = id
	local list = ns.BUFFS and ns.BUFFS[definition.class]
	if type(list) ~= "table" or type(buff.key) ~= "string"
		or type(buff.ranks) ~= "table" or #buff.ranks == 0 then return false end
	for _, present in ipairs(list) do
		if present.key == buff.key then return false end
	end
	list[#list + 1] = buff
	for id, level in pairs(definition.levels or {}) do ns.RANK_LEVEL[id] = level end
	for _, id in ipairs(buff.ranks) do ns.SPELL_SECONDS[id] = definition.seconds or 180 end
	ns.BuildBuffLookups()
	if ns.db and type(ns.ProbeCapabilities) == "function" then
		ns.Guard("service buff registration", ns.ProbeCapabilities)
	end
	return true
end

function api:UnregisterServiceBuff(id, class, key)
	if id ~= "services" or type(class) ~= "string" or type(key) ~= "string" then return false end
	local list = ns.BUFFS and ns.BUFFS[class]
	if type(list) ~= "table" then return false end
	for i, buff in ipairs(list) do
		if buff.key == key and buff.optionalService == id then
			table.remove(list, i)
			ns.BuildBuffLookups()
			if ns.db and type(ns.ProbeCapabilities) == "function" then
				ns.Guard("service buff removal", ns.ProbeCapabilities)
			end
			return true
		end
	end
	return false
end

function api:NotePetBuffCast(unit, castGUID, spellID)
	if unit ~= "pet" or type(ns.PetCastLanded) ~= "function" then return false end
	ns.PetCastLanded(unit, castGUID, spellID)
	return true
end

function api:ForgetPetBuffs(id)
	if id == "services" and type(ns.ForgetPetSpells) == "function" then
		ns.ForgetPetSpells()
		return true
	end
	return false
end

function api:RegisterPetCastFrame(id, frame)
	if id ~= "services" or type(frame) ~= "table" then return false end
	if ns.petCastEvents then return true end
	ns.petCastEvents = frame
	return true
end

function api:RegisterModule(id, title)
	if type(id) ~= "string" or id == "" then return false end
	if loaded[id] then return true end
	loaded[id] = title
	if coreReady and not attached[id] then
		attached[id] = true
		-- Modules load after Manners' own dependency. Re-run the capability
		-- pass once, so wrappers installed by the module (own spells and
		-- break-free) and newly registered service buffs are visible to caps.
		if ns.db then
			ns.Guard("module attach " .. id, ns.ProbeCapabilities)
			api:Fire("ModuleAttached", id, title)
		end
	end
	api:Fire("ModuleLoaded", id, title)
	if ns.RepaintOptions then ns.RepaintOptions() end
	return true
end

function api:ModuleLoaded(id)
	return loaded[id] ~= nil
end

function ns.ModuleActive(id)
	local runtime = loaded[id] ~= nil
	if not runtime then return false end
	if pendingReload[id] ~= nil then return pendingReload[id] == true end
	return true
end

function api:LoadedModules()
	return loaded
end

local MODULE_FOLDERS = {
	combat = "Manners_Combat",
	achievements = "Manners_Achievements",
	pets = "Manners_Pets",
	mybuffs = "Manners_MyBuffs",
	services = "Manners_Services",
}

local function AddOnCharacter()
	local guid = type(_G.UnitGUID) == "function" and ns.plain(_G.UnitGUID("player")) or nil
	if type(guid) == "string" and guid ~= "" then return guid end
	return type(_G.UnitName) == "function" and ns.plain(_G.UnitName("player")) or nil
end

local function AddOnEnableState(folder, id)
	local chat = _G.C_AddOns
	if type(chat) == "table" and type(chat.GetAddOnEnableState) == "function" then
		local state = chat.GetAddOnEnableState(folder, AddOnCharacter())
		state = ns.plain(state)
		if type(state) == "number" then return state ~= 0 end
		return loaded[id] ~= nil
	end
	if type(GetAddOnEnableState) == "function" then
		local state = ns.plain(GetAddOnEnableState(UnitName("player") or "", folder))
		return type(state) == "number" and state ~= 0
	end
	if loaded[id] then return true end
	return false
end

local function LegacyMyBuffsActive(profile)
	local sources = type(profile) == "table" and profile.sources or nil
	return type(sources) == "table" and sources.self == true
end

local function LegacyCombatActive(profile)
	local prompt = type(profile) == "table" and profile.prompt or nil
	local beast = type(profile) == "table" and profile.beast or nil
	return type(prompt) == "table" and (prompt.breakFree == true or prompt.cureFight == true
			or prompt.reactiveWards == true)
		or type(beast) == "table" and beast.fightMend == true
end

local function LegacyServicesActive(profile)
	local sources = type(profile) == "table" and profile.sources or nil
	if sources and sources.courtesyTarget == true then return true end
	local buff = profile and profile.buff
	if buff and type(buff.optIn) == "table" and buff.optIn.fireshield == true then return true end
	local services = profile and profile.services
	if type(services) == "table" and sources and sources.asked == true then
		for _, config in pairs(services) do
			if type(config) == "table" and config.enabled == true then return true end
		end
	end
	if type(sources) ~= "table" or sources.asked ~= true then return false end
	for _, key in ipairs({
		"courtesyRefresh", "courtesyPortals", "courtesyHealthstones",
		"courtesySummons", "courtesySoulstone", "courtesySlowFall",
		"courtesyLevitate", "courtesyWaterWalking",
	}) do
		if sources[key] == true then return true end
	end
	return false
end

local function MigrationCharacter()
	local db = ns.db
	local keys = db and db.keys
	local key = type(keys) == "table" and ns.plain(keys.char) or nil
	if type(key) == "string" and key ~= "" then return key end
	local name = type(UnitName) == "function" and ns.plain(UnitName("player")) or nil
	return type(name) == "string" and name ~= "" and name or nil
end

local function MigrationDone(profile, marker, character)
	local characters = profile[marker]
	return type(characters) == "table" and characters[character] == true
end

local function MarkMigration(profile, marker, character)
	local characters = profile[marker]
	if type(characters) ~= "table" then
		characters = {}
		profile[marker] = characters
	end
	characters[character] = true
end

-- A folder's game-level addon state is separate from an AceDB profile. Do this
-- only for profiles that existed before the folders shipped, then leave an
-- explicit marker for this character/profile pair so another character using
-- the shared profile is reconciled too, while a later intentional disable is
-- never undone.
function api:MigrateOptionalModules(legacyProfile)
	local profile = api:GetProfile()
	if type(profile) ~= "table" then return false end
	local character = MigrationCharacter()
	if not character then return false end
	local changed = false
	local modulesDone = MigrationDone(profile, "optionalModulesMigratedCharacters", character)
	local combatDone = MigrationDone(profile, "optionalCombatMigratedCharacters", character)
	local modulesReady, combatReady = true, true
	if legacyProfile == true and not modulesDone then
		if LegacyMyBuffsActive(profile) then
			changed = api:SetModuleEnabled("mybuffs", true) or changed
			modulesReady = api:IsModuleEnabled("mybuffs")
		end
		if LegacyServicesActive(profile) then
			changed = api:SetModuleEnabled("services", true) or changed
			modulesReady = modulesReady and api:IsModuleEnabled("services")
		end
	end
	if legacyProfile == true and not combatDone then
		if LegacyCombatActive(profile) then
			changed = api:SetModuleEnabled("combat", true) or changed
			combatReady = api:IsModuleEnabled("combat")
		end
	end
	if not modulesDone and modulesReady then
		MarkMigration(profile, "optionalModulesMigratedCharacters", character)
		modulesDone = true
	end
	if not combatDone and combatReady then
		MarkMigration(profile, "optionalCombatMigratedCharacters", character)
		combatDone = true
	end
	if modulesDone then profile.optionalModulesMigrated = true end
	if combatDone then profile.optionalCombatMigrated = true end
	return changed
end

function api:IsModuleEnabled(id)
	if pendingReload[id] ~= nil then return pendingReload[id] end
	local folder = MODULE_FOLDERS[id]
	if not folder then return false end
	local state = AddOnEnableState(folder, id)
	if state ~= nil then return state end
	return loaded[id] ~= nil
end

-- Enabling an unloaded addon only changes what the next reload starts, so it is
-- safe in combat. A loaded addon's immediate suspension can involve secure
-- frames, which waits until combat ends.
function api:CanToggleModule(id)
	if type(id) ~= "string" or not MODULE_FOLDERS[id] then return false end
	return not InCombatLockdown() or loaded[id] == nil
end

function api:SetModuleEnabled(id, enabled)
	if not api:CanToggleModule(id) then return false end
	local folder = MODULE_FOLDERS[id]
	if not folder then return false end
	local wasActive = api:ModuleActive(id)
	enabled = enabled == true
	if AddOnEnableState(folder, id) == enabled then
		pendingReload[id] = enabled == (loaded[id] ~= nil) and nil or enabled
		local active = api:ModuleActive(id)
		if active ~= wasActive then
			SetModuleActive(id, active)
		end
		if ns.RepaintOptions then ns.RepaintOptions() end
		return false
	end
	local chat = _G.C_AddOns
	local changed = false
	if enabled then
		if type(chat) == "table" and type(chat.EnableAddOn) == "function" then
			chat.EnableAddOn(folder, AddOnCharacter())
			changed = true
		elseif type(EnableAddOn) == "function" then
			EnableAddOn(folder)
			changed = true
		end
	else
		if type(chat) == "table" and type(chat.DisableAddOn) == "function" then
			chat.DisableAddOn(folder, AddOnCharacter())
			changed = true
		elseif type(DisableAddOn) == "function" then
			DisableAddOn(folder)
			changed = true
		end
	end
	if not changed then return false end
	if enabled == (loaded[id] ~= nil) then
		pendingReload[id] = nil
	else
		pendingReload[id] = enabled
	end
	local active = api:ModuleActive(id)
	if active ~= wasActive then
		SetModuleActive(id, active)
	end
	if ns.RepaintOptions then ns.RepaintOptions() end
	return true
end

function api:ModuleReloadPending()
	for id, enabled in pairs(pendingReload) do
		if enabled ~= nil then return true end
	end
	return false
end

function api:ModuleSummary()
	local names = {}
	for _, module in ipairs(KNOWN) do names[#names + 1] = module.title end
	return table.concat(names, ", ")
end

function api:ModuleActive(id)
	return ns.ModuleActive(id)
end

function api:ModuleWelcomeOpen()
	return moduleWelcomeOpen
end

function api:DismissModuleWelcome()
	local token = moduleWelcomeToken
	if not token or api:GetProfile() ~= token.profile or token.presented ~= true then return false end
	moduleWelcomeOpen = false
	moduleWelcomeToken = nil
	token.profile.moduleWelcome1125 = true
	if ns.RepaintOptions then ns.RepaintOptions() end
	return true
end

-- 1.12.5 is the one release that explains the new default-on folders. Once
-- per profile, after login, open the chooser. The marker is written only when
-- the window was actually presented, and a delayed callback belongs to the
-- profile that scheduled it even if the player switches profiles meanwhile.
do
	local frame = CreateFrame("Frame")
	local serial = 0

	local function ProfileName()
		local db = ns.db
		local current = db and db.GetCurrentProfile
		local name = type(current) == "function" and ns.safecall(current, db) or nil
		name = ns.plain(name)
		return type(name) == "string" and name or nil
	end

	local function CurrentToken(token)
		return _G.MannersAPI == api and moduleWelcomeToken == token and api:GetProfile() == token.profile
			and (token.profileName == nil or ProfileName() == token.profileName)
	end

	local function Attempt(token)
		if not CurrentToken(token) or token.profile.moduleWelcome1125 == true then
			if moduleWelcomeToken == token then
				moduleWelcomeToken, moduleWelcomeOpen = nil, false
			end
			return false
		end
		if InCombatLockdown() then return false end
		local opened = type(ns.OpenOptions) == "function"
		moduleWelcomeOpen = true
		opened = opened and ns.Guard("module chooser", ns.OpenOptions, "modules", true)
		if not opened or not CurrentToken(token) then
			moduleWelcomeOpen = false
			return false
		end
		token.presented, moduleWelcomeOpen = true, true
		token.profile.moduleWelcome1125 = true
		if ns.RepaintOptions then ns.RepaintOptions() end
		return true
	end

	local function Schedule()
		local profile = api:GetProfile()
		if type(profile) ~= "table" or profile.moduleWelcome1125 == true then return end
		local old = moduleWelcomeToken
		if old and old.profile == profile and old.presented ~= true then return end
		serial = serial + 1
		local token = { serial = serial, profile = profile, profileName = ProfileName() }
		moduleWelcomeToken, moduleWelcomeOpen = token, false
		local later = _G.C_Timer and _G.C_Timer.After
		if type(later) == "function" then later(1, function() Attempt(token) end)
		else Attempt(token)
		end
	end

	api:RegisterCallback("ProfileChanged", Schedule)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, _, initial, reload)
		if initial == true or reload == true then Schedule()
		elseif moduleWelcomeToken then Attempt(moduleWelcomeToken)
		end
	end)
end
