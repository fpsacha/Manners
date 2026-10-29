-- Hunt 40: the text on the look picker's cards.
--
-- The pictures on the cards (Textures/Previews, drawn by
-- tools/make_look_previews.py) had the English sample "Anna Aim" and "buffed
-- you" baked into them, so a player on any of the other seven languages saw
-- English on every card. The pictures now carry no text, and the picker
-- (Options/Window/WidgetsTheme.lua) writes the two lines live over each, at
-- the rectangles the tool recorded for the look (ns.Looks.previewText), as the
-- look writes them: the sample name, a name and so not translated, and the
-- reason in the client's own words (the prompt's own default for it,
-- L["buffed you"]).
--
-- What it promises: every card has its two lines at the recorded rectangles,
-- in the recorded face, size (scaled with the picture), colour, shadow and
-- outline, at any width of the page; the reason is what each client's locale
-- file says for it; the face is the look's own only where the look uses it on
-- the prompt (Latin clients, the player's font the default one); a line wider
-- than its rectangle is drawn smaller and then left to the client to cut; a
-- greyed-out control greys the text, and a look without a picture has none;
-- nothing runs per frame; the pictures hold no text; and the recorded data is
-- complete and current.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "hunt40-cards:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session with the options window open on Look, everything put back.
-- `spec.locale`: the client's language. `body(ns, UI, row)`.
local function session(scenario, spec, body)
	Mock.reset()
	if spec.locale then Mock.locale = spec.locale end
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions("appearance", true)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards and UI.RowShown("appearance.style")) then
			fail(scenario, "SKIPPED -- the gallery is not on the Look page")
			return
		end
		body(ns, UI, row)
		noErrors(scenario, ns)
	end)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function registry(ns)
	local _, sorting = ns.Looks.Choices()
	return sorting
end

local function cardFor(row, key)
	for i = 1, #row.cards do
		local card = row.cards[i]
		if card:IsShown() and card.key == key then return card end
	end
end

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

local NAMES = { "name", "reason" }

-- What the locale file says for the owed reason, read from the file itself.
local function fileReason(locale)
	local code = locale == "esMX" and "esES" or locale
	local text = slurp(dir .. "/Locales/" .. code .. ".lua")
	return text and text:match('L%["buffed you"%] = "([^"]*)"')
end

-- Where a line sits, as the client would place it: the offsets of its two
-- corners from the picture's top left.
local function box(fs, card)
	local p = fs.points
	if #p ~= 2 then return nil, "has " .. #p .. " anchors, not two" end
	for _, point in ipairs(p) do
		if point[2] ~= card.ground then return nil, "is not anchored to the picture" end
	end
	if p[1][1] ~= "TOPLEFT" or p[1][3] ~= "TOPLEFT" or p[2][1] ~= "BOTTOMRIGHT" or p[2][3] ~= "TOPLEFT" then
		return nil, "is anchored by the wrong corners"
	end
	return { p[1][4], p[1][5], p[2][4], p[2][5] }
end

local function wholeUnits(v)
	local n = math.max(1, math.floor(math.abs(v) + 0.5))
	return v < 0 and -n or n
end

