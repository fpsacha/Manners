-- The ledger window's states for tools/render_ledger.py, and the addon loaded
-- to draw them.
--
-- The same arrangement as render_prompt.lua: each state is the addon on the
-- mock client with a ledger filled through Ledger.lua's own entry points -- the
-- calls Core makes when a favour arrives, is repaid, is let go or a buff goes
-- out unprompted -- and the window opened as /manners ledger opens it. Nothing
-- here paints; the renderer draws what the frames were told.
--
-- What this file does supply is what a real client would and the mock does
-- not: every class's colour, each spell its own icon, and the spell names in
-- the client's language, because a German client names Arcane Intellect in
-- German and a row that only fits in English does not fit.

-- `dir` holds the mock and the recorder; `addonDir` the addon being drawn, which
-- differs when an older build is drawn with today's renderer. `measure`, when
-- given, is the renderer's own text measure, so what the addon is told a string
-- is as wide as is what the picture draws.
local dir, addonDir, measure = ...
addonDir = addonDir or dir

dofile(dir .. "/tests/mockapi.lua")
dofile(dir .. "/tests/frametree.lua")

local R = {}
local FILES = dofile(dir .. "/tests/addonfiles.lua")(addonDir)

-- The client's class colours (RAID_CLASS_COLORS), which the mock has only two
-- of. Kept to what a Camelot client hands out.
local CLASS_COLORS = {
	WARRIOR = "ffc69b6d", PALADIN = "fff48cba", HUNTER = "ffaad372", ROGUE = "fffff468",
	PRIEST = "ffffffff", SHAMAN = "ff0070dd", MAGE = "ff3fc7eb", WARLOCK = "ff8788ee",
	DRUID = "ffff7c0a",
}

-- Spell names as each client would give them. Only the spells the states use.
local SPELL_NAMES = {
	enUS = {
		[1459] = "Arcane Intellect", [21562] = "Power Word: Fortitude", [27841] = "Divine Spirit",
		[10958] = "Shadow Protection", [1126] = "Mark of the Wild", [20217] = "Blessing of Kings",
		[6673] = "Battle Shout", [19740] = "Blessing of Might",
	},
	deDE = {
		[1459] = "Arkane Intelligenz", [21562] = "Machtwort: Seelenstärke",
		[27841] = "Göttlicher Willen", [10958] = "Schattenschutz", [1126] = "Mal der Wildnis",
		[20217] = "Segen der Könige", [6673] = "Schlachtruf", [19740] = "Segen der Macht",
	},
	ruRU = {
		[1459] = "Чародейский интеллект", [21562] = "Слово силы: Стойкость",
		[27841] = "Божественный дух", [10958] = "Защита от темной магии",
		[1126] = "Знак дикой природы", [20217] = "Благословение королей",
		[6673] = "Боевой крик", [19740] = "Благословение могущества",
	},
}
-- Each spell's own icon file id, which the renderer draws as a tile in the
-- spell's colours. The mock answers Arcane Intellect's for everything.
local SPELL_ICONS = {
	[1459] = 135932, [21562] = 135987, [27841] = 135898, [10958] = 136121,
	[1126] = 136078, [20217] = 135995, [6673] = 132333, [19740] = 135906,
}

local installed = {}

-- The client's pieces the mock lacks, put in for one state and taken out after.
local function client(locale)
	installed.colors = RAID_CLASS_COLORS
	local colors = {}
	for class, str in pairs(CLASS_COLORS) do colors[class] = { colorStr = str } end
	RAID_CLASS_COLORS = colors
	local names = SPELL_NAMES[locale or "enUS"] or SPELL_NAMES.enUS
	local base = C_Spell
	local spell = {}
	for k, v in pairs(base or {}) do spell[k] = v end
	spell.GetSpellName = function(id) return names[id] or SPELL_NAMES.enUS[id] or base.GetSpellName(id) end
	spell.GetSpellTexture = function(id) return SPELL_ICONS[id] or 135932 end
	rawset(_G, "C_Spell", spell)
	installed.spell = true
end

