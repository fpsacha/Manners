-- Hunt 41: the tag round the reason on the Luxe card.
--
-- Luxe sets the prompt's reason line in a tag (its pill), sized to the words.
-- The card's picture (Textures/Previews/Preview_luxe.tga) had the tag baked in
-- at the English words' width, so once the words were written live in the
-- player's language (hunt 40) a German, Korean or Chinese reason ran past it.
-- The tool (tools/make_look_previews.py) now leaves the tag out of the picture
-- with the words and records it on the reason line
-- (ns.Looks.previewText.luxe.reason.pill: its edges, how far it reaches past
-- the words on either side, its caps, its layers), and the picker
-- (Options/Window/WidgetsTheme.lua) draws it live round the words it has just
-- measured, in the look's own textures and colours.
--
-- What it promises: on every client language and at any width of the page the
-- Luxe card's tag hugs its live reason -- its lead before the words and its
-- tail after them scaled with the picture, its edges where the look puts them,
-- each layer the look's own file cut at the quarters in the look's colour,
-- under the words and over the icon; the tag's width follows the words, so a
-- German tag is not an English one; what is recorded is the tag the live Luxe
-- prompt wears, not a guess; no other look wears one; a greyed-out card greys
-- the tag with its words; and the recording is complete.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "hunt41-cards:".

local dir, H = ...
local fail, load, drive, strangers, clearClicks, owe = H.fail, H.load, H.drive, H.strangers, H.clearClicks, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- The view the tool cuts the pictures from, in UI units (make_look_previews.py
-- VIEW): what the recorded fractions of the picture's height are of.
local VIEW_H = 62
-- A horizontal three-slice's cuts, as the look and the picker make them.
local CUTS = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
local LOCALES = { "enUS", "deDE", "frFR", "koKR", "zhCN" }

local function near(a, b, tol) return math.abs(a - b) < (tol or 1e-6) end

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

-- Where a region sits, as the client would place it: the offsets of its two
-- corners from the picture's top left, or nil and why.
local function corners(r, card)
	local p = r.points
	if not p or #p ~= 2 then return nil, "has " .. tostring(p and #p) .. " anchors, not two" end
	for _, point in ipairs(p) do
		if point[2] ~= card.ground then return nil, "is not anchored to the picture" end
	end
	if p[1][1] ~= "TOPLEFT" or p[1][3] ~= "TOPLEFT" or p[2][1] ~= "BOTTOMRIGHT" or p[2][3] ~= "TOPLEFT" then
		return nil, "is anchored by the wrong corners"
	end
	return { p[1][4], p[1][5], p[2][4], p[2][5] }
end

local function sameColour(a, b, tol)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 4 do
		if not near(a[i] == nil and 1 or a[i], b[i] == nil and 1 or b[i], tol or 1e-3) then return false end
	end
	return true
end

local function colourText(c)
	if type(c) ~= "table" then return tostring(c) end
	local out = {}
	for i = 1, 4 do out[i] = ("%.3f"):format(c[i] or 1) end
	return table.concat(out, ",")
end

-- The file on disk behind one of the addon's own texture paths.
local function shippedFile(path)
	local rel = tostring(path or ""):match("^Interface\\AddOns\\Manners\\(.+)$")
	if not rel then return nil end
	return dir .. "/" .. rel:gsub("\\", "/") .. ".tga"
end