-- ------------------------------------------------------------------ the rectangles
do
	local scenario = "hunt40-cards: every card has its two text overlays at the rectangles recorded for its look, at any width"
	session(scenario, {}, function(ns, UI, row)
		local Looks = ns.Looks
		local sizes = {}
		for _, width in ipairs({ 612, 1000, 480, 330 }) do
			row:Layout(width)
			sizes[width] = {}
			for _, key in ipairs(registry(ns)) do
				local card = cardFor(row, key)
				local at = Looks.previewText[key]
				if not card then
					fail(scenario, key .. " has no card")
				elseif not at then
					fail(scenario, key .. " has no text recorded: run tools/make_look_previews.py")
				else
					local w, h = card.ground._width, card.ground._height
					sizes[width][key] = {}
					for _, name in ipairs(NAMES) do
						local spec, fs = at[name], card.lines and card.lines[name]
						local where = ("%s's %s line at %d wide"):format(key, name, width)
						if not spec then
							fail(scenario, key .. " records no " .. name .. " line")
						elseif not fs or not fs:IsShown() then
							fail(scenario, where .. " is not shown")
						else
							local b, why = box(fs, card)
							if not b then
								fail(scenario, where .. " " .. why)
							else
								local want = { spec.l * w, -spec.t * h, spec.r * w, -spec.b * h }
								for i = 1, 4 do
									if not near(b[i], want[i]) then
										fail(scenario, ("%s: corner %d is at %.3f, the recorded rectangle puts it at %.3f (picture %.1f x %.1f)")
											:format(where, i, b[i], want[i], w, h))
										break
									end
								end
								if b[1] < 0 or b[2] > 0 or b[3] > w or b[4] < -h then
									fail(scenario, where .. " runs outside its picture")
								end
							end
							-- What it says.
							local text = name == "name" and "Anna Aim" or ns.L["buffed you"]
							if fs:GetText() ~= text then
								fail(scenario, ("%s says %q, not %q"):format(where, tostring(fs:GetText()), text))
							end
							-- How it is written: the size scales with the picture, a line
							-- is cut and not wrapped, justified as the look justifies it.
							local font = fs._font
							local base = math.max(5, math.floor(spec.size * h + 0.5))
							if not font then
								fail(scenario, where .. " has no font")
							else
								sizes[width][key][name] = font.size
								if font.size > base or font.size < math.floor(base * 0.8 + 0.5) then
									fail(scenario, ("%s is written at %s, the look's size for this picture is %d"):format(where,
										tostring(font.size), base))
								end
								if (font.flags or "") ~= (spec.flags or "") then
									fail(scenario, ("%s has outline %q, the look's is %q"):format(where, tostring(font.flags), spec.flags or ""))
								end
							end
							if fs._wordWrap ~= false then fail(scenario, where .. " wraps instead of being cut") end
							if fs._justifyH ~= spec.h or fs._justifyV ~= spec.v then
								fail(scenario, ("%s is justified %s/%s, the look's is %s/%s"):format(where, tostring(fs._justifyH),
									tostring(fs._justifyV), spec.h, spec.v))
							end
							local c = fs._textColor
							if not (c and near(c[1], spec.color[1]) and near(c[2], spec.color[2]) and near(c[3], spec.color[3])
								and near(c[4], spec.color[4])) then
								fail(scenario, where .. " is not in the look's colour")
							end
							local so, sc = fs._shadowOffset, fs._shadowColor
							if spec.shadow then
								local sx, sy = wholeUnits(spec.shadow.x * h), wholeUnits(spec.shadow.y * h)
								if not (so and so[1] == sx and so[2] == sy) then
									fail(scenario, ("%s has shadow offset %s,%s, the look's is %d,%d"):format(where,
										so and tostring(so[1]) or "none", so and tostring(so[2]) or "none", sx, sy))
								end
								local s = spec.shadow.color
								if not (sc and near(sc[1], s[1]) and near(sc[2], s[2]) and near(sc[3], s[3]) and near(sc[4], s[4])) then
									fail(scenario, where .. " has not the look's shadow colour")
								end
							elseif (so and (so[1] ~= 0 or so[2] ~= 0)) and not (sc and sc[4] == 0) then
								fail(scenario, where .. " has a shadow where the look has none")
							end
						end
					end
				end
			end
		end
		-- The letters are drawn with the picture: smaller on a narrower card.
		for _, key in ipairs(registry(ns)) do
			for _, name in ipairs(NAMES) do
				local big, small = sizes[612][key] and sizes[612][key][name], sizes[480][key] and sizes[480][key][name]
				if big and small and not (big > small) then
					fail(scenario, ("%s's %s line is %s at 612 wide and %s at 480: not scaled with its picture"):format(key, name,
						tostring(big), tostring(small)))
				end
			end
		end
		-- A card handed another rectangle (its look re-recorded under it) is
		-- placed anew at once, with no layout in between.
		local at = ns.Looks.previewText.luxe
		local moved = { l = at.name.l + 0.05, t = at.name.t, r = at.name.r, b = at.name.b, h = at.name.h, v = at.name.v,
			size = at.name.size, color = at.name.color, shadow = at.name.shadow }
		ns.Looks.previewText.luxe = { name = moved, reason = at.reason }
		row:Refresh()
		local card = cardFor(row, "luxe")
		local b = card and box(card.lines.name, card)
		if not (b and near(b[1], moved.l * card.ground._width)) then
			fail(scenario, "a card given another rectangle did not move its name")
		end
		ns.Looks.previewText.luxe = at
		row:Refresh()
	end)