local function unclient()
	if installed.colors then RAID_CLASS_COLORS = installed.colors end
	if installed.spell then rawset(_G, "C_Spell", nil) end
	installed = {}
end

-- The recording CreateFrame, with every font string made measurable by the
-- renderer's own font -- the mock's estimate counts bytes, which makes a
-- Cyrillic word twice as wide as it is -- and able to take a cap on its lines.
local function measurable()
	if not measure then return end
	local create = CreateFrame
	local function wrap(f)
		local make = f.CreateFontString
		f.CreateFontString = function(self, ...)
			local fs = make(self, ...)
			fs.GetStringWidth = function(s)
				local size = s._font and s._font.size or 12
				return measure(tostring(s._text or ""), size)
			end
			fs.GetUnboundedStringWidth = fs.GetStringWidth
			-- The client's cap on wrapped lines, which the mock has no slot for.
			fs.SetMaxLines = function(s, n) s._maxLines = n return s end
			return fs
		end
		return f
	end
	CreateFrame = function(...) return wrap(create(...)) end
	wrap(UIParent)
end

local function load(locale)
	Mock.reset()
	Mock.locale = locale
	FrameTree.uninstall()
	FrameTree.install()
	measurable()
	client(locale)
	local ns = {}
	for _, file in ipairs(FILES) do
		local chunk, err = loadfile(addonDir .. "/" .. file)
		if not chunk then error("load " .. file .. ": " .. tostring(err)) end
		chunk("Manners", ns)
	end
	return ns
end

local function boot(ns)
	Mock.unitNames = {}
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.runTimers(3)
	Mock.advance(60)
	wipe(ns.owed)
	ns.db.char.ledger = nil
	ns.Ledger.Load()
	return ns
end

local function received(ns, name, class, spell)
	ns.Ledger.Received({ name = name, class = class, key = spell })
end

local function returned(ns, name, ago)
	ns.Ledger.Settled(name, { at = GetTime() - ago }, { buffKey = "intellect" }, 1459)
end

local function gave(ns, name, class, inGroup, spell)
	ns.Ledger.Settled(name, nil, { inGroup = inGroup, class = class }, spell or 1459)
end

-- Days of ordinary play, oldest first: every state a favour can end in, gifts to
-- the group and to strangers, a long name, a name with a realm, a favour of
-- three buffs, and enough rows that the list scrolls.
local STRANGERS = {
	{ "Brannoc Vale", "WARRIOR" }, { "Corwin Ash", "HUNTER" }, { "Delphine Moor", "WARLOCK" },
	{ "Esk Tallow", "ROGUE" }, { "Fenna Greaves", "SHAMAN" }, { "Garrick Holt", "PALADIN" },
	{ "Hesper Lune", "DRUID" }, { "Ivo Brand", "MAGE" }, { "Jory Welk", "PRIEST" },
}

local function busy(ns)
	local day = 86400
	received(ns, "Oriel Dawnwhisper", "PRIEST", 21562)
	Mock.advance(130)
	ns.Ledger.LetGo("Oriel Dawnwhisper")
	Mock.advance(day + 3000)
	received(ns, "Tamsin Reed", "DRUID", 1126)
	Mock.advance(600)
	ns.Ledger.LetGo("Tamsin Reed", "notkept")
	Mock.advance(3 * 3600)
	for i, who in ipairs(STRANGERS) do
		gave(ns, who[1], who[2], false)
		Mock.advance(i % 3 == 0 and 1900 or 240)
	end
	received(ns, "Maximiliana Featherstonehaugh-Worthington", "PALADIN", 20217)
	Mock.advance(40)
	ns.Ledger.LetGo("Maximiliana Featherstonehaugh-Worthington", "never")
	Mock.advance(2 * 3600)
	received(ns, "Hild Ironbraid-Stormrage", "PALADIN", 19740)
	Mock.advance(35)
	returned(ns, "Hild Ironbraid-Stormrage", 35)
	Mock.advance(900)
	gave(ns, "Gwen Hollow", "WARRIOR", true)
	Mock.advance(20)
	gave(ns, "Pim Lightfoot", "ROGUE", true)
	Mock.advance(1500)
	ns.Ledger.Received({ name = "Brannoc Vale", class = "WARRIOR", key = 6673 }, true)
	Mock.advance(700)
	received(ns, "Anna Aim", "PRIEST", 21562)
	Mock.advance(2)
	received(ns, "Anna Aim", "PRIEST", 27841)
	Mock.advance(2)
	received(ns, "Anna Aim", "PRIEST", 10958)
	Mock.advance(480)
	ns.Ledger.Received({ name = "Korg Bloodfist", class = "WARRIOR", key = 6673 }, nil, true)
	Mock.advance(20)
