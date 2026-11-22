-- Manners -- Report a bug: one window that walks a player through it.
--
-- What went wrong (six choices) and a few words, then two boxes to copy from:
-- a link that opens the issue form on GitHub with the category, class, game and
-- version filled in, and the full check-up (Diagnostics.lua, ns.FullReport) to
-- paste into the form's report box. Also here: Mark this moment (a key, a menu
-- entry and /manners mark write what Manners sees at that instant onto the
-- trail, in a fight too), the watch that notes why the prompt is held back, and
-- the chat link an error offers ("Report it").
--
-- Names never leave in the link: the player's own name, realm and guild, and
-- every other name the report knows, are replaced (BR.Scrub). The window is a
-- plain frame, so it opens and works in a fight; the full report waits for the
-- fight to end, the short summary does not.

local _, ns = ...
local L = ns.L

local BR = {}
ns.BugReport = BR

BR.CAP = 60000
BR.URL_MAX = 2000
BR.ISSUE = "https://github.com/fpsacha/Manners/issues/new"

-- `en` goes in the link and the report, `name` is what the window shows.
BR.CATEGORIES = {
	{ key = "noprompt", en = "The prompt never showed up", name = L["The prompt never showed up"] },
	{ key = "wrong", en = "It offered the wrong buff or person", name = L["It offered the wrong buff or person"] },
	{ key = "fight", en = "A fight button (cure, Will of the Forsaken, Mend Pet)", name = L["A fight button (cure, Will of the Forsaken, Mend Pet)"] },
	{ key = "window", en = "The options window", name = L["The options window"] },
	{ key = "error", en = "An error message", name = L["An error message"] },
	{ key = "other", en = "Something else", name = L["Something else"] },
}

-- English, as the issue form's dropdown lists them.
BR.GAMES = {
	camelot = "WoW Forever",
	vanilla = "Classic Era",
	tbc = "Burning Crusade Classic",
	mists = "Mists of Pandaria Classic",
	mainline = "Retail",
}

BR.CLASSES = {
	WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
	DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", MONK = "Monk",
	DRUID = "Druid", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
}

BR.MARK_COMMAND = "CLICK MannersMark:LeftButton"

