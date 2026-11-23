-- Manners -- options window: the page in the content area. Its sections and
-- rows, which of them show, pairs and columns measured in the
-- player's language, the folds and their gold dots.
--
-- Each page's rows are built the first time it is opened and kept: switching
-- pages hides one set and shows another, and a repaint re-reads values and
-- moves rows, never rebuilds them, so a slider being dragged or a box being
-- typed in is never pulled out from under the player.

local _, ns = ...
local UI = ns.WindowUI

local PAD_LEFT, PAD_TOP, PAD_BOTTOM = 18, 14, 26
-- The page's width: the window's, less the sidebar, the bar and the padding.
-- Worked out again at every layout, since the window can be resized
-- (Window.lua, UI.Resized).
local function ContentWidth() return UI.WIDTH - UI.SIDEBAR - 13 - PAD_LEFT - 17 end
local CONTENT_W = ContentWidth()
local GAP, ROW_GAP, SECTION_GAP, INDENT = 18, 6, 10, 16
-- Columns: a page wide enough for two columns of MIN_COLUMN flows its sections
-- into two, and into three when there is room for three (UI.ColumnsFor). The
-- usual 820 window is one column of 612, as it always was. COLUMN_W is the
-- width of the column being laid out, the page's own while there is one.
-- A page with fewer sections than columns does not stretch them past
-- MAX_COLUMN: a line of text that long is hard to read back.
local COLUMN_GAP, MIN_COLUMN, MAX_COLUMN, MAX_COLUMNS = 28, 420, 760, 3
local COLUMN_W = CONTENT_W
-- Every row placed in the paint under way carries its number, so the columns
-- move only what this paint laid out.
local stamp = 0
local C = UI.C

-- path -> { page, sec, e }, for every placed control and note
local where = {}
local models = {}
-- While a sub-division is in view (Layout.lua, `subpages`), its folds are
-- drawn open under their titles, with no caption over them.
local flat = false
local NONE = {}
-- page id -> the key of the sub-division last chosen on it, for the session
-- (a /reload forgets it); nil is All, the whole page.
UI.subOf = UI.subOf or {}

---------------------------------------------------------------------------
-- the page model: sections and entries, no frames
---------------------------------------------------------------------------

local function KindOf(item, entry)
	if entry.composite then return entry.composite end
	if entry.widget then return entry.widget end
	local t = item.def.type
	if t == "input" and item.def.multiline then return "multiline" end
	return t
end

local function IsNote(item)
	local t = item.def.type
	return t == "description" or t == "header"
end

-- A placed item's layout entry, with how the layout draws it as a note (its
-- `notes` table: grey, or a grey block) folded into a copy.
local function EntryLayout(raw)
	local entry = type(raw) == "table" and raw or { raw }
	local look = type(entry[1]) == "string" and (UI.Layout().notes or {})[entry[1]]
	if type(look) ~= "table" then return entry end
	local out = {}
	for k, v in pairs(entry) do out[k] = v end
	for k, v in pairs(look) do out[k] = v end
	return out
end