end

-- ------------------------------------------------------------------ the languages
do
	local LOCALES = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }
	for _, locale in ipairs(LOCALES) do
		local scenario = "hunt40-cards: the reason on every card is the client's own translation (" .. locale .. ")"
		session(scenario, { locale = locale }, function(ns, UI, row)
			local want = locale == "enUS" and "buffed you" or fileReason(locale)
			if not want then
				fail(scenario, "SKIPPED -- the locale file has no line for it")
				return
			end
			if locale ~= "enUS" and want == "buffed you" then fail(scenario, "the locale file does not translate it") end
			if ns.L["buffed you"] ~= want then
				fail(scenario, ("the client says %q, its locale file says %q"):format(ns.L["buffed you"], want))
			end
			-- It is what the prompt itself says by default, not a second string.
			if ns.defaults.profile.prompt.reasonOwed ~= want then
				fail(scenario, "the prompt's default reason is not the one the cards write")
			end
			local seen = 0
			for _, key in ipairs(registry(ns)) do
				local card = cardFor(row, key)
				if card then
					seen = seen + 1
					if card.lines.reason:GetText() ~= want then
						fail(scenario, ("the %s card says %q, the client's words are %q"):format(key,
							tostring(card.lines.reason:GetText()), want))
					end
					if card.lines.name:GetText() ~= "Anna Aim" then
						fail(scenario, ("the %s card's name is %q"):format(key, tostring(card.lines.name:GetText())))
					end
				end
			end
			if seen < 6 then fail(scenario, "only " .. seen .. " cards") end
		end)
	end

	-- A client with no translation for it reads English, as every string does.
	local scenario = "hunt40-cards: the cards ask for no string of their own"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local src = slurp(dir .. "/Options/Window/WidgetsTheme.lua")
		local keys = {}
		for key in (src or ""):gmatch('L%["([^"]*)"%]') do keys[key] = true end
		for key in pairs(keys) do
			if key ~= "buffed you" then fail(scenario, ("WidgetsTheme asks for the string %q, new to every locale"):format(key)) end
		end
		if not keys["buffed you"] then fail(scenario, "the picker does not use the prompt's own reason string") end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the faces
-- The face a look writes a line in on the prompt itself, for a client and a
-- font choice: what the card holds the overlay to.
local function promptFace(ns, key, which)
	ns.db.profile.prompt.style = key
	ns.Prompt:ApplyStyle()
	local fs = ns.Prompt:Regions()[which]
	return fs and fs._font and fs._font.path
end