local function CategoryOf(key)
	for _, c in ipairs(BR.CATEGORIES) do
		if c.key == key then return c end
	end
	return BR.CATEGORIES[#BR.CATEGORIES]
end

---------------------------------------------------------------------------
-- the link
---------------------------------------------------------------------------

function BR.Encode(s)
	return (tostring(s):gsub("[^%w%-%._~]", function(c) return ("%%%02X"):format(c:byte()) end))
end

-- At most n bytes, never inside a multi-byte character.
function BR.CutUTF8(s, n)
	s = tostring(s)
	if #s <= n then return s end
	if n <= 0 then return "" end
	local at = n
	-- The byte after the cut must not be a continuation byte (128-191).
	while at > 0 do
		local b = s:byte(at + 1)
		if b and b >= 128 and b <= 191 then at = at - 1 else break end
	end
	return s:sub(1, at)
end

local function Plain1(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return ns.plain(a), ns.plain(b)
end

-- The text with every name it knows replaced: the aliases a full check-up made
-- (name -> "Person 3"), then yours, your realm and your guild. Whole words,
-- longest first.
function BR.Scrub(text, aliases)
	text = tostring(text or "")
	local names = {}
	local function Add(name, to)
		if type(name) == "string" and name ~= "" then names[#names + 1] = { name, to } end
	end
	for name, to in pairs(aliases or {}) do Add(name, to) end
	local me, surname = Plain1(_G.UnitName, "player")
	Add(me, "(me)")
	if type(me) == "string" and me ~= "" and type(surname) == "string" and surname ~= "" then
		Add(me .. " " .. surname, "(me)")
		Add(surname, "(me)")
	end
	Add((Plain1(_G.GetRealmName)), "(realm)")
	Add((Plain1(_G.GetNormalizedRealmName)), "(realm)")
	Add((Plain1(_G.GetGuildInfo, "player")), "(guild)")
	table.sort(names, function(a, b)
		if #a[1] ~= #b[1] then return #a[1] > #b[1] end
		return a[1] < b[1]
	end)
	for _, pair in ipairs(names) do text = ns.SwapName(text, pair[1], pair[2]) end
	return text
end

-- The issue form's address with what the form's fields take. Nothing else
-- goes in it, and it stays under URL_MAX: the words are cut first, then dropped.
function BR.URL(categoryKey, words, aliases)
	local c = CategoryOf(categoryKey)
	local caps = ns.caps or {}
	local scrubbed = BR.Scrub(words or "", aliases)
	local function Make(w)
		local what = c.en .. (w ~= "" and (": " .. w) or "")
		local fields = {
			{ "template", "bug_report.yml" },
			{ "title", "Bug: " .. c.en },
			{ "category", c.en },
			{ "what", what },
			{ "class", BR.CLASSES[caps.class] or tostring(caps.class or "") },
			{ "version", tostring(ns.BUILD) },
			{ "game", BR.GAMES[ns.Flavour and ns.Flavour.flavour] or "" },
		}
		local parts = {}
		for _, f in ipairs(fields) do parts[#parts + 1] = f[1] .. "=" .. BR.Encode(f[2]) end
		return BR.ISSUE .. "?" .. table.concat(parts, "&")
	end
	local w = scrubbed
	local url = Make(w)
	while #url > BR.URL_MAX and w ~= "" do
		if #w <= 40 then
			w = ""
		else
			w = BR.CutUTF8(w, #w - 40) .. "..."
		end
		url = Make(w)
	end
	return url
end

---------------------------------------------------------------------------
-- the report
---------------------------------------------------------------------------

function BR.CountMarks()
	local trail = ns.db and ns.db.char and ns.db.char.trail
	local n = 0
	for _, t in ipairs(type(trail) == "table" and trail or {}) do
		if t.kind == "MARK" and type(t.text) == "string" and t.text:find("^marked:") then n = n + 1 end
	end
	return n
end

local function InTheirWords(words)
	words = BR.Scrub(words or "", nil)
	return words ~= "" and words or "(none)"
end

-- text, aliases, cut. Over the cap the oldest of the trail goes, 25 lines at a
-- time, and the report says so.
function BR.Compose(categoryKey, words)
	local c = CategoryOf(categoryKey)
	local marks = BR.CountMarks()
	BR.marks = marks
	local top = {
		"What went wrong: " .. c.en,
		"In their words: " .. InTheirWords(words),
		("Marks in the trail: %d"):format(marks),
	}
	local trail = ns.db and ns.db.char and ns.db.char.trail
	local length = type(trail) == "table" and #trail or 0
	local skip = 0
	local text, aliases = ns.FullReport({ top = top, trailSkip = skip })
	while #text > BR.CAP and skip < length do
		skip = skip + 25
		text, aliases = ns.FullReport({ top = top, trailSkip = skip })
	end
	if #text > BR.CAP then text = BR.CutUTF8(text, BR.CAP) end
	return text, aliases, skip > 0
end

---------------------------------------------------------------------------
-- Mark this moment
---------------------------------------------------------------------------

local function Ask(fn, ...)
	local a = Plain1(fn, ...)
	return a
end

local KINDS = { "res", "cure", "courtesy", "ask", "pet", "thank", "care", "bond" }

local function Yes(v) return v and "yes" or "no" end

local function ButtonLine()
	local parts = {}
	local CF = ns.CureFight
	if CF and CF.Button then
		for index = 1, 2 do
			local b = CF:Button(index)
			if b then
				parts[#parts + 1] = ("cure %d shown %s alpha %.2f"):format(index, Yes(b:IsShown()),
					tonumber(b:GetAlpha()) or 0)
			end
		end
		local last = CF.LastFight and CF.LastFight()
		if last then
			parts[#parts + 1] = ("last fight %d reads, %d withheld"):format(last.reads or 0, last.secret or 0)
		end
	end
	local BF = ns.BreakFree
	if BF and BF.State then
		local s = BF.State()
		local b = BF.Button and BF:Button()
		parts[#parts + 1] = ("break free shown %s (lit %s, afflicted %s, guessed %s, always %s)"):format(
			Yes(b and b:IsShown()), Yes(s.lit), Yes(s.afflicted), Yes(s.guessed), Yes(s.always))
	end
	local MP = ns.MendPet
	if MP and MP.Button then
		local b = MP:Button()
		if b then
			parts[#parts + 1] = ("Mend Pet shown %s alpha %.2f"):format(Yes(b:IsShown()), tonumber(b:GetAlpha()) or 0)
		end
	end
	return "buttons: " .. (#parts > 0 and table.concat(parts, "; ") or "none made")
end

-- Reads Lua state only and writes nothing secure, so it is safe in a fight.
function ns.MarkMoment()
	local _, instance = Plain1(_G.IsInInstance)
	local map = type(_G.C_Map) == "table" and Ask(_G.C_Map.GetBestMapForUnit, "player") or nil
	ns.Trail("MARK", ("marked: in a fight %s; %s; map %s, a capital %s"):format(
		Yes(InCombatLockdown()), tostring(instance), tostring(map), tostring(ns.InCity and ns.InCity())))

	local entry = ns.Prompt and ns.Prompt.Showing and ns.Prompt:Showing()
	if type(entry) == "table" then
		local kind = "buff"
		for _, k in ipairs(KINDS) do
			if entry[k] then
				kind = k
				break
			end
		end
		ns.Trail("MARK", ("prompt: %s %s, %s"):format(kind, tostring(entry.buff and entry.buff.key),
			tostring(entry.reason)), type(entry.name) == "string" and entry.name or nil)
	else
		local held = ns.OptionsPage and ns.OptionsPage.HoldLines and ns.OptionsPage.HoldLines() or {}
		for _, line in ipairs(held) do ns.Trail("MARK", "held back: " .. ns.PlainText(line)) end
		if #held == 0 then ns.Trail("MARK", "prompt: empty, nothing holding it back") end
	end

	local picked = ns.Prompt and ns.Prompt.state and ns.Prompt.state.pickedFrom
	for i = 1, math.min(3, type(picked) == "table" and #picked or 0) do
		local e = picked[i]
		ns.Trail("MARK", ("queue %d: %s, %s, priority %s"):format(i, tostring(e.buff and e.buff.key),
			tostring(e.reason), tostring(e.priority)), type(e.name) == "string" and e.name or nil)
	end

	ns.Trail("MARK", ButtonLine())
	if ns.addon and ns.addon.Print then
		ns.addon:Print(L["Marked this moment. Report a bug will show what Manners saw then."])
	end
end

-- A button of its own so a key can reach it: a plain one, so it works in a
-- fight, never shown.
do
	local mark = CreateFrame("Button", "MannersMark", UIParent)
	mark:RegisterForClicks("AnyDown")
	mark:Hide()
	mark:SetScript("OnClick", function() ns.Guard("mark this moment", ns.MarkMoment) end)
	BR.markButton = mark
	_G["BINDING_NAME_CLICK MannersMark:LeftButton"] = L["Mark this moment"]
end

---------------------------------------------------------------------------
-- the hold-back watch
---------------------------------------------------------------------------

local lastKind
function ns.NoteHold()
	local _, line, _, _, _, _, _, kind = ns.LauncherState()
	if kind ~= lastKind then
		lastKind = kind
		ns.Trail("hold", tostring(kind) .. ": " .. ns.PlainText(line))
	end
end

---------------------------------------------------------------------------
-- the chat link
---------------------------------------------------------------------------

BR.LINK = "|cff71d5ff|Haddon:Manners:report|h[" .. L["Report it"] .. "]|h|r"

local offered, pending = false, false

local function Offer()
	pending = false
	if offered then return end
	offered = true
	ns.addon:Print(L["Manners hit a snag. %s"]:format(BR.LINK))
end

function ns.OfferReport()
	if offered then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	Offer()
end

local registered
function BR.RegisterLink()
	local registry = rawget(_G, "EventRegistry")
	if type(registry) ~= "table" or type(registry.RegisterCallback) ~= "function" or registered == registry then return end
	registered = registry
	registry:RegisterCallback("SetItemRef", function(_, link)
		if type(link) == "string" and link:find("^addon:Manners:report") then
			ns.Guard("report link", function() BR.Show() end)
		end
	end, BR)
end
BR.RegisterLink()

do
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			if pending then Offer() end
		elseif event == "PLAYER_LOGIN" then
			BR.RegisterLink()
			-- Never on the scan: its own slow ticker.
			if C_Timer and C_Timer.NewTicker then
				C_Timer.NewTicker(2, function() ns.Guard("hold watch", ns.NoteHold) end)
			end
		end
	end)
	BR.eventFrame = frame
end

---------------------------------------------------------------------------
-- the window
---------------------------------------------------------------------------

local WIDTH, HEIGHT, PAD = 580, 700, 20
local INNER = WIDTH - 2 * PAD
local window

local function SelectAll(box, hint)
	box:SetFocus()
	box:HighlightText()
	hint:Show()
end

-- A read-only box: what is typed is put back.
local function ReadOnly(box)
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self.fixed ~= nil then
			self:SetText(self.fixed)
			self:HighlightText()
		end
	end)
end

local function Fill(box, text)
	box.fixed = text
	box:SetText(text)
	box:SetCursorPosition(0)
end

local function ShowCopied(box)
	local note = box.copied
	if not note then return end
	box.copiedAt = (box.copiedAt or 0) + 1
	local mine = box.copiedAt
	note:Show()
	if C_Timer and C_Timer.After then
		C_Timer.After(3, function()
			if box.copiedAt == mine then note:Hide() end
		end)
	end
end

local function CopyKey(box, key)
	if key == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then ShowCopied(box) end
end

local function Build()
	local W = ns.WindowWidgets
	local T = W.Theme
	window = CreateFrame("Frame", "MannersBugReport", UIParent)
	window:SetSize(WIDTH, HEIGHT)
	window:SetFrameStrata("HIGH")
	if window.SetToplevel then window:SetToplevel(true) end
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	window:Hide()
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "MannersBugReport") end
	window:SetScript("OnDragStart", function(self) self:StartMoving() end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)
	end)

	local body = W.Solid(window, "BACKGROUND", -6, { 0.04, 0.04, 0.06, 0.96 })
	body:SetAllPoints()
	W.Border(window, T.fieldEdge)

	local function Label(parent, text, x, y, width, font, colour)
		local fs = W.Wrapping(W.Text(parent, font or T.fonts.label, colour or T.ink))
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
		fs:SetWidth(width or INNER)
		fs:SetText(text)
		return fs
	end

	window.title = Label(window, L["Report a bug"], PAD, 14, INNER, T.fonts.large, T.gold)
	Label(window, L["1. What went wrong?"], PAD, 46, INNER, T.fonts.normal, T.gold)

	-- six radio buttons
	window.radios = {}
	window.chosen = nil
	local function Choose(key)
		window.chosen = key
		for _, r in ipairs(window.radios) do if r.key == key then r.dot:Show() else r.dot:Hide() end end
		window.make:Enable()
		window.makeHint:Hide()
	end
	for i, c in ipairs(BR.CATEGORIES) do
		local r = CreateFrame("Button", nil, window)
		r:SetSize(INNER, 20)
		r:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -(68 + (i - 1) * 22))
		r:RegisterForClicks("LeftButtonUp")
		r.key = c.key
		r.box = CreateFrame("Frame", nil, r)
		r.box:SetSize(14, 14)
		r.box:SetPoint("LEFT", r, "LEFT", 0, 0)
		W.Field(r.box)
		r.dot = W.Solid(r.box, "ARTWORK", 1, T.gold)
		r.dot:SetPoint("TOPLEFT", r.box, "TOPLEFT", 3, -3)
		r.dot:SetPoint("BOTTOMRIGHT", r.box, "BOTTOMRIGHT", -3, 3)
		r.dot:Hide()
		r.label = W.Text(r, T.fonts.label, T.ink)
		r.label:SetPoint("LEFT", r.box, "RIGHT", 8, 0)
		r.label:SetText(c.name)
		r:SetScript("OnClick", function() ns.Guard("report a bug", Choose, c.key) end)
		window.radios[i] = r
	end

	Label(window, L["In a few words"], PAD, 208, INNER, T.fonts.normal, T.gold)
	local wordsField = CreateFrame("Frame", nil, window)
	wordsField:SetSize(INNER, 56)
	wordsField:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -228)
	W.Field(wordsField)
	local words = CreateFrame("EditBox", nil, wordsField)
	words:SetMultiLine(true)
	words:SetAutoFocus(false)
	words:SetMaxLetters(300)
	W.SetFont(words, T.fonts.label)
	words:SetTextColor(T.ink[1], T.ink[2], T.ink[3])
	words:SetTextInsets(8, 8, 6, 6)
	words:SetPoint("TOPLEFT", wordsField, "TOPLEFT", 0, 0)
	words:SetSize(INNER, 56)
	words:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	window.words = words

	-- 2. Make the report
	window.make = W.Button(window, L["2. Make the report"], function() BR.Make() end)
	window.make:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -296)
	window.make:Disable()
	window.makeHint = Label(window, L["Choose what went wrong first."], PAD + window.make:GetWidth() + 12, 301,
		INNER - window.make:GetWidth() - 12, T.fonts.small, T.hint)

	-- 3. Send it
	local res = CreateFrame("Frame", nil, window)
	res:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -334)
	res:SetSize(INNER, 320)
	res:Hide()
	window.res = res
	Label(res, L["3. Send it"], 0, 0, INNER, T.fonts.normal, T.gold)

	window.waitNote = Label(res, L["The full report waits for the fight to end. The short summary works now."], 0, 24, INNER)
	window.shortBtn = W.Button(res, L["Show the short summary"], function() BR.ShowShort() end)
	window.shortBtn:SetPoint("TOPLEFT", res, "TOPLEFT", 0, -58)

	local part = CreateFrame("Frame", nil, res)
	part:SetPoint("TOPLEFT", res, "TOPLEFT", 0, -22)
	part:SetSize(INNER, 298)
	window.part = part

	local function Copier(parent, y, labelText, height, multi)
		local label = Label(parent, labelText, 0, y, INNER - 190, T.fonts.label)
		local field = CreateFrame("Frame", nil, parent)
		field:SetSize(INNER, height)
		field:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(y + 22))
		W.Field(field)
		local box
		if multi then
			local scroll = CreateFrame("ScrollFrame", nil, field)
			scroll:SetAllPoints(field)
			scroll:EnableMouseWheel(true)
			box = CreateFrame("EditBox", nil, scroll)
			box:SetMultiLine(true)
			box:SetSize(INNER, height)
			scroll:SetScrollChild(box)
			scroll:SetScript("OnMouseWheel", function(self, delta)
				local range = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
				local now = self:GetVerticalScroll() or 0
				self:SetVerticalScroll(math.max(0, math.min(range, now - delta * 40)))
			end)
			box.scroll = scroll
		else
			box = CreateFrame("EditBox", nil, field)
			box:SetMultiLine(false)
			box:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
			box:SetSize(INNER, height)
		end
		box:SetAutoFocus(false)
		box:SetMaxLetters(0)
		W.SetFont(box, T.fonts.small)
		box:SetTextColor(T.inkSoft[1], T.inkSoft[2], T.inkSoft[3])
		box:SetTextInsets(8, 8, 6, 6)
		ReadOnly(box)
		box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		box:SetScript("OnKeyDown", function(self, key) ns.Guard("report a bug", CopyKey, self, key) end)
		-- Select all, with its hint and the "Copied" note beside it.
		local hint = W.Text(parent, T.fonts.small, T.hint)
		local select = W.Button(parent, L["Select all"], function() SelectAll(box, hint) end)
		select:SetPoint("TOPRIGHT", parent, "TOPLEFT", INNER, -y + 2)
		hint:SetPoint("RIGHT", select, "LEFT", -8, 0)
		hint:SetText(L["Press Ctrl+C to copy."])
		hint:Hide()
		local copied = W.Text(parent, T.fonts.small, T.gold)
		copied:SetPoint("RIGHT", select, "LEFT", -8, 0)
		copied:SetText(L["Copied"])
		copied:Hide()
		box.copied, box.hint, box.select = copied, hint, select
		return box, label
	end

	window.boxA = Copier(part, 0, L["1. Open this link in your browser"], 26, false)
	window.boxB = Copier(part, 58, L["2. Copy the report and paste it into the issue's report box"], 140, true)
	window.cfNote = Label(part, L["No GitHub account? A comment on the Manners page on CurseForge works too."], 0, 232, INNER,
		T.fonts.small, T.hint)
	window.marksNote = Label(part, "", 0, 252, INNER, T.fonts.small, T.ink)
	window.cutNote = Label(part, L["The report was too long, so the oldest of what happened lately was left out."], 0, 280,
		INNER, T.fonts.small, T.remove)

	local close = W.Button(window, L["Close"], function() window:Hide() end)
	close:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 14)
	window.close = close