-- One placed item: a control or a note, or the never-offer composite, which
-- is one row built from several definitions.
local function Entry(raw, sec)
	local entry = EntryLayout(raw)
	local e = { layout = entry, sec = sec }
	if entry.composite then
		e.subs = {}
		for _, path in ipairs(entry.ids or {}) do
			local sub = UI.Item(path, entry)
			if sub then e.subs[#e.subs + 1] = sub end
		end
		if #e.subs == 0 then return nil end
		e.item, e.path, e.kind, e.isControl = e.subs[1], e.subs[1].path, entry.composite, true
		return e
	end
	e.path = entry[1]
	e.item = UI.Item(e.path, entry)
	if not e.item then return nil end
	e.kind = KindOf(e.item, entry)
	e.isControl = not IsNote(e.item)
	e.standIn = entry.standIn and true or false
	return e
end

-- How many steps in the layout indents a row: `indent = true` one, `indent =
-- 2` two (a choice that belongs to a switch which is itself indented).
local function Level(e)
	local n = e.layout.indent
	if not n then return 0 end
	return n == true and 1 or tonumber(n) or 1
end

-- The page's sub-divisions from the layout's `subpages`: each the sections
-- it names, in the page's order, each section in one at most (sec.sub). A key
-- the page does not have is passed over; an entry left with none is dropped.
local function Subdivide(m)
	m.subs = {}
	local byKey = {}
	for _, sec in ipairs(m.sections) do byKey[sec.key] = sec end
	for _, def in ipairs(m.page and m.page.subpages or {}) do
		local sub = { def = def, key = def[1], secs = {}, page = m.id }
		for _, key in ipairs(def) do
			local sec = byKey[key]
			if sec and not sec.sub then sec.sub = sub end
		end
		for _, sec in ipairs(m.sections) do
			if sec.sub == sub then sub.secs[#sub.secs + 1] = sec end
		end
		if #sub.secs > 0 then m.subs[#m.subs + 1] = sub end
	end
end

-- A page's sections and entries, made once. Controls the model does not have
-- for this character are left out.
function UI.Model(id)
	local m = models[id]
	if m then return m end
	local page = UI.Layout().pages[id]
	m = { id = id, page = page, sections = {} }
	for si, s in ipairs(page and page.sections or {}) do
		local sec = { def = s, key = s.key or (id .. "." .. si), fold = s.fold and true or false,
			entries = {}, hasControls = false, page = id }
		sec.span = (UI.Layout().spans or {})[sec.key] and true or false
		sec.headerItem = UI.Item(s.header)
		for _, raw in ipairs(s.items or {}) do
			local e = Entry(raw, sec)
			if e then
				-- What the row is indented under: the nearest row above it that
				-- is further out (UnderOff).
				e.level = Level(e)
				for k = #sec.entries, 1, -1 do
					if e.level == 0 then break end
					if sec.entries[k].level < e.level then
						e.parent = sec.entries[k]
						break
					end
				end
				sec.entries[#sec.entries + 1] = e
				sec.hasControls = sec.hasControls or e.isControl
				where[e.path] = { page = id, sec = sec, e = e }
				for _, sub in ipairs(e.subs or {}) do
					where[sub.path] = where[sub.path] or { page = id, sec = sec, e = e }
				end
			end
		end
		m.sections[#m.sections + 1] = sec
	end
	Subdivide(m)
	models[id] = m
	return m
end

-- Which page a control is placed on.
function UI.PageOf(path)
	if not where[path] then
		for id in pairs(UI.Layout().pages) do UI.Model(id) end
	end
	local w = where[path]
	return w and w.page or nil
end

function UI.Where(path)
	UI.PageOf(path)
	return where[path]
end

-- A switch's value as the window reads any; one that throws reads as on, so
-- nothing is hidden on the strength of a rule that failed.
local function SwitchedOff(item)
	local ok, value = pcall(ns.WindowBind.Value, item)
	return ok and value ~= true
end

-- The switch a row is indented under, while that switch is off and has made
-- the row useless: a sub-option is not drawn under a switch that is off, where
-- it used to stand greyed out. Going by the layout's indents, up through every
-- row it is under (a choice under a dropdown under a switch): the first switch
-- on the way that is on screen and off. A control goes only while its own rule
-- greys it too -- the model decides what a switch governs, so the pause before
-- a /thank stays while the whisper that shares it is on -- and a note goes
-- with its switch.
local function UnderOff(e)
	if not e.parent or e.subs then return nil end
	if e.isControl and not UI.Disabled(e.item) then return nil end
	local p = e.parent
	while p do
		if p.kind == "toggle" and not UI.Hidden(p.item) and SwitchedOff(p.item) then return p end
		p = p.parent
	end
	return nil
end

-- Whether an entry is shown by its own rules and its tab's. A composite is
-- shown while any of its controls is. A rule that throws hides its entry
-- (UI.Hidden).
local function ShownByModel(e)
	if e.subs then
		for _, sub in ipairs(e.subs) do
			if not IsNote(sub) and not UI.Hidden(sub) then return true end
		end
		return false
	end
	return not UI.Hidden(e.item)
end

-- Whether the simple view leaves an entry out: on, the page not one drawn
-- whole, and the entry (for a composite, every control of it) not on the
-- short list (Layout.lua, `simple`). Never the view's own lines.
local function SimpleHides(e)
	if e.chrome or ns.MenuView() ~= "simple" then return false end
	local simple = UI.Layout().simple
	if type(simple) ~= "table" or (simple.pages or {})[e.sec.page] then return false end
	local keep = simple.items or {}
	if e.subs then
		for _, sub in ipairs(e.subs) do
			if keep[sub.path] then return false end
		end
		return true
	end
	return not keep[e.path]
end

-- ...and by the window's: on the short list while the simple view is on, and
-- not under a switch that is off. `bySimple` says a control the model shows
-- was left out by the view, for the count under the page.
local function Shown(e)
	e.bySimple = false
	if not ShownByModel(e) then return false end
	if SimpleHides(e) then
		e.bySimple = e.isControl
		return false
	end
	return UnderOff(e) == nil
end
UI.EntryShown = Shown

-- Whether a control is one the simple view is leaving out now.
function UI.HiddenBySimple(path)
	local w = UI.Where(path)
	return w ~= nil and ShownByModel(w.e) and SimpleHides(w.e)
end

-- Whether the simple view would leave a control out, shown by its own rule
-- or not: for a search result that leads to it through its switch.
function UI.OffShortList(path)
	local w = UI.Where(path)
	return w ~= nil and SimpleHides(w.e)
end

-- The switch to turn on first for a control the model shows and the window
-- does not draw (UnderOff), or nil: for the search, which finds the control
-- and opens its switch.
function UI.SwitchFor(path)
	local w = UI.Where(path)
	if not w or w.e.path ~= path or not ShownByModel(w.e) then return nil end
	local p = UnderOff(w.e)
	return p and p.item or nil
end

-- A page is in the sidebar while one of its controls is shown. Notes never
-- keep it there, and their rules are never asked for a page not open.
function UI.PageVisible(id)
	for _, sec in ipairs(UI.Model(id).sections) do
		for _, e in ipairs(sec.entries) do
			if e.isControl and ShownByModel(e) then return true end
		end
	end
	return false
end

-- The note rule: a section shows while a control in it does. A
-- note keeps it only when it stands in for a hidden control, or when the
-- section holds no controls at all; any other note is attached and never
-- keeps a section by itself.
local function Judge(sec)
	local control, standIn, note = false, false, false
	for _, e in ipairs(sec.entries) do
		e.visible = Shown(e)
		if e.visible then
			if e.isControl then
				control = true
			elseif e.standIn then
				standIn = true
			else
				note = true
			end
		end
	end
	sec.visible = control or standIn or (note and not sec.hasControls)
	return sec.visible
end

---------------------------------------------------------------------------
-- the gold dot on a fold: something inside differs from default
---------------------------------------------------------------------------

-- The profile fields each foldable control writes. Only controls shown now
-- count, so a reason text a hunter cannot see does not light the dot.
local FIELDS = {
	["who.target"] = { { "priority", "target" } },
	["who.friends"] = { { "priority", "friends" } },
	["who.readyCheck"] = { { "priority", "readyCheck" } },
	["who.revived"] = { { "priority", "revived" } },
	-- Other people's buffs (Who to buff).
	["who.leaveBlessed"] = { { "buff", "leaveBlessed" } },
	["who.ownHoldMoving"] = { { "ownBuffs", "holdMoving" } },
	["who.ownFoodOutside"] = { { "ownBuffs", "foodOutside" } },
	["who.spareFishBowl"] = { { "buff", "spareFishBowl" } },
	["who.neverFishBowl"] = { { "buff", "neverFishBowl" } },
	["who.spareCamp"] = { { "buff", "spareCamp" } },
	["advanced.retryCooldown"] = { { "timing", "retryCooldown" } },
	["advanced.skipSeconds"] = { { "timing", "skipSeconds" } },
	["advanced.ownSkipMinutes"] = { { "timing", "ownSkipMinutes" } },
	["advanced.scanInterval"] = { { "timing", "scanInterval" } },
	["advanced.restoreTarget"] = { { "filters", "restoreTarget" } },
	["advanced.x"] = { { "prompt", "x" }, { "prompt", "point" }, { "prompt", "relPoint" } },
	["advanced.y"] = { { "prompt", "y" }, { "prompt", "point" }, { "prompt", "relPoint" } },
}
for _, key in ipairs({ "format", "reasonTarget", "reasonOwed", "reasonAsked", "reasonSelf", "reasonGroup",
	"reasonNearby", "reasonRefresh", "reasonUnknown" }) do
	FIELDS["advanced." .. key] = { { "prompt", key } }
end
for _, key in ipairs({ "font", "fontSize", "fontColor", "classColor", "showSub", "showIcon", "iconSize",
	"roundIcon", "iconFrame", "textShadow", "showCooldown", "showCount", "showQueue", "queueRows", "clickRows",
	-- Look's Tooltip and This window, folds since 1.12.
	"tooltip", "tooltipPosition", "peekOnChange" }) do
	FIELDS["appearance." .. key] = { { "prompt", key } }
end
-- The buttons for the moment: a switch each and the shares of health and mana. Their
-- key boxes have no default and so no mark.
for _, key in ipairs({ "counterspell", "spellsteal", "blink", "iceblock", "coldsnap", "evocation", "managem",
	"drink", "slowfall", "fireward", "frostward", "purge", "dispel", "tranq", "shieldslam" }) do
	FIELDS["appearance.moment" .. key:sub(1, 1):upper() .. key:sub(2)] = { { "moments", key } }
end
FIELDS["appearance.momentHealth"] = { { "moments", "health" } }
FIELDS["appearance.momentMana"] = { { "moments", "mana" } }
FIELDS["appearance.momentCardSize"] = { { "moments", "cardSize" } }
-- Look's colours (Style), a fold too: its dot says a colour is not the look's own.
for _, key in ipairs({ "bgColor", "accentByReason", "accentMode", "accentColor" }) do
	FIELDS["appearance." .. key] = { { "prompt", key } }
end
-- The pane's width and height, in Exact position's fold with where it sits.
for _, key in ipairs({ "width", "height" }) do
	FIELDS["appearance." .. key] = { { "prompt", key } }
end

local function Profile() return ns.db.profile end

-- The food family's spell keys: ownBuffs.leave holds the ticks of both Never
-- remind me about lists, the food's (who.own_leave_food) and the rest's.
local function FoodKeys()
	local keys = {}
	for _, family in ipairs(ns.GetOwnFamilies and ns.GetOwnFamilies() or {}) do
		if family.food then
			for _, spell in ipairs(family.spells or {}) do keys[spell.key] = true end
		end
	end
	return keys
end

local function AnyTicked(ticks, only)
	for key, on in pairs(type(ticks) == "table" and ticks or {}) do
		if on == true and (only == nil or only[key]) then return true end
	end
	return false
end

-- The line set, by its definition rather than what the box shows: a set
-- other than Role-play, or the box no longer holding the set's own lines.
local function LinesChanged()
	local speech = Profile().speech
	local choice = speech.presetChoice or "roleplay"
	if choice ~= "roleplay" then return true end
	return ns.PhraseSetText ~= nil and speech.phrases ~= ns.PhraseSetText(choice)
end

-- Controls whose shown value is computed: a later layout that folds one
-- must use these, never the value the control displays.
-- Whether this class has a cure saved on a modifier (prompt.cureFightMods).
local function CureModSaved(mod)
	local by = Profile().prompt.cureFightMods
	local mine = type(by) == "table" and ns.caps.class and by[ns.caps.class] or nil
	return type(mine) == "table" and mine[mod] ~= nil
end

local DIFFERS = {
	["appearance.posPreset"] = function() return ns.CurrentPositionPreset() ~= "bars" end,
	["general.quickWho"] = function() return ns.QuickSetup.Match(ns.QuickSetup.WHO) ~= "nearby" end,
	["general.quickVoice"] = function() return ns.QuickSetup.Match(ns.QuickSetup.VoiceList()) ~= "silent" end,
	["who.choice"] = function() return Profile().buff.choice ~= "auto" end,
	["who.skipRaidGroups"] = function() return next(Profile().filters.skipRaidGroups or {}) ~= nil end,
	["who.skipNearbyClasses"] = function() return next(Profile().filters.skipNearbyClasses or {}) ~= nil end,
	["who.own_leave"] = function()
		local foods = FoodKeys()
		for key, on in pairs(Profile().ownBuffs.leave or {}) do
			-- A food's tick is the food list's change, not this one's.
			if foods[key] then on = false end
			if on == true then return true end
		end
		return false
	end,
	["who.own_leave_food"] = function() return AnyTicked(Profile().ownBuffs.leave, FoodKeys()) end,
	["who.own_elixirkeep"] = function() return AnyTicked(Profile().ownBuffs.elixirKeep) end,
	["appearance.reasonPalette"] = function() return Profile().prompt.reasonPalette == "colourblind" end,
	-- The cure button's modifiers, kept per class: a choice saved is a change.
	["appearance.cureFightPlain"] = function() return CureModSaved("plain") end,
	["appearance.cureFightShift"] = function() return CureModSaved("shift") end,
	["appearance.cureFightCtrl"] = function() return CureModSaved("ctrl") end,
	["general.minimap"] = function() return Profile().minimap.hide == true end,
	["click.preset"] = LinesChanged,
	["click.phrases"] = LinesChanged,
}

-- Numbers within half a step, colours per component within 0.002 (alpha 1
-- when missing), anything else exactly.
local function Same(a, b, step)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= (step and step / 2 or 1e-9)
	end
	if type(a) == "table" and type(b) == "table" then
		for i = 1, 4 do
			local x, y = a[i], b[i]
			if i == 4 then x, y = x == nil and 1 or x, y == nil and 1 or y end
			if type(x) ~= "number" or type(y) ~= "number" or math.abs(x - y) > 0.002 then return false end
		end
		return true
	end
	return a == b
end

-- The kinds of control that have a default to go back to.
local MARKED = { toggle = true, range = true, select = true, input = true, color = true }

-- The profile default of a control, and the value it holds now; nil, nil when
-- it has none to go back to. A path with exactly one FIELDS entry, or a
-- control whose get is a shared getter (Options/Shared.lua, BOUND) and so
-- reads the profile table under the option's own key. A table default counts
-- for a colour only.
local function Locate(path, item)
	local def = item and item.def
	if type(def) ~= "table" or not MARKED[def.type] then return nil end
	local p, defaults = Profile(), ns.defaults.profile
	local fields, section, key = FIELDS[path], nil, nil
	if fields then
		if #fields ~= 1 then return nil end
		section, key = fields[1][1], fields[1][2]
	else
		local bound = ns.OptionsPage.BOUND
		section = bound[def.get] or bound[def.getColor]
		key = path:match("%.([^.]+)$")
		if not section or not key then return nil end
	end
	local want = (defaults[section] or {})[key]
	if want == nil or (type(want) == "table" and def.type ~= "color") then return nil end
	-- A clamp to the prompt's size alone is not a change.
	if key == "iconSize" and type(want) == "number" and ns.IconCeiling then
		want = math.min(want, ns.IconCeiling(p.prompt))
	end
	return want, (p[section] or {})[key]
end

function UI.DefaultOf(path, item)
	return (Locate(path, item))
end

function UI.IsChanged(path, item)
	local want, have = Locate(path, item)
	if want == nil then return false end
	return not Same(have, want, item.def.step)
end

function UI.Differs(path, item)
	local differs = DIFFERS[path]
	if differs then return differs() and true or false end
	local p = Profile()
	local skip = path:match("^who%.offer_(.+)$")
	-- A buff that is off until it is ticked (Buffs.lua, optIn) differs ticked.
	if skip then return (p.buff.skip or {})[skip] == true or (p.buff.optIn or {})[skip] == true end
	local tanks = path:match("^who%.tank_(.+)$")
	if tanks then return (p.buff.tanksOnly or {})[tanks] == true or (p.buff.meOnly or {})[tanks] == true end
	local inside = path:match("^who%.notMeInside_(.+)$")
	if inside then return (p.buff.notMeInside or {})[inside] == true end
	local family = path:match("^who%.own_(.+)$")
	if family then
		local pick = (p.ownBuffs.pick or {})[family]
		return pick ~= nil and pick ~= ns.defaults.profile.ownBuffs.pick[family]
	end
	local fields = FIELDS[path]
	if not fields then return UI.IsChanged(path, item) end
	local defaults = ns.defaults.profile
	local step = item and item.def.step
	for _, f in ipairs(fields) do
		local want = (defaults[f[1]] or {})[f[2]]
		-- A clamp to the prompt's size alone does not light the dot.
		if f[2] == "iconSize" and type(want) == "number" and ns.IconCeiling then
			want = math.min(want, ns.IconCeiling(p.prompt))
		end
		if not Same((p[f[1]] or {})[f[2]], want, step) then return true end
	end
	return false
end

function UI.FoldChanged(sec)
	for _, e in ipairs(sec.entries) do
		if e.isControl and e.visible and UI.Differs(e.path, e.item) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- frames: built once per page
---------------------------------------------------------------------------

-- A row that will not build is named in /manners errors and left out; the
-- rest of the page still works.
local function BuildRow(e, child)
	local W = ns.WindowWidgets
	local ok, row = pcall(W.Build, e.kind, child, e.item)
	if not ok then
		ns.Guard("options row " .. e.path, error, row, 0)
		return nil
	end
	row.frame:Hide()
	return row
end

local function ToggleFold(sec)
	local open = UI.State().open
	open[sec.key] = not open[sec.key] or nil
	UI.Refresh()
end

local function FoldButton(sec, child)
	local b = CreateFrame("Button", nil, child)
	b:SetHeight(26)
	b.hover = UI.Solid(b, "BACKGROUND", C.hover)
	b.hover:SetAllPoints()
	b.hover:Hide()
	local rule = UI.Solid(b, "BORDER", C.faint)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)
	b.chevron = b:CreateTexture(nil, "ARTWORK")
	b.chevron:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	b.chevron:SetSize(12, 12)
	b.chevron:SetVertexColor(C.goldSoft[1], C.goldSoft[2], C.goldSoft[3], 1)
	b.chevron:SetPoint("LEFT", b, "LEFT", 4, 0)
	b.label = UI.Text(b, 13, C.goldSoft)
	b.label:SetPoint("LEFT", b, "LEFT", 22, 0)
	b.dot = UI.Dot(b, C.gold)
	b:SetScript("OnClick", UI.Guarded(function() ToggleFold(sec) end))
	b:SetScript("OnEnter", function(self) self.hover:Show() end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	b:Hide()
	return b
end

local function SectionTitle(sec, child)
	sec.title = UI.Text(child, 13, C.gold)
	sec.title:Hide()
	sec.rule = child:CreateTexture(nil, "ARTWORK")
	sec.rule:SetHeight(1)
	UI.Gradient(sec.rule, "HORIZONTAL", C.goldRule, { 1, 0.82, 0, 0 })
	sec.rule:Hide()
	UI.Dress.Section(sec, child)
end

-- The hairline above the folds, captioned in grey with advIntro's sentence.
local function Caption(m, child)
	local cap = {}
	cap.text = UI.Text(child, GameFontDisableSmall, C.hint)
	cap.text:SetJustifyH("CENTER")
	cap.text:SetWordWrap(true)
	if cap.text.SetNonSpaceWrap then cap.text:SetNonSpaceWrap(true) end
	cap.left = UI.Solid(child, "ARTWORK", C.line)
	cap.left:SetHeight(1)
	cap.right = UI.Solid(child, "ARTWORK", C.line)
	cap.right:SetHeight(1)
	cap.item = UI.Item(UI.Layout().foldCaption)
	m.caption = cap
	UI.ShowCaption(m, false)
end

function UI.ShowCaption(m, on)
	local cap = m.caption
	cap.text:SetShown(on)
	cap.left:SetShown(on)
	cap.right:SetShown(on)
end

local function BuildFrames(m)
	if m.built then return end
	local child = UI.view.child
	m.title = UI.Text(child, 18, C.gold)
	m.title:Hide()
	m.blurb = UI.Text(child, 12, C.hint)
	m.blurb:Hide()
	for _, sec in ipairs(m.sections) do
		if sec.fold then sec.button = FoldButton(sec, child) end
		-- A fold has a title too: drawn open under it in a sub-division.
		if sec.def.title or sec.headerItem then SectionTitle(sec, child) end
		for _, e in ipairs(sec.entries) do e.row = BuildRow(e, child) end
	end
	Caption(m, child)
	m.built = true
end

local function HideTitle(sec)
	if sec.title then
		sec.title:Hide()
		sec.rule:Hide()
		if sec.stud then sec.stud:Hide() end
	end
end

local function HideSection(sec)
	HideTitle(sec)
	if sec.button then sec.button:Hide() end
	for _, e in ipairs(sec.entries) do
		if e.row then e.row.frame:Hide() end
	end
end

-- Put a page's frames away when another one is shown.
function UI.HidePage(id)
	local m = models[id]
	if not (m and m.built) then return end
	m.title:Hide()
	m.blurb:Hide()
	UI.ShowCaption(m, false)
	for _, sec in ipairs(m.sections) do HideSection(sec) end
end

---------------------------------------------------------------------------
-- laying a page out
---------------------------------------------------------------------------

local function NaturalWidth(e)
	local row = e.row
	local w = row and row.NaturalWidth and row.NaturalWidth(row)
	return type(w) == "number" and w or math.huge
end

-- A row laid out at a width and given its place within its section: x from
-- the column's left edge, y from the section's top. The section is put in its
-- column afterwards (AnchorSection), which is what anchors and shows the row.
-- `h` when the row was laid out at this width already.
local function Place(e, x, y, width, h)
	local row = e.row
	h = h or row.Layout(row, width) or 20
	row.frame:SetSize(width, h)
	e.y, e.x, e.h, e.stamp = y, x, h, stamp
	return h
end

local function Usable(e) return e.visible and e.row ~= nil end

-- How far in a row starts: `indent = true` one step, `indent = 2` two (a
-- choice that belongs to a switch which is itself indented).
local function Indent(e)
	local n = e.layout.indent
	if not n then return 0 end
	return (n == true and 1 or tonumber(n) or 1) * INDENT
end

-- How far down a row the middle of its control is: under the label for a
-- dropdown, a slider or a box, at the top for a switch or a swatch. Nil for a
-- row with no control to line up (a note).
local function Middle(row)
	if not (row and row.fieldHeight) then return nil end
	return (row.fieldTop or 0) + row.fieldHeight / 2
end

-- Two rows side by side, the one whose control sits higher moved down until
-- the two controls are level: Lock position beside its dropdown rather than
-- beside the dropdown's label.
local function PlaceTwo(a, b, x, half, y)
	local ha = a.row.Layout(a.row, half) or 20
	local hb = b.row.Layout(b.row, half) or 20
	local ma, mb = Middle(a.row), Middle(b.row)
	local da, db = 0, 0
	if ma and mb then
		if ma > mb then db = math.floor(ma - mb + 0.5) else da = math.floor(mb - ma + 0.5) end
	end
	Place(a, x, y + da, half, ha)
	Place(b, x + half + GAP, y + db, half, hb)
	return y + math.max(ha + da, hb + db) + ROW_GAP
end

-- The items from i that a run of pairs covers: a pair and the item after it,
-- and the next pair when it starts straight after (the reason boxes are one
-- run of four pairs).
local function PairRun(list, i)
	local last, k = i, i
	while list[k] and list[k].layout.pair and list[k + 1] do
		last = k + 1
		k = k + 2
	end
	return last
end

-- A run's shown items two to a row, in order, so two still share a row when
-- the ones between them are hidden (a hunter's two reason boxes), and a pair
-- whose partner is hidden is not joined to whatever follows the run. Two share
-- a row when both fit half the width, measured in this language; otherwise
-- one goes above the other.
local function PlacePairs(list, i, y)
	local last, shown = PairRun(list, i), {}
	for k = i, last do
		if Usable(list[k]) then
			shown[#shown + 1] = list[k]
		elseif list[k].row then
			list[k].row.frame:Hide()
		end
	end
	local k = 1
	while k <= #shown do
		local a, b = shown[k], shown[k + 1]
		local x, width = PAD_LEFT + Indent(a), COLUMN_W - Indent(a)
		local half = math.floor((width - GAP) / 2)
		if b and NaturalWidth(a) <= half and NaturalWidth(b) <= half then
			y = PlaceTwo(a, b, x, half, y)
			k = k + 2
		else
			y = y + Place(a, x, y, width) + ROW_GAP
			k = k + 1
		end
	end
	return y, last + 1
end

-- A run of items in `columns` columns (the per-spell switches, the reason
-- boxes), when every one fits a column; stacked otherwise.
local function PlaceColumns(list, i, y)
	local e = list[i]
	local cols = e.layout.columns
	local run, last = {}, i
	for k = i, #list do
		if list[k].layout.columns ~= cols then break end
		last = k
		if Usable(list[k]) then
			run[#run + 1] = list[k]
		elseif list[k].row then
			list[k].row.frame:Hide()
		end
	end
	local x, width = PAD_LEFT + Indent(e), COLUMN_W - Indent(e)
	local colW = math.floor((width - (cols - 1) * GAP) / cols)
	local fits = true
	for _, r in ipairs(run) do
		if NaturalWidth(r) > colW then fits = false end
	end
	if not fits then
		for _, r in ipairs(run) do y = y + Place(r, PAD_LEFT + Indent(r), y, COLUMN_W - Indent(r)) + ROW_GAP end
		return y, last + 1
	end
	local col, tallest = 0, 0
	for _, r in ipairs(run) do
		tallest = math.max(tallest, Place(r, x + col * (colW + GAP), y, colW))
		col = col + 1
		if col == cols then
			y, col, tallest = y + tallest + ROW_GAP, 0, 0
		end
	end
	if col > 0 then y = y + tallest + ROW_GAP end
	return y, last + 1
end

-- A run of buttons (the layout's `buttons`): the shown ones left to right at
-- their own widths, a gap between, onto the next line where the width runs
-- out; Done beside Skip rather than half a page apart.
local BUTTON_GAP = 10

-- A note in a run of buttons (the line Profiles' Undo stands beside) set
-- level with them: moved down by half of what the line's tallest has more.
local function Level(line, tallest)
	for _, e in ipairs(line) do
		if e.row.kind == "description" and e.h < tallest then e.y = e.y + math.floor((tallest - e.h) / 2) end
	end
end

local function PlaceButtons(list, i, y)
	local last = i
	while list[last + 1] and list[last + 1].layout.buttons do last = last + 1 end
	local x0 = PAD_LEFT + Indent(list[i])
	local right = PAD_LEFT + COLUMN_W
	local x, tallest, line = x0, 0, {}
	for k = i, last do
		local e = list[k]
		if Usable(e) then
			local w = math.min(NaturalWidth(e), right - x0)
			if x > x0 and x + w > right then
				Level(line, tallest)
				y, x, tallest, line = y + tallest + ROW_GAP, x0, 0, {}
			end
			tallest = math.max(tallest, Place(e, x, y, w))
			line[#line + 1] = e
			x = x + w + BUTTON_GAP
		elseif e.row then
			e.row.frame:Hide()
		end
	end
	Level(line, tallest)
	if tallest > 0 then y = y + tallest + ROW_GAP end
	return y, last + 1
end

-- Dropdowns of one `match` draw their fields at the widest one's width
-- (WidgetsChoice.lua reads row.matchField), so two questions asked one under
-- the other line up in any language.
local function MatchFields(sec)
	local widest = {}
	for _, e in ipairs(sec.entries) do
		local tag = e.layout.match
		if tag and e.row and Usable(e) then
			widest[tag] = math.max(widest[tag] or 0, e.row.fieldNeed or 0)
		end
	end
	for _, e in ipairs(sec.entries) do
		local tag = e.layout.match
		if tag and e.row then e.row.matchField = widest[tag] end
	end
end

local function LayoutRows(sec, y)
	local list, i = sec.entries, 1
	MatchFields(sec)
	while i <= #list do
		local e = list[i]
		local cols = e.layout.columns
		if e.layout.buttons then
			y, i = PlaceButtons(list, i, y)
		elseif e.layout.pair then
			y, i = PlacePairs(list, i, y)
		elseif not Usable(e) then
			if e.row then e.row.frame:Hide() end
			i = i + 1
		elseif cols and cols > 1 and e.kind ~= "multiselect" and e.kind ~= "never" then
			y, i = PlaceColumns(list, i, y)
		else
			y = y + Place(e, PAD_LEFT + Indent(e), y, COLUMN_W - Indent(e)) + ROW_GAP
			i = i + 1
		end
	end
	return y
end

local function SectionText(sec)
	if sec.def.title then return sec.def.title end
	local item = sec.headerItem
	return item and ns.WindowBind.Text(item, "name") or ""
end
UI.SectionText = SectionText

local function PlaceFold(sec, y)
	local b = sec.button
	b:SetWidth(COLUMN_W + 4)
	b.label:SetText(SectionText(sec))
	b.dot:ClearAllPoints()
	b.dot:SetPoint("LEFT", b.label, "LEFT", math.ceil(UI.TextWidth(b.label, 13)) + 8, 0)
	b.dot:SetShown(UI.FoldChanged(sec))
	-- Pointing right when shut, down when open.
	if UI.State().open[sec.key] then
		b.chevron:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
	else
		b.chevron:SetTexCoord(0, 1, 0, 1)
	end
	sec.y = y
	return y + 26
end

-- The title, and its gold rule running on from it to its column's right
-- edge on the same line, fading out, as the mock-up and a model header row
-- (Widgets.lua) draw it. Measured here; AnchorSection puts both in the column.
local function PlaceTitle(sec, y)
	sec.title:SetText(SectionText(sec))
	local h = UI.TextHeight(sec.title, 13)
	sec.ruleFrom = math.min(math.ceil(UI.TextWidth(sec.title, 13)) + 10, COLUMN_W)
	sec.ruleTo = COLUMN_W
	sec.ruleMiddle = y + math.floor(h / 2 + 0.5)
	sec.y = y
	return y + h + 6
end

-- A section laid out (LayoutSection) put where its column has it: its fold
-- button or its title and rule, and every row this paint placed in it, moved
-- by the column's left edge and the section's top. Placement only: nothing is
-- laid out or read again.
local function AnchorSection(sec, ox, oy, column)
	local child = UI.view.child
	if sec.fold and not flat then
		HideTitle(sec)
		local b = sec.button
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", child, "TOPLEFT", ox + PAD_LEFT - 4, -(oy + sec.y))
		b:Show()
	elseif sec.title then
		if sec.button then sec.button:Hide() end
		sec.title:ClearAllPoints()
		sec.title:SetPoint("TOPLEFT", child, "TOPLEFT", ox + PAD_LEFT, -(oy + sec.y))
		sec.title:Show()
		local middle = -(oy + sec.ruleMiddle)
		sec.rule:ClearAllPoints()
		sec.rule:SetPoint("LEFT", child, "TOPLEFT", ox + PAD_LEFT + sec.ruleFrom, middle)
		sec.rule:SetPoint("RIGHT", child, "TOPLEFT", ox + PAD_LEFT + sec.ruleTo, middle)
		sec.rule:Show()
		UI.Dress.PlaceSection(sec)
	end
	for _, e in ipairs(sec.entries) do
		if e.stamp == stamp and e.row then
			local frame = e.row.frame
			e.x, e.y = e.x + ox, e.y + oy
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", child, "TOPLEFT", e.x, -e.y)
			frame:Show()
		end
	end
	if (sec.fold and not flat) or sec.title then sec.y = sec.y + oy end
	-- Where the section stands: its column (1 the leftmost), that column's
	-- left edge and width, and its own top.
	sec.column, sec.left, sec.width, sec.top = column, ox, COLUMN_W, oy
end

-- Across the whole page, over however many columns the folds under it take.
local function PlaceCaption(m, y)
	local cap = m.caption
	local text = cap.item and ns.WindowBind.Text(cap.item, "name")
	text = text and UI.Plain(text) or ""
	cap.text:SetWidth(CONTENT_W - 80)
	cap.text:SetText(text)
	local w = math.min(CONTENT_W - 80, UI.TextWidth(cap.text, 10))
	local h = UI.TextHeight(cap.text, 10)
	local mid = y + 6 + math.floor(h / 2)
	cap.text:ClearAllPoints()
	cap.text:SetPoint("TOP", UI.view.child, "TOPLEFT", PAD_LEFT + CONTENT_W / 2, -(y + 6))
	local side = math.max(8, math.floor((CONTENT_W - w) / 2) - 10)
	cap.left:ClearAllPoints()
	cap.left:SetPoint("TOPLEFT", UI.view.child, "TOPLEFT", PAD_LEFT, -mid)
	cap.left:SetWidth(side)
	cap.right:ClearAllPoints()
	cap.right:SetPoint("TOPRIGHT", UI.view.child, "TOPLEFT", PAD_LEFT + CONTENT_W, -mid)
	cap.right:SetWidth(side)
	UI.ShowCaption(m, true)
	return y + h + 16
end

-- A visible section laid out at the column's width from its own top: its
-- fold button or title, then its rows. Answers how tall it is, the gap under
-- it included.
local function LayoutSection(sec)
	local y = 0
	if sec.fold and not flat then
		y = PlaceFold(sec, y)
		if not UI.State().open[sec.key] then
			for _, e in ipairs(sec.entries) do
				if e.row then e.row.frame:Hide() end
			end
			return y + 2
		end
		y = y + 6
	elseif sec.title then
		y = PlaceTitle(sec, y)
	end
	return LayoutRows(sec, y) + SECTION_GAP
end

-- Every row re-reads its label, value and greyed-out state; the widget
-- leaves a slider being dragged and a box being typed in alone. A row that
-- throws is named once and left out of this paint.
local function RefreshRow(e, row)
	row:Refresh()
	-- The gold mark on a setting that is not at its default (W.PaintChanged).
	if e.isControl and not e.subs then ns.WindowWidgets.PaintChanged(row, e.path) end
end

local function RefreshRows(sec)
	for _, e in ipairs(sec.entries) do
		local row = e.row
		if row and e.visible then
			local ok, err = pcall(RefreshRow, e, row)
			if not ok then
				ns.Guard("options row " .. e.path, error, err, 0)
				e.visible = false
			end
		end
	end
end

---------------------------------------------------------------------------
-- the view's own lines: the offer over a page, what the short list leaves out
---------------------------------------------------------------------------

-- Two sections of the window's own, on no page of the layout and so drawn on
-- whichever is open (Layout.lua, `menu`): over the page, the line offering
-- the simple view with its two buttons; under it, how many settings the short
-- list leaves out and Show everything. Built once, with the rows of any page,
-- and shown by their own rules (Options/Start.lua).
local menu

local function MenuSection(key, raws)
	local sec = { def = {}, key = key, fold = false, entries = {}, hasControls = false, chrome = true }
	for _, raw in ipairs(raws) do
		local e = raw[1] and Entry(raw, sec)
		if e then
			e.level, e.chrome = 0, true
			e.row = BuildRow(e, UI.view.child)
			sec.entries[#sec.entries + 1] = e
			sec.hasControls = sec.hasControls or e.isControl
		end
	end
	return sec
end

local function MenuSections()
	if menu then return menu end
	local slots = UI.Layout().menu or {}
	menu = {
		offer = MenuSection("menu.offer", { { slots.offer, hint = true, block = true },
			{ slots.try, buttons = true }, { slots.dismiss, buttons = true } }),
		more = MenuSection("menu.more", { { slots.more, hint = true }, { slots.everything, buttons = true } }),
	}
	return menu
end

-- The row of one of the view's own controls ("offer", "try", "dismiss",
-- "more", "everything"), for the scenarios; nil until a page has been painted.
function UI.MenuRow(slot)
	local path = (UI.Layout().menu or {})[slot]
	for _, sec in pairs(menu or {}) do
		for _, e in ipairs(sec.entries) do
			if e.path == path then return e.row, e end
		end
	end
	return nil
end


---------------------------------------------------------------------------
-- sub-divisions: the second level of the sidebar (Layout.lua, `subpages`)
---------------------------------------------------------------------------

-- A page's sub-divisions that have a section shown, as the last paint judged
-- the page; none at all unless two or more have, and none before the page
-- has been painted (the paint that judges it paints the sidebar again).
function UI.SubsShown(id)
	local m = models[id]
	local out = {}
	if not (m and m.judged and m.subs) then return out end
	for _, sub in ipairs(m.subs) do
		for _, sec in ipairs(sub.secs) do
			if sec.visible then
				out[#out + 1] = sub
				break
			end
		end
	end
	if #out < 2 then return {} end
	return out
end

-- The sub-division chosen on a page while it has something to show; nil for
-- All. One that has nothing now (the simple view on) shows All and is kept.
function UI.SubInView(id)
	local key = UI.subOf[id]
	if key == nil then return nil end
	for _, sub in ipairs(UI.SubsShown(id)) do
		if sub.key == key then return sub end
	end
	return nil
end

-- What the sidebar calls a sub-division: its title, or the title of its first
-- section shown.
function UI.SubLabel(sub)
	if sub.def.title then return sub.def.title end
	for _, sec in ipairs(sub.secs) do
		if sec.visible and (sec.def.title or sec.headerItem) then return SectionText(sec) end
	end
	return SectionText(sub.secs[1])
end

-- A sub-division chosen in the sidebar (key nil: All), on its page, from the
-- top.
function UI.ShowSub(id, key)
	UI.subOf[id] = key
	if UI.page ~= id then return UI.ShowPage(id) end
	if UI.LeaveSearch then UI.LeaveSearch() end
	UI.view.scrollY = 0
	UI.Refresh()
end

-- Whether a section's rows are on screen as far as the page goes: in the
-- sub-division in view, and open (a fold is open in a sub-division). Read
-- from the choice as it stands, not from the last paint, so the strip
-- painted before the page agrees with it.
function UI.SectionOpen(sec)
	local sub = UI.SubInView(sec.page)
	if sub and sec.sub and sec.sub ~= sub then return false end
	return sub ~= nil or not sec.fold or UI.State().open[sec.key] == true
end

-- How many columns a page of this width flows into: one until there is room
-- for two of MIN_COLUMN with the gap between them, three at most.
function UI.ColumnsFor(width)
	local n = math.floor(((tonumber(width) or 0) + COLUMN_GAP) / (MIN_COLUMN + COLUMN_GAP))
	return math.max(1, math.min(MAX_COLUMNS, n))
end

-- How many columns the page in view has room for as the window stands.
function UI.Columns() return UI.ColumnsFor(ContentWidth()) end

-- Where to break a run of sections into `n` columns: the sections stay in
-- order and whole, each column a stretch of the run, and of every way to cut
-- it the one whose tallest column is shortest; between two as short, the one
-- that fills the columns to the left first. Answers the index each column
-- starts at. The runs are a handful of sections and the columns three at
-- most, so every cut is simply tried.
local function Breaks(heights, n)
	local count = #heights
	local sum = { [0] = 0 }
	for i = 1, count do sum[i] = sum[i - 1] + heights[i] end
	if n <= 1 or count <= 1 then return { 1 } end
	local best, bestTall, bestLeft
	local function Try(a, b)
		local one, two = sum[a - 1], b and sum[b - 1] - sum[a - 1] or sum[count] - sum[a - 1]
		local three = b and sum[count] - sum[b - 1] or 0
		local tall = math.max(one, two, three)
		-- Left first: the leftmost column as tall as the cut allows, then the next.
		local left = one * 1e6 + two
		if not best or tall < bestTall or (tall == bestTall and left > bestLeft) then
			best, bestTall, bestLeft = b and { 1, a, b } or { 1, a }, tall, left
		end
	end
	for a = 2, count do
		if n >= 3 and count >= 3 then
			for b = a + 1, count do Try(a, b) end
		else
			Try(a)
		end
	end
	return best
end
UI.ColumnBreaks = Breaks

-- A run of sections that share the page's width: laid out at the width of a
-- column, cut into columns (Breaks) and put there. A run of one section, or a
-- page with room for one column, is the page as it always was. Answers the y
-- under the tallest column.
local function FlowRun(run, y, columns)
	local n = math.min(columns, #run)
	if n < 1 then return y end
	local width = math.floor((CONTENT_W - (n - 1) * COLUMN_GAP) / n)
	-- Fewer sections than the page has columns for: not stretched across it.
	if columns > 1 then width = math.min(width, MAX_COLUMN) end
	COLUMN_W = width
	local heights = {}
	for i, sec in ipairs(run) do heights[i] = LayoutSection(sec) end
	local starts = Breaks(heights, n)
	local bottom = y
	for c, first in ipairs(starts) do
		local last = (starts[c + 1] or (#run + 1)) - 1
		local ox, oy = (c - 1) * (width + COLUMN_GAP), y
		for i = first, last do
			AnchorSection(run[i], ox, oy, c)
			oy = oy + heights[i]
		end
		bottom = math.max(bottom, oy)
	end
	COLUMN_W = CONTENT_W
	return bottom
end

-- A section that takes the page's whole width whatever the columns: one the
-- layout's `spans` names (the line a page opens with).
local function FlowSpan(sec, y)
	COLUMN_W = CONTENT_W
	local h = LayoutSection(sec)
	AnchorSection(sec, 0, y, 1)
	return y + h
end

-- One of the view's own sections, across the page at y while its rules show
-- it. Answers the y under it.
local function PaintChrome(sec, y, mode)
	if mode ~= "reflow" and Judge(sec) and mode ~= "layout" then RefreshRows(sec) end
	if not sec.visible then
		HideSection(sec)
		return y
	end
	return FlowSpan(sec, y)
end

-- The line under the page's title, saying what the page is for; answers the
-- y under it.
local function PaintBlurb(m, y)
	if m.page.blurb then
		m.blurb:SetText(m.page.blurb)
		m.blurb:SetWidth(CONTENT_W)
		m.blurb:SetWordWrap(true)
		m.blurb:ClearAllPoints()
		m.blurb:SetPoint("TOPLEFT", UI.view.child, "TOPLEFT", PAD_LEFT, -y)
		m.blurb:Show()
		return y + UI.TextHeight(m.blurb, 12) + 8
	end
	m.blurb:Hide()
	return y
end

-- mode: nil reads every row again and lays the page out; "layout" places the
-- rows again without reading them (a row changed height by itself); "reflow"
-- also keeps which rows show as the last paint judged it, so nothing of the
-- model is asked: the window being dragged wider or narrower, every frame.
function UI.PaintPage(mode)
	if mode == true then mode = "layout" end
	CONTENT_W = ContentWidth()
	local m = UI.Model(UI.page)
	if mode == "reflow" and not m.judged then mode = "layout" end
	BuildFrames(m)
	stamp = stamp + 1
	COLUMN_W = CONTENT_W
	local y = PAD_TOP
	m.title:SetText(m.page.title or "")
	m.title:ClearAllPoints()
	m.title:SetPoint("TOPLEFT", UI.view.child, "TOPLEFT", PAD_LEFT, -y)
	m.title:Show()
	y = y + UI.TextHeight(m.title, 18) + 10
	y = PaintBlurb(m, y)
	local chrome = MenuSections()
	-- Over the page: the simple view, offered once.
	y = PaintChrome(chrome.offer, y, mode)
	-- Which sections show, all of them, before any is placed: the sidebar's
	-- sub-divisions are the ones with a section shown.
	for _, sec in ipairs(m.sections) do
		if mode ~= "reflow" then
			Judge(sec)
		end
	end
	m.judged = true
	-- The sub-division in view, nil for the whole page: only its sections are
	-- placed, each fold of them open, and no caption is drawn over them.
	local sub = UI.SubInView(m.id)
	flat = sub ~= nil
	local captioned, open = flat, UI.State().open
	local columns = UI.ColumnsFor(CONTENT_W)
	m.columns = columns
	-- The sections in order, in runs: the ones before the folds, then the
	-- folds under their caption, a `span` section standing alone between runs.
	local run = {}
	local function Flush()
		if #run > 0 then
			y = FlowRun(run, y, columns)
			run = {}
		end
	end
	for _, sec in ipairs(m.sections) do
		-- Out of the sub-division in view: put away, and not read.
		sec.away = sub ~= nil and sec.sub ~= nil and sec.sub ~= sub
		if mode == nil and sec.visible and not sec.away then
			-- A shut fold's rows are not drawn, so not read either.
			if flat or not (sec.fold and not open[sec.key]) then RefreshRows(sec) end
		end
		if not sec.visible or sec.away then
			HideSection(sec)
		else
			-- Over the first fold of fine print: a `plain` fold (the hall of
			-- fame on Start here) holds no setting and takes no caption.
			if sec.fold and not sec.def.plain and not captioned then
				Flush()
				y = PlaceCaption(m, y)
				captioned = true
			end
			if sec.span then
				Flush()
				y = FlowSpan(sec, y)
			else
				run[#run + 1] = sec
			end
		end
	end
	Flush()
	if flat or not captioned then UI.ShowCaption(m, false) end
	-- Under the page: what the short list left out of it (of the sub-division
	-- in view), counted by the judging above, and the way to it.
	if mode ~= "reflow" then
		local left = 0
		for _, sec in ipairs(m.sections) do
			for _, e in ipairs(sec.away and NONE or sec.entries) do
				if e.bySimple then left = left + 1 end
			end
		end
		UI.simpleHidden = left
	end
	y = PaintChrome(chrome.more, y, mode)
	UI.SetContentHeight(y + PAD_BOTTOM)
end

---------------------------------------------------------------------------
-- finding a row: the search jump and the share box
---------------------------------------------------------------------------

-- Opens the page a control is on, its fold with it (remembered open), and
-- scrolls the row into view. Answers the entry, or nil when it is not shown.
function UI.Reveal(path)
	local w = UI.Where(path)
	if not w then return nil end
	-- The sub-division that holds it, chosen and remembered as a click would.
	if w.sec.sub then UI.subOf[w.page] = w.sec.sub.key end
	if UI.page ~= w.page then UI.ShowPage(w.page) end
	if w.sec.fold then UI.State().open[w.sec.key] = true end
	UI.Refresh()
	-- Left out by the simple view: nothing is lost, the full view opens on it.
	if not UI.RowShown(path) and UI.HiddenBySimple(path) then
		ns.SetMenuView("full")
		UI.Refresh()
	end
	if not UI.RowShown(path) then
		-- Not drawn under a switch that is off: the switch is what to show.
		local switch = UI.SwitchFor(path)
		if switch and switch.path ~= path then return UI.Reveal(switch.path) end
		return nil
	end
	local e = w.e
	UI.ScrollTo(e.y - 30)
	return e
end

-- The row for a path on the page as built, for the search flash and tests.
function UI.RowFor(path)
	local w = UI.Where(path)
	return w and w.e.row or nil
end

-- Whether the row is drawn on the open page right now.
function UI.RowShown(path)
	local w = UI.Where(path)
	if not (w and w.page == UI.page and w.e.row and w.e.visible and w.sec.visible) then return false end
	return UI.SectionOpen(w.sec)
end