do
	for _, locale in ipairs({ "enUS", "deDE", "koKR", "zhCN" }) do
		local scenario = "hunt40-cards: each line is in the face its look writes it in on the prompt (" .. locale .. ")"
		session(scenario, { locale = locale }, function(ns, UI, row)
			local latin = locale == "enUS" or locale == "deDE"
			local faces = 0
			for _, key in ipairs(registry(ns)) do
				local card = cardFor(row, key)
				if card then
					for _, pair in ipairs({ { "name", "name" }, { "reason", "sub" } }) do
						local name, region = pair[1], pair[2]
						local got = card.lineFace and card.lineFace[name]
						local fs = card.lines[name]
						local spec = ns.Looks.previewText[key][name]
						local worn = promptFace(ns, key, region)
						if got ~= worn then
							fail(scenario, ("the %s card writes its %s in %s, its look writes it in %s"):format(key, name,
								tostring(got), tostring(worn)))
						end
						if fs._font and fs._font.path ~= got then
							fail(scenario, ("the %s card's %s line is set in %s, not %s"):format(key, name,
								tostring(fs._font.path), tostring(got)))
						end
						if spec.font then
							faces = faces + 1
							local want = latin and spec.font or "font.ttf"
							if got ~= want then
								fail(scenario, ("the %s card's %s is in %s on a %s client, not %s"):format(key, name,
									tostring(got), locale, want))
							end
						end
					end
				end
			end
			if faces < 4 then fail(scenario, "SKIPPED -- only " .. faces .. " lines have a face of their own") end
		end)
	end

	-- A font the player chose is theirs on the cards as on the prompt.
	local scenario = "hunt40-cards: a font the player chose replaces the look's own face on the cards"
	session(scenario, {}, function(ns, UI, row)
		local LSM = LibStub("LibSharedMedia-3.0")
		LSM:Register("font", "Hunt40 Face", "Interface\\AddOns\\Hunt40\\Face.ttf")
		ns.db.profile.prompt.font = "Hunt40 Face"
		ns.RefreshOptionsDisplay()
		for _, key in ipairs(registry(ns)) do
			local card = cardFor(row, key)
			for _, name in ipairs(NAMES) do
				if card and card.lines[name]._font.path ~= "Interface\\AddOns\\Hunt40\\Face.ttf" then
					fail(scenario, ("the %s card's %s is in %s, not the player's font"):format(key, name,
						tostring(card.lines[name]._font.path)))
				end
				local fs = card and card.lines[name]
				if fs and card.lineFace[name] ~= promptFace(ns, key, name == "name" and "name" or "sub") then
					fail(scenario, ("the %s card's %s is not in the face the prompt uses"):format(key, name))
				end
			end
		end
		ns.db.profile.prompt.font = ns.defaults.profile.prompt.font
		ns.RefreshOptionsDisplay()
		local ribbon = cardFor(row, "ribbon")
		if ribbon and ribbon.lines.name._font.path ~= "Fonts\\MORPHEUS.TTF" then
			fail(scenario, "the ribbon's face did not come back with the default font")
		end
	end)

	-- A font file the client refuses leaves the client's own in its place.
	scenario = "hunt40-cards: a face the client cannot load gives way to its own font"
	Mock.reset()
	Mock.badFonts = { ["Fonts\\MORPHEUS.TTF"] = true }
	session(scenario, {}, function(ns, UI, row)
		Mock.badFonts = { ["Fonts\\MORPHEUS.TTF"] = true }
		ns.RefreshOptionsDisplay()
		for _, key in ipairs({ "ribbon", "letter", "leather" }) do
			local card = cardFor(row, key)
			local font = card and card.lines.name._font
			if not (font and font.path == STANDARD_TEXT_FONT) then
				fail(scenario, ("the %s card's name has no font when its face will not load"):format(key))
			end
			if card and card.lines.name:GetText() ~= "Anna Aim" then fail(scenario, key .. "'s name is blank") end
		end
		Mock.badFonts = nil
	end)
end