end

local function MarksLine(n)
	if n > 0 then
		if n == 1 then return L["This report holds 1 mark."] end
		return L["This report holds %d marks."]:format(n)
	end
	return L["No marks in this report. Next time, press Mark this moment (its key is on Diagnostics, or use the minimap menu) the moment it goes wrong."]
end

local function Marks(n)
	window.marksNote:SetText(MarksLine(n))
end

function BR.Make()
	if not window or not window.chosen then return end
	local key, words = window.chosen, window.words:GetText() or ""
	window.res:Show()
	if InCombatLockdown() then
		-- Nothing is gathered in a fight: the short summary is offered instead.
		window.part:Hide()
		window.waitNote:Show()
		window.shortBtn:Show()
		return
	end
	window.waitNote:Hide()
	window.shortBtn:Hide()
	local text, aliases, cut = BR.Compose(key, words)
	Fill(window.boxA, BR.URL(key, words, aliases))
	Fill(window.boxB, text)
	window.boxA.hint:Hide()
	window.boxB.hint:Hide()
	Marks(BR.marks or 0)
	if cut then window.cutNote:Show() else window.cutNote:Hide() end
	window.part:Show()
end

-- In a fight: the short summary in the report box, and the link as usual.
function BR.ShowShort()
	if not window or not window.chosen then return end
	local c = CategoryOf(window.chosen)
	local words = window.words:GetText() or ""
	local text = "What went wrong: " .. c.en .. "\nIn their words: " .. InTheirWords(words) .. "\n" .. ns.ShortReport()
	Fill(window.boxA, BR.URL(window.chosen, words, nil))
	Fill(window.boxB, text)
	window.boxA.hint:Hide()
	window.boxB.hint:Hide()
	Marks(BR.CountMarks())
	window.cutNote:Hide()
	window.waitNote:Hide()
	window.shortBtn:Hide()
	window.part:Show()
end

function BR.Show()
	if not window then Build() end
	window:Show()
	if window.Raise then window:Raise() end
end

function BR.Window() return window end