-- ------------------------------------------------------------------ the tag hugs the words
for _, locale in ipairs(LOCALES) do
	local scenario = "hunt41-cards: the Luxe tag hugs the live reason in every language (" .. locale .. ")"
	session(scenario, { locale = locale }, function(ns, UI, row)
		local W = ns.WindowWidgets
		local spec = ns.Looks.previewText.luxe and ns.Looks.previewText.luxe.reason
		local pill = spec and spec.pill
		if not pill then
			fail(scenario, "Luxe records no tag on its reason line: run tools/make_look_previews.py")
			return
		end
		for _, width in ipairs({ 612, 330 }) do
			row:Layout(width)
			local card = cardFor(row, "luxe")
			if not card then
				fail(scenario, "there is no Luxe card")
				return
			end
			local w, h = card.ground._width, card.ground._height
			local fs = card.lines.reason
			if not (fs and fs:IsShown()) then
				fail(scenario, "the reason line is not shown at " .. width .. " wide")
				return
			end
			local words = W.Measure(fs)
			local room = (spec.r - spec.l) * w
			local left, right = spec.l * w - pill.lead * h, spec.l * w + math.min(words, room) + pill.tail * h
			local top, bottom = pill.t * h, pill.b * h
			local cap = (pill.cap or 0.5) * (bottom - top)
			local wants = {
				{ left, -top, left + cap, -bottom },
				{ left + cap, -top, right - cap, -bottom },
				{ right - cap, -top, right, -bottom },
			}
			if #card.pill < #pill.layers then
				fail(scenario, ("the card draws %d layer(s) of the tag, the look records %d"):format(#card.pill, #pill.layers))
				return
			end
			for i, layer in ipairs(pill.layers) do
				local s = card.pill[i]
				local where = ("the Luxe tag's layer %d at %d wide"):format(i, width)
				if not (s and #s == 3) then
					fail(scenario, where .. " is not three slices")
				else
					for j = 1, 3 do
						local t = s[j]
						local piece = where .. (", slice %d"):format(j)
						if not t:IsShown() then
							fail(scenario, piece .. " is not shown")
						elseif t:GetTexture() ~= layer.file then
							fail(scenario, ("%s is %s, the look's file is %s"):format(piece, tostring(t:GetTexture()), layer.file))
						elseif not sameColour(t._color, layer.color) then
							fail(scenario, ("%s is coloured %s, the look paints it %s"):format(piece, colourText(t._color),
								colourText(layer.color)))
						else
							local tc = t._texCoord
							if not (tc and near(tc[1], CUTS[j][1]) and near(tc[2], CUTS[j][2]) and near(tc[3], 0) and near(tc[4], 1)) then
								fail(scenario, piece .. " is not cut from the file's quarter it belongs to")
							end
							local b, why = corners(t, card)
							if not b then
								fail(scenario, piece .. " " .. why)
							else
								for k = 1, 4 do
									if not near(b[k], wants[i == 0 and 1 or j][k], 1e-3) then
										fail(scenario, ("%s: corner %d is at %.3f, the words put it at %.3f (words %.1f wide, picture %.1f x %.1f)")
											:format(piece, k, b[k], wants[j][k], words, w, h))
										break
									end
								end
							end
							-- Under the words, over the icon.
							if t._layer ~= "ARTWORK" or not ((t._sublevel or 0) > (card.icon._sublevel or 0)) then
								fail(scenario, piece .. " is not drawn over the icon")
							end
							if fs._layer ~= "OVERLAY" then fail(scenario, "the words are not drawn over the tag") end
						end
					end
				end
			end
			for i = #pill.layers + 1, #card.pill do
				for _, t in ipairs(card.pill[i]) do
					if t:IsShown() then fail(scenario, ("the card shows a layer %d the look does not have"):format(i)) end
				end
			end
			-- The words sit inside the tag: after its lead, before its tail,
			-- between its edges.
			local fb = corners(fs, card)
			if fb then
				if fb[1] < left - 1e-6 or fb[1] + math.min(words, room) > right + 1e-6 then
					fail(scenario, ("the words run past the tag at %d wide: words %.2f to %.2f, tag %.2f to %.2f"):format(width,
						fb[1], fb[1] + words, left, right))
				end
				if fb[2] > -top + 1e-6 or fb[4] < -bottom - 1e-6 then
					fail(scenario, ("the tag does not reach round the words at %d wide"):format(width))
				end
			end
		end
	end)
end

-- The tag's width follows the words: the German and the Chinese tags are not
-- the English one, and each is its own words plus the lead and the tail. A
-- session per language of its own, so this stands alone in a narrowed run.
do
	local scenario = "hunt41-cards: the Luxe tag is as wide as its words, not the English ones"
	local width, words = {}, {}
	for _, locale in ipairs({ "enUS", "deDE", "zhCN" }) do
		session(scenario, { locale = locale }, function(ns, UI, row)
			row:Layout(612)
			local card = cardFor(row, "luxe")
			local fs = card and card.lines.reason
			local b = card and card.pillBox
			if not (fs and b) then
				fail(scenario, "the Luxe card has no tag drawn on a " .. locale .. " client")
				return
			end
			width[locale], words[locale] = b[3] - b[1], ns.WindowWidgets.Measure(fs)
			local h = card.ground._height
			local pill = ns.Looks.previewText.luxe.reason.pill
			if not near(width[locale], words[locale] + (pill.lead + pill.tail) * h, 1e-3) then
				fail(scenario, ("on a %s client the tag is %.2f wide round words %.2f wide, with lead and tail %.2f"):format(
					locale, width[locale], words[locale], (pill.lead + pill.tail) * h))
			end
		end)
	end
	if width.enUS and width.deDE and width.zhCN then
		for _, other in ipairs({ "deDE", "zhCN" }) do
			if near(words.enUS, words[other], 1) then
				fail(scenario, ("the %s words measure as the English ones do: the mock cannot tell them apart"):format(other))
			elseif near(width.enUS, width[other], 1) then
				fail(scenario, ("the %s tag is %.1f wide and the English one %.1f: it does not follow its words"):format(
					other, width[other], width.enUS))
			end
		end
	end
end

-- ------------------------------------------------------------------ the prompt's own, and only Luxe's
do
	local scenario = "hunt41-cards: the recorded tag is the one the live Luxe prompt wears, and no other look wears one"
	session(scenario, {}, function(ns, UI, row)
		for _, key in ipairs(registry(ns)) do
			if key ~= "luxe" then
				local at = ns.Looks.previewText[key]
				for _, name in ipairs({ "name", "reason" }) do
					if at and at[name] and at[name].pill then fail(scenario, key .. " records a tag on its " .. name .. " line") end
				end
				local card = cardFor(row, key)
				for _, s in ipairs(card and card.pill or {}) do
					for _, t in ipairs(s) do
						if t:IsShown() then fail(scenario, key .. "'s card wears a tag") end
					end
				end
			end
		end
		local spec = ns.Looks.previewText.luxe and ns.Looks.previewText.luxe.reason
		local pill = spec and spec.pill
		if not pill then
			fail(scenario, "Luxe records no tag: run tools/make_look_previews.py")
			return
		end
		-- The live prompt in Luxe with a favour owed, as the picture was drawn
		-- from (render_prompt.lua's "owed" state).
		local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
		clearClicks(ns)
		ns.db.profile.prompt.style = "luxe"
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local look = ns.Looks.list.luxe
		local sub = ns.Prompt:Regions().sub
		if not (look and look.pillFill and look.pillEdge and look.pillFrame and look.pillH and sub) then
			fail(scenario, "the Luxe look does not expose its tag as it did")
		elseif sub:GetText() ~= ns.L["buffed you"] then
			fail(scenario, ("the prompt's reason reads %q, not the favour"):format(tostring(sub:GetText())))
		else
			local worn = { look.pillFill, look.pillEdge }
			if #pill.layers ~= #worn then
				fail(scenario, ("%d layer(s) recorded, the look draws %d"):format(#pill.layers, #worn))
			end
			for i, slices in ipairs(worn) do
				local layer = pill.layers[i]
				if layer then
					if slices[1]:GetTexture() ~= layer.file then
						fail(scenario, ("layer %d is recorded as %s, the prompt wears %s"):format(i, layer.file, tostring(slices[1]:GetTexture())))
					end
					if not sameColour(slices[1]._color, layer.color) then
						fail(scenario, ("layer %d is recorded %s, the prompt paints it %s"):format(i, colourText(layer.color),
							colourText(slices[1]._color)))
					end
					-- Caps half the height, as the look places its slices.
					if not near(slices[1]._width, (pill.cap or 0.5) * look.pillH, 1e-3) then
						fail(scenario, ("the caps are recorded %.3f of the height, the prompt's are %.3f"):format(pill.cap or 0.5,
							slices[1]._width / look.pillH))
					end
				end
			end
			-- The tag's height, and how far it reaches past the words, as the
			-- look sizes them: the words start half the tag's height in, and
			-- the tag is the words plus its height wide (a unit of rounding).
			if not near((pill.b - pill.t) * VIEW_H, look.pillH, 1e-3) then
				fail(scenario, ("the tag is recorded %.2f tall, the prompt's is %d"):format((pill.b - pill.t) * VIEW_H, look.pillH))
			end
			if not near(pill.lead * VIEW_H, look.pillH / 2, 1e-3) then
				fail(scenario, ("the lead is recorded %.2f, the prompt starts its words %.2f in"):format(pill.lead * VIEW_H, look.pillH / 2))
			end
			local words = sub:GetStringWidth()
			local tail = look.pillFrame._width - words - look.pillH / 2
			if not near(pill.tail * VIEW_H, tail, 0.51) then
				fail(scenario, ("the tail is recorded %.2f, the prompt's tag reaches %.2f past its words"):format(pill.tail * VIEW_H, tail))
			end
		end
		restore()
	end)
end

-- ------------------------------------------------------------------ greyed out
do
	local scenario = "hunt41-cards: a greyed-out card greys its tag with its words"
	session(scenario, {}, function(ns, UI, row)
		local pill = ns.Looks.previewText.luxe and ns.Looks.previewText.luxe.reason and ns.Looks.previewText.luxe.reason.pill
		if not pill then
			fail(scenario, "Luxe records no tag: run tools/make_look_previews.py")
			return
		end
		local def = ns.optionsTable.args.appearance.args.style
		local was = def.disabled
		def.disabled = function() return true end
		ns.RefreshOptionsDisplay()
		local card = cardFor(row, "luxe")
		if not card then
			fail(scenario, "there is no Luxe card")
			return
		end
		for i, layer in ipairs(pill.layers) do
			for j, t in ipairs(card.pill[i] or {}) do
				local c = t._color
				if not t:IsShown() then
					fail(scenario, ("layer %d slice %d is hidden on a greyed-out card"):format(i, j))
				elseif not (c and near(c[1], c[2], 1e-6) and near(c[2], c[3], 1e-6)) then
					fail(scenario, ("layer %d slice %d keeps its colour (%s) on a greyed-out card"):format(i, j, colourText(c)))
				elseif not near(c[4] or 1, layer.color[4] or 1, 1e-6) then
					fail(scenario, ("layer %d slice %d changed its opacity when greyed"):format(i, j))
				end
				if t:GetAlpha() >= 1 then fail(scenario, ("layer %d slice %d is not dimmed with its card"):format(i, j)) end
			end
		end
		def.disabled = was
		ns.RefreshOptionsDisplay()
		card = cardFor(row, "luxe")
		for i, layer in ipairs(pill.layers) do
			for j, t in ipairs(card and card.pill[i] or {}) do
				if not sameColour(t._color, layer.color) then
					fail(scenario, ("layer %d slice %d did not get its colour back"):format(i, j))
				end
				if t:GetAlpha() < 1 then fail(scenario, ("layer %d slice %d stayed dim"):format(i, j)) end
			end
		end
	end)
end

-- ------------------------------------------------------------------ the data
do
	local scenario = "hunt41-cards: the tag is recorded completely"
	session(scenario, {}, function(ns)
		local spec = ns.Looks.previewText.luxe and ns.Looks.previewText.luxe.reason
		local pill = spec and spec.pill
		if not pill then
			fail(scenario, "Luxe records no tag: run tools/make_look_previews.py")
			return
		end
		local function number(v) return type(v) == "number" and v == v end
		if not (number(pill.t) and number(pill.b) and 0 <= pill.t and pill.t < pill.b and pill.b <= 1) then
			fail(scenario, "the tag's edges are not inside the picture")
		end
		if not (number(pill.lead) and number(pill.tail) and pill.lead >= 0 and pill.tail >= 0
			and pill.lead < 0.5 and pill.tail < 0.5) then
			fail(scenario, "the tag's lead and tail are not sensible")
		end
		if pill.cap ~= nil and not (number(pill.cap) and pill.cap > 0 and pill.cap <= 1) then
			fail(scenario, "the tag's caps are not a share of its height")
		end
		if number(pill.t) and number(spec.t) and (pill.t > spec.t or pill.b < spec.b) then
			fail(scenario, "the tag does not reach round the words' rectangle")
		end
		if type(pill.layers) ~= "table" or #pill.layers < 1 then
			fail(scenario, "the tag has no layers")
		else
			for i, layer in ipairs(pill.layers) do
				local file = shippedFile(layer.file)
				local f = file and io.open(file, "rb")
				if not f then
					fail(scenario, ("layer %d's file %s is not one the addon ships"):format(i, tostring(layer.file)))
				else
					f:close()
				end
				local c = layer.color
				if not (type(c) == "table" and #c == 4) then
					fail(scenario, ("layer %d has no colour"):format(i))
				else
					for k = 1, 4 do
						if not (number(c[k]) and c[k] >= 0 and c[k] <= 1) then fail(scenario, ("layer %d's colour is not numbers"):format(i)) end
					end
				end
			end
		end
	end)
end