-- ------------------------------------------------------------------ fit
do
	local scenario = "hunt40-cards: a long German reason is drawn smaller to fit its rectangle, then cut"
	session(scenario, { locale = "deDE" }, function(ns, UI, row)
		row:Layout(612)
		local card = cardFor(row, "glass")
		local spec = ns.Looks.previewText.glass.reason
		local w, h = card.ground._width, card.ground._height
		local room = (spec.r - spec.l) * w
		local base = math.max(5, math.floor(spec.size * h + 0.5))
		local least = math.max(5, math.floor(base * 0.8 + 0.5))
		local fs = card.lines.reason
		local function with(text)
			rawset(ns.L, "buffed you", text)
			row:Refresh()
			row:Layout(612)
		end
		local function width(text, size) return #text:gsub("[\128-\191]", "") * size * 0.5 end

		-- The client's own German fits as it is.
		local german = fileReason("deDE")
		with(german)
		if fs._font.size ~= base then
			fail(scenario, ("the client's own German reason is drawn at %d, not the %d the look asks for"):format(fs._font.size, base))
		end

		-- Wider than the rectangle at the look's size, narrower at a fifth less:
		-- drawn smaller, and then it fits.
		local n = 1
		while width(("ä"):rep(n), base) <= room + 0.5 do n = n + 1 end
		local medium = ("ä"):rep(n)
		if width(medium, least) > room then
			fail(scenario, "SKIPPED -- cannot make a line that fits only once shrunk")
		else
			with(medium)
			if fs:GetText() ~= medium then fail(scenario, "the shrunk line's text changed") end
			if not (fs._font.size < base and fs._font.size >= least) then
				fail(scenario, ("a line %.0f wide in a %.0f room is drawn at %d, between %d and %d expected"):format(
					width(medium, base), room, fs._font.size, least, base - 1))
			end
			if width(medium, fs._font.size) > room + 0.5 then
				fail(scenario, ("a line drawn at %d is still %.1f wide in a %.1f room"):format(fs._font.size,
					width(medium, fs._font.size), room))
			end
			-- And it is no smaller than it has to be.
			if fs._font.size < base - 1 and width(medium, fs._font.size + 1) <= room + 0.5 then
				fail(scenario, "the line was drawn smaller than it had to be")
			end
		end

		-- Far too long: drawn at the smallest size and left cut to the client's
		-- ellipsis (no wrapping), the text itself whole.
		local long = german:rep(6, " ")
		with(long)
		if fs._font.size ~= least then
			fail(scenario, ("a line far too long is drawn at %d, not the smallest %d"):format(fs._font.size, least))
		end
		if fs:GetText() ~= long then fail(scenario, "a long line's text was cut by the addon") end
		if fs._wordWrap ~= false then fail(scenario, "a long line wraps over the next one") end
		local b = box(fs, card)
		if not (b and near(b[3] - b[1], room)) then fail(scenario, "a long line's room is not its rectangle") end
		-- The name is not translated and is not shrunk by a long reason.
		if card.lines.name:GetText() ~= "Anna Aim" then fail(scenario, "the name changed with the reason") end
		if card.lines.name._font.size < math.floor(ns.Looks.previewText.glass.name.size * h + 0.5) then
			fail(scenario, "the name was shrunk to fit the reason")
		end
		-- Back to the translation the client has.
		rawset(ns.L, "buffed you", german)
		row:Refresh()
	end)
end