end

-- A short list: somebody owed and somebody repaid a minute ago.
local function few(ns)
	received(ns, "Hild Ironbraid-Stormrage", "PALADIN", 19740)
	Mock.advance(40)
	returned(ns, "Hild Ironbraid-Stormrage", 40)
	Mock.advance(50)
	received(ns, "Anna Aim", "PRIEST", 21562)
	Mock.advance(10)
end

local function open(ns, tab)
	ns.addon:HandleSlash("ledger")
	local window = ns.Ledger.Window()
	for _, t in ipairs(window and window.tabs or {}) do
		if t.key == tab and t.scripts.OnClick then t.scripts.OnClick(t) end
	end
	return window
end

R.states = {
	{ key = "all", title = "Everything", setup = function(ns) busy(ns) open(ns, "all") end },
	{ key = "favours", title = "Favours", setup = function(ns) busy(ns) open(ns, "favours") end },
	{ key = "given", title = "Buffs you gave", setup = function(ns) busy(ns) open(ns, "given") end },
	{ key = "scrolled", title = "Everything, scrolled to the end", setup = function(ns)
		busy(ns)
		open(ns, "all")
		ns.Ledger.Scroll(100)
	end },
	{ key = "few", title = "Two rows", setup = function(ns) few(ns) open(ns, "all") end },
	{ key = "empty", title = "Nothing yet", setup = function(ns) open(ns, "all") end },
	{ key = "empty-given", title = "Nothing given yet", setup = function(ns)
		few(ns)
		open(ns, "given")
	end },
	{ key = "empty-off", title = "Switched off", setup = function(ns)
		ns.db.profile.enabled = false
		open(ns, "all")
	end },
}

function R.find(key)
	for _, s in ipairs(R.states) do
		if s.key == key then return s end
	end
end

function R.keys()
	local out = {}
	for i, s in ipairs(R.states) do out[i] = s.key end
	return out
end

-- One state in one language, drawn: the tree under UIParent and the window's id
-- so the picture can be framed on it.
function R.run(key, locale)
	local state = R.find(key)
	if not state then return nil end
	local ns = load(locale)
	local ok, err = pcall(function()
		boot(ns)
		state.setup(ns)
		-- Past the window's fade-in, and every one-shot animation settled.
		Mock.advance(1)
		FrameTree.settle()
	end)
	local window = ns.Ledger and ns.Ledger.Window()
	-- Whether each string wraps, which the recorder keeps and its snapshot
	-- leaves out: the prompt never wraps a line, and the ledger's empty-list
	-- message is nothing but wrapping.
	local tree = FrameTree.snapshot(UIParent)
	local bySerial = {}
	for _, r in ipairs(FrameTree.all) do bySerial[r._serial] = r end
	for _, entry in ipairs(tree) do
		local r = bySerial[entry.id]
		if r and r._wordWrap ~= nil then entry.wordWrap = r._wordWrap end
		if r and r._maxLines ~= nil then entry.maxLines = r._maxLines end
	end
	local out = {
		tree = tree,
		window = window and window._serial,
		now = Mock.now,
		title = state.title,
		screen = { width = 1600, height = Mock.screenHeight or 1000 },
		errors = ns.errors and #ns.errors or 0,
		firstError = ns.errors and ns.errors[1] and (tostring(ns.errors[1].where) .. " -> "
			.. tostring(ns.errors[1].err)) or nil,
	}
	unclient()
	if not ok then error("state " .. key .. ": " .. tostring(err)) end
	return out
end

return R