-- ------------------------------------------------------------------ greyed out, no picture, no timers
do
	local scenario = "hunt40-cards: a greyed-out control greys the text, and a look with no picture has none"
	session(scenario, {}, function(ns, UI, row)
		local def = ns.optionsTable.args.appearance.args.style
		local was = def.disabled
		def.disabled = function() return true end
		ns.RefreshOptionsDisplay()
		for _, key in ipairs(registry(ns)) do
			local card = cardFor(row, key)
			for _, name in ipairs(NAMES) do
				local fs, spec = card and card.lines[name], ns.Looks.previewText[key][name]
				if fs then
					local c = fs._textColor
					if fs:GetAlpha() >= 1 then fail(scenario, ("the %s card's %s is not dimmed with its card"):format(key, name)) end
					if not (c and near(c[1], c[2]) and near(c[2], c[3])) then
						fail(scenario, ("the %s card's %s is in colour on a greyed-out card"):format(key, name))
					end
				end
			end
		end
		def.disabled = was
		ns.RefreshOptionsDisplay()
		for _, key in ipairs(registry(ns)) do
			local card = cardFor(row, key)
			for _, name in ipairs(NAMES) do
				local fs, spec = card and card.lines[name], ns.Looks.previewText[key][name]
				local c = fs and fs._textColor
				if fs and not (fs:GetAlpha() == 1 and c and near(c[1], spec.color[1]) and near(c[2], spec.color[2])
					and near(c[3], spec.color[3])) then
					fail(scenario, ("the %s card's %s stayed grey once the control was back"):format(key, name))
				end
			end
		end

		-- A look the tool has not drawn has the addon's mark and no text, whatever
		-- the table holds for it.
		ns.Looks.Register("fake", { name = "Fake -- a made-up look", order = 60, fallback = "glass" })
		ns.Looks.previewText.fake = ns.Looks.previewText.glass
		ns.RefreshOptionsDisplay()
		local fake = cardFor(row, "fake")
		if not fake then
			fail(scenario, "the new look has no card")
		else
			for _, name in ipairs(NAMES) do
				if fake.lines[name]:IsShown() then fail(scenario, "a look with no picture has its " .. name .. " over the placeholder") end
			end
		end
		ns.Looks.list.fake, ns.Looks.previewText.fake = nil, nil
		row:Refresh()
		-- A card whose look loses its picture drops the text, and has it back.
		local picture = ns.Looks.previews.luxe
		ns.Looks.previews.luxe = nil
		row:Refresh()
		local luxe = cardFor(row, "luxe")
		if luxe and (luxe.lines.name:IsShown() or luxe.lines.reason:IsShown()) then
			fail(scenario, "a card whose look lost its picture kept the text over the placeholder")
		end
		ns.Looks.previews.luxe = picture
		row:Refresh()
		if luxe and not (luxe.lines.name:IsShown() and luxe.lines.reason:IsShown()) then
			fail(scenario, "the text did not come back with the picture")
		end
		if ns.Looks.PreviewText("no-such-look") ~= nil then fail(scenario, "an unknown look has text") end
	end)

	scenario = "hunt40-cards: the text is set when the page paints, not on a timer or a frame"
	session(scenario, {}, function(ns, UI, row)
		local before = #Mock.timers
		row:Refresh()
		row:Layout(612)
		row:Layout(480)
		if #Mock.timers ~= before then fail(scenario, ("painting the gallery parked %d timer(s)"):format(#Mock.timers - before)) end
		for _, key in ipairs(registry(ns)) do
			local card = cardFor(row, key)
			for _, name in ipairs(NAMES) do
				local fs = card and card.lines[name]
				if fs and fs.scripts and (fs.scripts.OnUpdate or fs.scripts.OnShow) then
					fail(scenario, ("the %s card's %s has a script"):format(key, name))
				end
			end
			if card and card.scripts.OnUpdate then fail(scenario, key .. "'s card has an OnUpdate") end
		end
	end)
end

-- ------------------------------------------------------------------ the data
local function tempLog(name)
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-" .. name .. "-" .. token .. "-" .. tostring(os.time()) .. ".log"
end

-- What the tool says, run on the tree under test.
local function runTool(flag, name)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local log = tempLog(name)
	os.execute(python .. ' "' .. dir .. '/tools/make_look_previews.py" ' .. flag .. ' > "' .. log .. '" 2>&1')
	local text = slurp(log)
	os.remove(log)
	return text
end

do
	local scenario = "hunt40-cards: every look records its two lines, completely"
	session(scenario, {}, function(ns)
		local Looks = ns.Looks
		local function number(v) return type(v) == "number" and v == v end
		local function colour(c)
			if not (type(c) == "table" and #c == 4) then return false end
			for i = 1, 4 do if not (number(c[i]) and c[i] >= 0 and c[i] <= 1) then return false end end
			return true
		end
		local faces = 0
		for _, key in ipairs(registry(ns)) do
			local at = Looks.previewText[key]
			if not at then
				fail(scenario, key .. " has no text recorded: run tools/make_look_previews.py")
			else
				for _, name in ipairs(NAMES) do
					local spec = at[name]
					if not spec then
						fail(scenario, ("%s records no %s line"):format(key, name))
					else
						local where = key .. "'s " .. name .. " line"
						if not (number(spec.l) and number(spec.t) and number(spec.r) and number(spec.b)
							and 0 <= spec.l and spec.l < spec.r and spec.r <= 1 and 0 <= spec.t and spec.t < spec.b and spec.b <= 1) then
							fail(scenario, where .. "'s rectangle is not inside its picture")
						end
						local icon = Looks.previewIcon[key]
						if icon and spec.l and spec.l < icon.r and spec.r > icon.l and spec.t and spec.t < icon.b and spec.b > icon.t then
							fail(scenario, where .. " is recorded over the icon")
						end
						if not (spec.h == "LEFT" or spec.h == "CENTER" or spec.h == "RIGHT") then fail(scenario, where .. " has no justification") end
						if not (spec.v == "TOP" or spec.v == "MIDDLE" or spec.v == "BOTTOM") then fail(scenario, where .. " has no vertical justification") end
						if not (number(spec.size) and spec.size > 0.05 and spec.size < 0.5) then fail(scenario, where .. " has no sensible size") end
						if not colour(spec.color) then fail(scenario, where .. " has no colour") end
						if spec.shadow and not (number(spec.shadow.x) and number(spec.shadow.y) and colour(spec.shadow.color)) then
							fail(scenario, where .. " has a shadow that is not numbers")
						end
						if spec.flags ~= nil and type(spec.flags) ~= "string" then fail(scenario, where .. " has flags that are not text") end
						if spec.font ~= nil then
							faces = faces + 1
							if type(spec.font) ~= "string" then fail(scenario, where .. " has a face that is not a path") end
							if type(spec.latin) ~= "boolean" then fail(scenario, where .. " has a face and does not say where it is drawn") end
						elseif spec.latin ~= nil then
							fail(scenario, where .. " is Latin-only and has no face")
						end
					end
				end
			end
		end
		for key in pairs(Looks.previewText) do
			if not Looks.list[key] then fail(scenario, "text is recorded for " .. key .. ", which is not a look") end
		end
		if faces < 4 then fail(scenario, "only " .. faces .. " lines record a face of their own") end
		-- A look the tool has not drawn has none, whatever the table holds.
		Looks.previewText.fake = Looks.previewText.glass
		if Looks.PreviewText("fake") ~= nil then fail(scenario, "a look with no picture was handed text rectangles") end
		Looks.previewText.fake = nil
		if Looks.PreviewText("no-such-look") ~= nil then fail(scenario, "an unknown look has text") end
	end)

	scenario = "hunt40-cards: the recorded text is current with the looks, held by the hash"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local text = runTool("--check", "cards-check")
		if not text then
			fail(scenario, "SKIPPED -- cannot run python")
		elseif text:find("No module named", 1, true) then
			text = nil -- lupa is all the check needs; a machine without it cannot judge
		elseif not text:find("previews current", 1, true) then
			fail(scenario, text:gsub("%s+$", ""):sub(1, 700))
		end
	end
	Mock.reset()

	scenario = "hunt40-cards: the pictures carry no text, which the cards write live"
	Mock.reset()
	ns = load(scenario)
	if ns then
		local text = runTool("--check-bare", "cards-bare")
		if not text then
			fail(scenario, "SKIPPED -- cannot run python")
		elseif text:find("No module named", 1, true) then
			text = nil -- drawing needs Pillow and numpy; a machine without them cannot judge
		elseif not text:find("pictures bare", 1, true) then
			fail(scenario, text:gsub("%s+$", ""):sub(1, 700))
		end
	end
	Mock.reset()
end
