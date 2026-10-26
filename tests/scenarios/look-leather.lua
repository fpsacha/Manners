-- The Leather look (Looks/Leather.lua): what it promises beyond what every
-- look does, which tests/scenarios/looks.lua asks of it as well.
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows the
-- wrong thing. What it holds:
--   * it is registered, in the toc after the other looks, in all eight
--     languages, and the look it replaced is gone (a saved style of "slate"
--     becomes the default);
--   * it draws only art of its own, every file of it ships and every file is
--     drawn in some state;
--   * every state paints without an error on all five clients;
--   * the tag is fitted into the prompt at every size and in two languages:
--     the leather covers the whole of it, opaque; the thread, the eyelet and
--     the icon's setting lie inside it; the text never stands over the icon's
--     setting, the eyelet or a chip; a long name and a long German reason are
--     shrunk or cut, never run over them;
--   * the reason is carried by the icon's thread, the tag's thread and the
--     enamel in the eyelet, in both palettes, and the marker off leaves cream
--     and a dark hole; the text reads on the leather;
--   * the name is in the display serif where the client writes in the Latin
--     alphabet, the player's own font wins, the others keep the client's;
--   * the list hangs from the same ring, its names secure buttons on frames;
--   * the motion is the look's own and keeps to its time and its room: a
--     favour swings the tag in with the eyelet held still, owed glows three
--     times and rests, a landing lights the thread piece by piece, a refusal
--     jerks it and flashes red and amber, a cast nobody confirmed does nothing;
--     Calm is fades only; a fight greys the leather and keeps the reason;
--     leaving the look puts everything it borrowed back;
--   * the generator draws the bytes that ship.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local LONG = { nameplate1 = { "Bartholomewzxyzq", "Longsurnamefortesting" },
	nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Leather\\"
local COMMAND = "CLICK MannersPrompt:LeftButton"
local CLIENTS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local REASONS = { "target", "owed", "asked", "group", "nearby", "self" }
local LOCALES = { "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }
local NAME_KEY = "Leather -- a stitched leather tag with a brass ring"
-- Every texture the look ships, as the generator writes them.
local FILES = { "Leather_BodyL", "Leather_BodyM", "Leather_BodyR", "Leather_StitchL", "Leather_StitchM",
	"Leather_StitchR", "Leather_IconRim", "Leather_IconRimRd", "Leather_IconMask", "Leather_IconMaskRd",
	"Leather_Eyelet", "Leather_Enamel", "Leather_Glow", "Leather_Star", "Leather_Sheen", "Leather_Band",
	"Leather_FxRing", "Leather_FxRingSq" }

local function withTree(scenario, names, body, before)
	Mock.reset()
	if before then before() end
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.005)
end

local function sameColour(c, r, g, b, eps)
	return c ~= nil and near(c[1], r, eps) and near(c[2], g, eps) and near(c[3], b, eps)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in Leather with Anna owed on top (or `who`). Returns the
-- regions, the settings and the look.
local function upIn(ns, scenario, edit, who)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "leather"
	p.flashStyle = "pulse"
	p.effects = "full"
	p.hideInCombat = false
	p.showIcon = true
	p.roundIcon = false
	p.showSub = true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, who or "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isLeather(look)
	return look ~= nil and look.key == "leather" and look.body ~= nil and look.eyelet ~= nil and look.thread ~= nil
end

local function plays(g) return g and g._plays or 0 end
local function total(list)
	local n = 0
	for _, g in ipairs(list) do n = n + plays(g) end
	return n
end

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function looping()
	local _, loops = FT.playing()
	return #loops
end

local function rectOf(r)
	local L, R = FT.span(r, "x")
	local B, T = FT.span(r, "y")
	if L and B then return { L, B, R, T } end
end

local function inside(a, b, margin)
	margin = margin or 0
	return a[1] >= b[1] + margin - 0.01 and a[3] <= b[3] - margin + 0.01
		and a[2] >= b[2] + margin - 0.01 and a[4] <= b[4] - margin + 0.01
end

local function across(a, b)
	return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01
end

local function lin(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function lum(c) return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3]) end

local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- Whether `c` is `base` taken towards white by one amount, which is how the
-- look lightens the reason's colour for the leather: the same hue, lighter.
local function lightened(c, base)
	if not c then return false end
	local t
	for i = 1, 3 do
		if base[i] < 0.999 then
			local ti = (c[i] - base[i]) / (1 - base[i])
			if t and math.abs(ti - t) > 0.03 then return false end
			t = ti
		end
	end
	return t == nil or t > -0.03, t or 0
end

local function distance(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- ------------------------------------------------------------------ 1
-- Registered, listed, in the toc, in all eight languages; the look it replaced
-- is gone and a saved style of it falls back.
withTree("look-leather: it is registered, listed and loaded after the other looks", ANNA, function(ns, scenario)
	local look = ns.Looks.list.leather
	if not look then fail(scenario, "no look is registered as leather") return end
	if look.key ~= "leather" then fail(scenario, "its key is " .. tostring(look.key)) end
	if ns.Looks.Get("leather") ~= look then fail(scenario, "Looks.Get does not hand back the look") end
	if look.native or look.fallback then fail(scenario, "the look is native or a fallback") end
	if not ns.Looks.Allowed().leather then fail(scenario, "a saved style of leather is not allowed") end
	local values, sorting = ns.Looks.Choices()
	if values.leather ~= ns.L[NAME_KEY] then fail(scenario, "the dropdown's label is " .. tostring(values.leather)) end
	local at
	for i, key in ipairs(sorting) do if key == "leather" then at = i end end
	if not at then fail(scenario, "the dropdown does not list it") end
	if look.order ~= 6 then fail(scenario, "its place in the dropdown is " .. tostring(look.order) .. ", not 6") end
	local title, line = ns.Looks.Card("leather")
	if title ~= "Leather" or line ~= "a stitched leather tag with a brass ring" then
		fail(scenario, "the picker's card says " .. tostring(title) .. " / " .. tostring(line))
	end
	-- The toc: after the last look, before the prompt that calls into it.
	local toc = slurp(dir .. "/Manners.toc") or ""
	local lines = {}
	for line in toc:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
	local function index(name)
		for i, l in ipairs(lines) do if l == name then return i end end
	end
	local mine = index("Looks\\Leather.lua")
	if not mine then
		fail(scenario, "Manners.toc does not load Looks\\Leather.lua")
	else
		for _, other in ipairs({ "Looks\\Looks.lua", "Looks\\Luxe.lua", "Looks\\Toast.lua", "Looks\\Arcane.lua" }) do
			local i = index(other)
			if i and i > mine then fail(scenario, "Leather loads before " .. other) end
		end
		if mine > (index("Prompt\\Prompt.lua") or 0) then fail(scenario, "Leather loads after Prompt") end
	end
	for _, flavour in ipairs({ "Camelot", "Vanilla", "TBC", "Mists", "Mainline" }) do
		local generated = slurp(dir .. "/Manners_" .. flavour .. ".toc") or ""
		if not generated:find("Looks\\Leather.lua", 1, true) then
			fail(scenario, "Manners_" .. flavour .. ".toc does not load the look")
		end
	end
end)

withTree("look-leather: the look it replaced is gone and a saved style of it falls back", ANNA, function(ns, scenario)
	if ns.Looks.list.slate then fail(scenario, "a look is still registered as slate") end
	if ns.Looks.Get("slate") then fail(scenario, "Looks.Get still hands back a look for slate") end
	for _, path in ipairs({ "Looks/Slate.lua", "tools/make_slate_textures.py", "Textures/Previews/Preview_slate.tga",
		"tests/scenarios/look-slate.lua", "tests/mutations/look-slate.py" }) do
		local f = io.open(dir .. "/" .. path, "rb")
		if f then f:close() fail(scenario, path .. " is still in the package") end
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	if toc:find("Slate", 1, true) then fail(scenario, "Manners.toc still names Slate") end
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "slate"
	ns.ClampSettings()
	if p.style ~= ns.defaults.profile.prompt.style then
		fail(scenario, "a saved style of slate is " .. tostring(p.style) .. " after the clamp, not the default")
	end
	p.style = "leather"
	ns.ClampSettings()
	if p.style ~= "leather" then fail(scenario, "a saved style of leather is not kept: " .. tostring(p.style)) end
end)

withTree("look-leather: its name is translated into all eight languages", ANNA, function(_, scenario)
	local keys = { 'L["Leather -- a stitched leather tag with a brass ring"] = "', 'L["Leather"] = "',
		'L["a stitched leather tag with a brass ring"] = "' }
	for _, code in ipairs(LOCALES) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs(keys) do
			local at = text:find(key, 1, true)
			if not at then
				fail(scenario, code .. " has no translation of " .. key:sub(4, 30))
			else
				local value = text:match('^[^\r\n]-"([^\r\n]*)"', at + #key - 1)
				if not value or value == "" or value:find("Leather", 1, true) or value:find("leather", 1, true) then
					fail(scenario, code .. "'s translation of " .. key:sub(4, 30) .. " is empty or still English: " .. tostring(value))
				end
			end
		end
	end
	local source = slurp(dir .. "/Looks/Leather.lua") or ""
	-- Every string the player reads goes through L with a literal key.
	if source:find("[^%w_]L%[[^\"]") then fail(scenario, "Looks/Leather.lua reads L with a key that is not a literal") end
end)

withTree("look-leather: a German client's card and label read in German", ANNA, function(ns, scenario)
	local title, line = ns.Looks.Card("leather")
	if title ~= "Leder" then fail(scenario, "the German card's title is " .. tostring(title)) end
	if not line or line == "" or line:find("leather", 1, true) then fail(scenario, "the German card's line is " .. tostring(line)) end
	local values = ns.Looks.Choices()
	if not values.leather or values.leather:find("Leather", 1, true) then
		fail(scenario, "the German label is " .. tostring(values.leather))
	end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 2
-- Only art of its own and all of it ships; every file is drawn in some state.
local function fileName(x)
	return tostring(x._file):sub(#ART + 1)
end

withTree("look-leather: it draws only art of its own, all of it ships and every file is drawn", CROWD, function(ns, scenario)
	local drawn, count = {}, 0
	local function one(x)
		if type(x) ~= "table" or type(x._file) ~= "string" then return end
		count = count + 1
		if x._file:sub(1, #ART) ~= ART then
			fail(scenario, "the look draws " .. x._file .. ", which is not its own art")
		else
			local name = fileName(x)
			drawn[name] = true
			local f = io.open(dir .. "/Textures/Leather/" .. name .. ".tga", "rb")
			if f then f:close() else fail(scenario, x._file .. " is not in the package") end
		end
	end
	for _, edit in ipairs({
		function(p) p.showQueue, p.queueRows = true, 3 end,
		function(p) p.showIcon = false end,
		function(p) p.roundIcon = true end,
	}) do
		local r, p, look = upIn(ns, scenario, edit)
		if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			Mock.advance(3)
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			for _, x in ipairs(look.own) do one(x) end
			for _, ring in ipairs(look.fx.rings) do one(ring.tex) end
			one(look.mask)
		end
		one(r.cooldown and { _file = r.cooldown._swipeTexture })
		Mock.advance(3)
		tick(ns)
		p.showQueue = false
	end
	if count < 60 then fail(scenario, "only " .. count .. " textures were read, so nothing was held") end
	-- The two files only a round icon uses were drawn too, and the swipe is the look's own.
	for _, name in ipairs(FILES) do
		if not drawn[name] then fail(scenario, name .. " ships and is drawn by no state") end
	end
	local source = slurp(dir .. "/Looks/Leather.lua") or ""
	for _, name in ipairs(FILES) do
		if not source:find('"' .. name:gsub("^Leather_", "") .. '"', 1, true) then
			fail(scenario, "Looks/Leather.lua never names " .. name)
		end
	end
	-- And the code names no texture of the client's anywhere.
	for path in source:gmatch('"(Interface[^"]*)"') do
		if path ~= "Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Leather\\\\Leather_" then
			fail(scenario, "Looks/Leather.lua names " .. path .. ", a path that is not its own art")
		end
	end
	local r, _, look = upIn(ns, scenario)
	if r.cooldown and r.cooldown._swipeTexture and tostring(r.cooldown._swipeTexture):sub(1, #ART) ~= ART then
		fail(scenario, "the cooldown's swipe is " .. tostring(r.cooldown._swipeTexture) .. ", not the icon's own shape")
	end
	if look.mask._file ~= ART .. "Leather_IconMask" then fail(scenario, "the icon's mask is " .. tostring(look.mask._file)) end
end)

-- ------------------------------------------------------------------ 3
-- Every state, on every client, without an error.
local function everyState(ns, p)
	local P = ns.Prompt
	local steps = {
		{ "owed", function() owe(ns, "Anna Aim") ns.addon:Tick() end },
		{ "success", function() P:ShowOutcome("cast", "Anna Aim") end },
		{ "refused", function() Mock.advance(1) P:ShowOutcome("failed", "Anna Aim", "Out of range.") end },
		{ "sent", function() Mock.advance(1) P:ShowOutcome("sent", "Anna Aim") end },
		{ "expiry", function() Mock.advance(2) ns.addon:Tick() end },
		{ "hover", function()
			local b = P:GetButton()
			b.scripts.OnEnter(b)
			b.scripts.OnLeave(b)
		end },
		{ "gcd", function()
			Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
			P:SyncCooldown()
		end },
		{ "combat", function()
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()
			ns.addon:Tick()
			P:ShowOutcome("failed", "Anna Aim", "Out of range.")
		end },
		{ "after combat", function()
			Mock.inCombat = false
			if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
			Mock.advance(2)
			ns.addon:Tick()
		end },
		{ "list below", function()
			p.showQueue, p.queueRows = true, 3
			Mock.promptCentreY = 700
			P:ApplyStyle()
			ns.addon:Tick()
		end },
		{ "list above", function()
			Mock.promptCentreY = 40
			P:ApplyStyle()
			ns.addon:Tick()
		end },
		{ "unlocked", function()
			p.locked = false
			P:ApplyStyle()
			p.locked = true
			P:ApplyStyle()
		end },
		{ "preview", function()
			Mock.optionsOpen = true
			P:ToggleTest()
			P:Refresh()
			P:ToggleTest()
			Mock.optionsOpen = nil
		end },
	}
	for _, step in ipairs(steps) do
		local ok, err = pcall(step[2])
		FT.settle()
		if not ok then return step[1] .. " threw: " .. tostring(err) end
	end
end

for _, client in ipairs(CLIENTS) do
	local scenario = "look-leather: every state paints without an error on " .. client
	withTree(scenario, CROWD, function(ns)
		local _, p = upIn(ns, scenario)
		local from = #(ns.errors or {})
		local threw = everyState(ns, p)
		if threw then fail(scenario, threw) end
		for _, edit in ipairs({
			{ "second line off", function() p.showSub = false end },
			{ "icon hidden", function() p.showIcon = false end },
			{ "round icon", function() p.showIcon, p.showSub, p.roundIcon = true, true, true end },
			{ "colour-blind set", function() p.roundIcon, p.reasonPalette = false, "colourblind" end },
			{ "marker off", function() p.accentMode = "off" end },
			{ "stripe only", function() p.accentMode = "stripe" end },
			{ "both", function() p.accentMode = "both" end },
			{ "light panel", function() p.accentMode, p.bgColor = "icon", { 0.86, 0.84, 0.78, 0.92 } end },
			{ "a dark text colour", function() p.fontColor = { 0.1, 0.1, 0.12, 1 } end },
			{ "calm", function() p.effects, p.bgColor, p.fontColor = "calm", { 0.04, 0.04, 0.06, 0.88 }, { 1, 1, 1, 1 } end },
		}) do
			local ok, err = pcall(function()
				edit[2]()
				ns.Prompt:ApplyStyle()
				ns.addon:Tick()
			end)
			if not ok then fail(scenario, edit[1] .. " threw: " .. tostring(err)) end
			threw = everyState(ns, p)
			if threw then fail(scenario, edit[1] .. ": " .. threw) end
		end
		for i = from + 1, #(ns.errors or {}) do
			local e = ns.errors[i]
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end, function() Mock.setFlavour(client) end)
end

-- ------------------------------------------------------------------ 4
-- The layout, at every size: the leather covers the prompt and is opaque, the
-- thread, the eyelet and the icon's setting lie inside it, and the lines stand
-- clear of the icon's setting and of the eyelet.

-- Every texture the look keeps on the prompt itself, which must lie inside
-- it: not the list's tags (outside by design), the rings' frames (scaled to fit
-- when they play) or the textures a swing moves.
local function mainTextures(look)
	local out, skip = {}, {}
	for _, tag in ipairs(look.tags) do
		for _, t in ipairs(tag.body) do skip[t] = true end
		skip[tag.eyelet], skip[tag.dot] = true, true
	end
	for _, set in ipairs({ look.chip, look.keyChip }) do
		for _, t in ipairs(set) do skip[t] = true end
	end
	for _, ring in ipairs(look.fx.rings) do skip[ring.tex] = true end
	for i, x in ipairs(look.own) do
		if x._kind == "Texture" and not skip[x] and FT.visible(x) then out[#out + 1] = { i, x } end
	end
	return out
end

for _, locale in ipairs({ "enUS", "deDE" }) do
	local scenario = "look-leather: nothing overlaps or leaves the prompt, at every size, " .. locale
	withTree(scenario, LONG, function(ns)
		for _, width in ipairs({ 160, 220, 400 }) do
			for _, height in ipairs({ 32, 44, 72 }) do
				for _, icon in ipairs({ true, false }) do
					for _, font in ipairs({ 11, 17 }) do
						local tag = ("%dx%d, %d pt, icon %s"):format(width, height, font, tostring(icon))
						local r, p, look = upIn(ns, scenario, function(pp)
							pp.width, pp.height, pp.fontSize, pp.showIcon = width, height, font, icon
							pp.iconSize = 30
						end)
						if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
						if locale == "deDE" then p.reasonOwed = "hat dich gerade gebufft und wartet auf deine Antwort" end
						ns.Prompt:ApplyStyle()
						tick(ns)
						local panel = rectOf(r.art)
						for _, item in ipairs(mainTextures(look)) do
							local box = rectOf(item[2])
							if box and not inside(box, panel) then
								fail(scenario, ("%s: a part of the tag (%d, %s) is outside the prompt"):format(
									tag, item[1], tostring(item[2]._file):gsub("^.*Leather_", "")))
							end
						end
						-- The leather is the whole prompt: its three slices meet and cover it.
						local a, b, c = rectOf(look.body[1]), rectOf(look.body[2]), rectOf(look.body[3])
						if not (a and b and c and near(a[1], panel[1], 0.02) and near(c[3], panel[3], 0.02)
							and near(a[3], b[1], 0.02) and near(b[3], c[1], 0.02)
							and near(a[2], panel[2], 0.02) and near(a[4], panel[4], 0.02)
							and near(b[2], panel[2], 0.02) and near(c[4], panel[4], 0.02)) then
							fail(scenario, tag .. ": the leather's three pieces do not meet and cover the prompt")
						end
						-- Its right end is the half circle of the prompt's height.
						if c and not near(c[3] - c[1], height / 2, 0.02) and width >= height * 1.5 then
							fail(scenario, ("%s: the right end is %.1f wide, not half the height"):format(tag, c[3] - c[1]))
						end
						-- The thread runs along the top and bottom, inside the leather.
						local top, bottom = rectOf(look.thread.top), rectOf(look.thread.bottom)
						if not (top and bottom and top[2] > bottom[4] and inside(top, panel) and inside(bottom, panel)) then
							fail(scenario, tag .. ": the thread is not a line along the top and a line along the bottom")
						end
						-- The eyelet: round, in the right end, in the middle of the height.
						local eye = rectOf(look.eyelet)
						if eye then
							if not near(eye[3] - eye[1], eye[4] - eye[2], 0.02) then fail(scenario, tag .. ": the eyelet is not round") end
							if not near((eye[2] + eye[4]) / 2, (panel[2] + panel[4]) / 2, 0.05) then
								fail(scenario, tag .. ": the eyelet is not in the middle of the height")
							end
							if panel[3] - eye[1] > 0.65 * height + 0.01 then fail(scenario, tag .. ": the eyelet is not in the right end") end
						end
						local name, sub = rectOf(r.name), r.sub:IsShown() and rectOf(r.sub) or nil
						if not name then fail(scenario, tag .. ": the name has no place") return end
						-- Never over the eyelet, the icon's setting or the left end.
						if eye then
							if name[3] > eye[1] + 0.01 then fail(scenario, tag .. ": the name runs over the eyelet") end
							if sub and sub[3] > eye[1] + 0.01 then fail(scenario, tag .. ": the reason runs over the eyelet") end
						end
						if icon then
							local box = rectOf(r.icon)
							local rim = rectOf(look.iconRim)
							if not (box and rim and near(box[1], rim[1], 0.02) and near(box[3], rim[3], 0.02)
								and near(box[2], rim[2], 0.02) and near(box[4], rim[4], 0.02)) then
								fail(scenario, tag .. ": the icon's setting is not the icon's box")
							end
							if box and not inside(box, panel, 1) then fail(scenario, tag .. ": the icon leaves the leather") end
							if box and math.abs((box[3] - box[1]) - (box[4] - box[2])) > 0.01 then
								fail(scenario, tag .. ": the icon is not square")
							end
							if box and top and (box[4] > top[2] or box[2] < bottom[4]) then
								-- (the icon is inside the two lines of thread)
								fail(scenario, tag .. ": the icon is over the thread")
							end
							if box and name[1] < box[3] + 0.99 then fail(scenario, tag .. ": the name starts over the icon's setting") end
							if box and sub and sub[1] < box[3] + 0.99 then fail(scenario, tag .. ": the reason starts over the icon's setting") end
						else
							if r.icon:IsShown() then fail(scenario, tag .. ": the icon is shown with the icon off") end
							if look.iconRim._shown ~= false and FT.visible(look.iconRim) then
								fail(scenario, tag .. ": the icon's setting is drawn with the icon off")
							end
							if name[1] < panel[1] + 2 then fail(scenario, tag .. ": the name starts at the leather's edge") end
						end
						if sub then
							local nm, sm = (name[2] + name[4]) / 2, (sub[2] + sub[4]) / 2
							if nm - sm < font * 0.8 then fail(scenario, tag .. ": the two lines meet") end
							-- Both between the two lines of thread.
							if top and (name[4] > top[2] + 0.01 or sub[2] < bottom[4] - 0.01) then
								fail(scenario, tag .. ": a line is over the thread")
							end
						end
						-- A line fitted into its room: never cut where it could shrink, never
						-- less than four fifths of its size.
						for _, fs in ipairs({ r.name, r.sub }) do
							if fs:IsShown() and fs._font and fs._font.size and fs._text and fs._text ~= "" then
								local base = font + (fs == r.name and ((fs._font.path or ""):find("MORPHEUS") and 1 or 0) or -3)
								if fs ~= r.name then base = math.max(7, font - 3) end
								if fs._font.size < math.max(7, math.floor(base * 0.8 + 0.5)) - 0.01 then
									fail(scenario, ("%s: a line is %d pt, under four fifths of %d"):format(tag, fs._font.size, base))
								end
							end
						end
					end
				end
			end
		end
	end)
end

-- With a key bound and a count the patches sit left of the eyelet, on the
-- reason's line side by side, the name keeps its whole room, the reason keeps
-- clear of them, and nothing is over the eyelet.
withTree("look-leather: the bound key and the count sit left of the eyelet and the name keeps its room", CROWD, function(ns, scenario)
	for _, icon in ipairs({ true, false }) do
		for _, case in ipairs({ { 220, 44, 13 }, { 300, 56, 17 } }) do
			local r, p, look = upIn(ns, scenario, function(pp)
				pp.width, pp.height, pp.fontSize, pp.showIcon = case[1], case[2], case[3], icon
			end)
			SetBinding("SHIFT-F", COMMAND)
			tick(ns)
			if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
			local panel, eye = rectOf(r.art), rectOf(look.eyelet)
			if not look.keyUp then fail(scenario, "a bound key shows no patch") return end
			local key, name, sub = rectOf(look.keyBox), rectOf(r.name), rectOf(r.sub)
			if not (key and eye and panel and inside(key, panel)) then fail(scenario, "the key's patch leaves the prompt") end
			if key and eye and key[3] > eye[1] + 0.01 then fail(scenario, "the key's patch is over the eyelet") end
			if look.keyLane ~= "sub" then fail(scenario, "the key's patch is not on the reason's line: " .. tostring(look.keyLane)) end
			if name and key and across(name, key) then fail(scenario, "the name runs under the key's patch") end
			if sub and key and (sub[3] > key[1] + 0.01 or math.abs((sub[2] + sub[4]) / 2 - (key[2] + key[4]) / 2) > 3) then
				fail(scenario, "the reason is not beside the key's patch on its own line")
			end
			-- The name's room is the whole line's, up to the eyelet.
			if name and eye and look.inset > look.baseInset + 0.01 then fail(scenario, "the name gives room to a patch that is not on its line") end
			local keyText = rectOf(look.keyText)
			if keyText and key and not inside(keyText, key) then fail(scenario, "the key's text leaves its patch") end
			local count = rectOf(look.chipBox)
			if look.countMode ~= "sub" then fail(scenario, "with a key bound and others waiting the count is " .. tostring(look.countMode)) end
			if count and key and (across(count, key) or count[3] > key[1] + 0.01) then fail(scenario, "the count's patch is over the key's, or right of it") end
			if count and eye and count[3] > eye[1] + 0.01 then fail(scenario, "the count's patch is over the eyelet") end
			if count and name and across(name, count) then fail(scenario, "the name runs under the count's patch") end
			if count and sub and sub[3] > count[1] + 0.01 then fail(scenario, "the reason runs under the count's patch") end
			if count and not inside(count, panel) then fail(scenario, "the count's patch leaves the prompt") end
			-- The key alone: the reason still keeps clear of its patch.
			p.showCount = false
			ns.Prompt:ApplyStyle()
			tick(ns)
			key, sub = rectOf(look.keyBox), rectOf(r.sub)
			if look.countMode then fail(scenario, "a count's patch with the count off") end
			if not look.keyUp then fail(scenario, "the key's patch gone with the count off") end
			if sub and key and sub[3] > key[1] + 0.01 then fail(scenario, "with no count the reason runs under the key's patch") end
			p.showCount = true
			ns.Prompt:ApplyStyle()
			tick(ns)
			SetBinding("SHIFT-F")
			tick(ns)
			if look.keyUp then fail(scenario, "the key's patch stays after the binding goes") end
			if look.countMode ~= "sub" then fail(scenario, "without a key the count is " .. tostring(look.countMode)) end
			count = rectOf(look.chipBox)
			if count and eye and count[3] > eye[1] + 0.01 then fail(scenario, "the lone count's patch is over the eyelet") end
			-- A count of three digits is a wider patch, and the reason gives it room.
			r.count:SetText("12345")
			ns.Prompt.lib.ShowChip(true)
			FT.settle()
			local wide, words, line, why = rectOf(look.chipBox), rectOf(r.count), rectOf(r.name), rectOf(r.sub)
			if not look.countMode then fail(scenario, "a count of three digits shows no patch") end
			if wide and words and not inside(words, wide) then fail(scenario, "the count's text leaves its patch") end
			if wide and line and across(line, wide) then fail(scenario, "the name runs under a count of three digits") end
			if wide and why and why[3] > wide[1] + 0.01 then fail(scenario, "the reason runs under a count of three digits") end
			if wide and eye and wide[3] > eye[1] + 0.01 then fail(scenario, "a count of three digits is over the eyelet") end
		end
	end
end)

-- Where the reason has no room for the patches, they step to the name line's end,
-- or aside, and nothing of either line is ever under a patch.
withTree("look-leather: where the reason has no room the patches stand at the name line's end or aside", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.width = 220
		pp.reasonOwed = "hat dich gerade gebufft und wartet auf deine Antwort"
	end)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	SetBinding("SHIFT-F", COMMAND)
	tick(ns)
	local name, sub = rectOf(r.name), rectOf(r.sub)
	local patches = { { "key", look.keyUp, look.keyBox }, { "count", look.countMode, look.chipBox } }
	for _, item in ipairs(patches) do
		local what, up, box = item[1], item[2], rectOf(item[3])
		if up and box then
			if name and across(name, box) then fail(scenario, "the name is under the " .. what .. "'s patch") end
			if sub and across(sub, box) then fail(scenario, "the reason is under the " .. what .. "'s patch") end
		end
	end
	if look.countMode == "chip" or look.countMode == "pair" then
		local count = rectOf(look.chipBox)
		if count and name and math.abs((count[2] + count[4]) / 2 - (name[2] + name[4]) / 2) > 4 then
			fail(scenario, "the count's patch is not on the name line")
		end
	end
end)

-- An ordinary name is whole at the default size with the count and the key up:
-- "Elowen Thistledown" (18 letters) in English and a German two-part name of the
-- same length, on a 220 x 44 prompt at 13 pt with a 30 icon, +2 behind them and
-- F bound. The patches stand on the reason's line, so the name has the line's
-- room; measured the way a display serif is (0.58 of the size a letter, the
-- width the stand-in for Morpheus draws), which the mock's half a size a letter
-- flatters.
for _, case in ipairs({ { "enUS", { "Elowen", "Thistledown" } }, { "deDE", { "Friedrich", "Eichwald" } } }) do
	local locale, who = case[1], case[2]
	local full = who[1] .. " " .. who[2]
	local scenario = ("look-leather: %s with a count and a key is not cut at the default size, %s"):format(full, locale)
	local names = { nameplate1 = who, nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" } }
	withTree(scenario, names, function(ns)
		local realMeasure = FT.measure
		FT.measure = function(text, size)
			local letters = select(2, text:gsub("[^\128-\191]", ""))
			return letters * size * 0.58
		end
		local ok, err = pcall(function()
			local r, p, look = upIn(ns, scenario, function(pp)
				pp.width, pp.height, pp.fontSize, pp.iconSize = 220, 44, 13, 30
				pp.showCount = true
			end, full)
			if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
			SetBinding("F", COMMAND)
			tick(ns)
			if not tostring(r.name:GetText()):find(who[1], 1, true) then
				fail(scenario, "the name on the prompt is not " .. full .. ": " .. tostring(r.name:GetText()))
				return
			end
			if not look.countMode then fail(scenario, "the count has no patch: it stepped aside for the name") end
			if not look.keyUp then fail(scenario, "the key has no patch: it stepped aside for the name") end
			local room = rectOf(r.name)
			local width = r.name:GetUnboundedStringWidth()
			local size = select(2, r.name:GetFont())
			local base = look.kit.fit.base[r.name]
			if room and type(width) == "number" and width > room[3] - room[1] + 0.6 then
				fail(scenario, ("the name is %.1f wide in a room of %.1f: it is cut"):format(width, room[3] - room[1]))
			end
			if type(size) == "number" and type(base) == "number" and size < base * 0.9 then
				fail(scenario, ("the name is drawn at %s, shrunk from %s for the patches"):format(tostring(size), tostring(base)))
			end
			if tostring(r.name:GetText()):find("%.%.%.") then fail(scenario, "the name is cut with an ellipsis") end
			local rs = rectOf(r.sub)
			local sw = r.sub:GetUnboundedStringWidth()
			if rs and type(sw) == "number" and sw > rs[3] - rs[1] + 0.6 then
				fail(scenario, ("the reason is %.1f wide in a room of %.1f: it is cut"):format(sw, rs[3] - rs[1]))
			end
		end)
		FT.measure = realMeasure
		if not ok then error(err, 0) end
	end, locale ~= "enUS" and function() Mock.locale = locale end or nil)
end

-- ------------------------------------------------------------------ 5
-- The leather is opaque at rest: the world never shows through it, whatever
-- the panel's opacity says, and the prompt rests at full alpha.
withTree("look-leather: the leather is opaque at rest, whatever the panel's opacity says", ANNA, function(ns, scenario)
	for _, opacity in ipairs({ 0.88, 0.2, 0 }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.bgColor = { 0.04, 0.04, 0.06, opacity } end)
		if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
		Mock.advance(3)
		wipe(ns.owed)
		tick(ns)
		owe(ns, "Anna Aim")
		tick(ns)
		Mock.advance(8)
		FT.settle()
		if (r.art._alpha or 1) < 0.999 then fail(scenario, "the prompt rests at alpha " .. tostring(r.art._alpha)) end
		for i, t in ipairs(look.body) do
			local a = 1
			local node = t
			while node do
				a = a * (node._alpha == nil and 1 or node._alpha)
				node = node._parent
			end
			if a < 0.999 then fail(scenario, ("leather piece %d is at alpha %.2f"):format(i, a)) end
			if t._blend and t._blend ~= "BLEND" then fail(scenario, "leather piece " .. i .. " is drawn " .. t._blend) end
			if t._desaturated then fail(scenario, "leather piece " .. i .. " is grey at rest") end
			local g = t._gradient
			if g then
				for k = 2, 3 do
					local c = g[k]
					local alpha = c.a or c[4]
					if alpha ~= nil and alpha < 0.999 then fail(scenario, ("leather piece %d has an end at alpha %.2f"):format(i, alpha)) end
				end
			elseif t._color and (t._color[4] or 1) < 0.999 then
				fail(scenario, "leather piece " .. i .. " is see-through")
			end
		end
		-- The art carries the brown; the untouched leather's colour is the art's own,
		-- a shade darker towards the right end and never darker than three quarters.
		local g = look.body[2]._gradient
		if g and opacity == 0.88 then
			local left, right = g[2], g[3]
			local lr, rr = left.r or left[1], right.r or right[1]
			if not (near(lr, left.g or left[2], 0.001) and near(lr, left.b or left[3], 0.001)) then
				fail(scenario, "the untouched leather is tinted: it should be the art's own brown")
			end
			if not (lr > rr and rr > 0.75) then
				fail(scenario, ("the leather's ends are %.2f and %.2f, not a shade darker to the right"):format(lr, rr))
			end
		end
	end
	-- The art's own pixels are opaque where the leather is: the middle piece has
	-- no transparent texel.
	local f = io.open(dir .. "/Textures/Leather/Leather_BodyM.tga", "rb")
	local data = f and f:read("*a")
	if f then f:close() end
	if data then
		local w, h = data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
		local least = 255
		for y = 0, h - 1 do
			for x = 1, w - 1, 7 do
				local a = data:byte(18 + (y * w + x) * 4 + 4)
				if y > 1 and y < h - 2 and a < least then least = a end
			end
		end
		if least < 250 then fail(scenario, "the leather's middle has a texel of alpha " .. least) end
	end
end)

-- ------------------------------------------------------------------ 6
-- The reason: the icon's thread, the tag's thread and the enamel in the eyelet,
-- in both palettes; neutral with the marker off.
withTree("look-leather: the reason is carried by the thread and the enamel, in both palettes", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local CREAM = { 0.93, 0.76, 0.54 }
	local function paint(mode, palette, reason)
		p.accentMode, p.reasonPalette = mode, palette
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent(reason)
		FT.settle()
	end
	local function threadOf() return look.thread.top._color end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		local carried = { thread = {}, rim = {}, enamel = {} }
		for _, reason in ipairs(REASONS) do
			local cr, cg, cb
			paint("both", palette, reason)
			cr, cg, cb = ns.Prompt:AccentColor(reason)
			local base = { cr, cg, cb }
			local thread, rim, enamel = threadOf(), look.iconRim._color, look.enamel._color
			for name, c in pairs({ thread = thread, rim = rim, enamel = enamel }) do
				if not c then fail(scenario, ("the %s has no colour for %s (%s)"):format(name, reason, palette)) end
				if c and not lightened(c, base) then
					fail(scenario, ("the %s is not %s's colour, only lightened, in the %s set"):format(name, reason, palette))
				end
			end
			-- The thread and the enamel are held to a luminance the leather can show.
			if thread and lum(thread) < 0.30 then fail(scenario, ("the thread for %s (%s) is too dark for the leather"):format(reason, palette)) end
			if enamel and lum(enamel) < 0.18 then fail(scenario, ("the enamel for %s (%s) is too dark for the hole"):format(reason, palette)) end
			carried.thread[reason], carried.rim[reason], carried.enamel[reason] = thread, rim, enamel
		end
		-- Every reason a carrier of its own: the five (self wears the group's).
		for _, carrier in ipairs({ "thread", "rim", "enamel" }) do
			for i = 1, #REASONS do
				for j = i + 1, #REASONS do
					local a, b = REASONS[i], REASONS[j]
					local ca, cb = carried[carrier][a], carried[carrier][b]
					if ca and cb then
						local same = a == "self" or b == "self"
						local d = distance(ca, cb)
						if same and (a == "group" or b == "group") then
							if d > 0.02 then fail(scenario, "self does not wear the group's colour on the " .. carrier) end
						elseif d < 0.17 then
							fail(scenario, ("%s and %s are %.2f apart on the %s in the %s set"):format(a, b, d, carrier, palette))
						end
					end
				end
			end
		end
	end
	-- The modes: the icon's thread, the tag's thread, both, neither.
	local function colours(mode)
		paint(mode, "standard", "group")
		local c = threadOf()
		return c, look.iconRim._color, look.enamel._color, look.enamel._shown ~= false and FT.visible(look.enamel)
	end
	local cr, cg, cb = ns.Prompt:AccentColor("group")
	local thread, rim, enamel, shown = colours("icon")
	if not sameColour(thread, CREAM[1], CREAM[2], CREAM[3], 0.01) then fail(scenario, "on icon the tag's thread is not cream") end
	if sameColour(rim, CREAM[1], CREAM[2], CREAM[3], 0.01) then fail(scenario, "on icon the icon's thread is cream") end
	if not shown then fail(scenario, "on icon the eyelet has no enamel") end
	thread, rim, enamel, shown = colours("stripe")
	if sameColour(thread, CREAM[1], CREAM[2], CREAM[3], 0.01) then fail(scenario, "on stripe the tag's thread is cream") end
	if not sameColour(rim, CREAM[1], CREAM[2], CREAM[3], 0.01) then fail(scenario, "on stripe the icon's thread is not cream") end
	if not shown then fail(scenario, "on stripe the eyelet has no enamel") end
	thread, rim, enamel, shown = colours("both")
	if sameColour(thread, CREAM[1], CREAM[2], CREAM[3], 0.01) or sameColour(rim, CREAM[1], CREAM[2], CREAM[3], 0.01) then
		fail(scenario, "on both a thread is cream")
	end
	thread, rim, enamel, shown = colours("off")
	if not (sameColour(thread, CREAM[1], CREAM[2], CREAM[3], 0.01) and sameColour(rim, CREAM[1], CREAM[2], CREAM[3], 0.01)) then
		fail(scenario, "with the marker off the thread is not cream")
	end
	if shown then fail(scenario, "with the marker off the eyelet's hole is not left dark") end
	-- What the options page is told.
	local ring, stripe = look.AccentCarriers({ accentMode = "icon", showIcon = true })
	if ring ~= true or stripe ~= true then fail(scenario, "AccentCarriers: icon is the thread round the icon and the eyelet") end
	ring, stripe = look.AccentCarriers({ accentMode = "stripe", showIcon = true })
	if ring ~= false or stripe ~= true then fail(scenario, "AccentCarriers: stripe is the tag's thread, not the icon's") end
	ring, stripe = look.AccentCarriers({ accentMode = "both", showIcon = true })
	if ring ~= true or stripe ~= true then fail(scenario, "AccentCarriers: both is both") end
	ring, stripe = look.AccentCarriers({ accentMode = "icon", showIcon = false })
	if ring ~= false or stripe ~= true then fail(scenario, "AccentCarriers: with the icon off the eyelet carries it alone") end
	ring, stripe = look.AccentCarriers({ accentMode = "off", showIcon = true })
	if ring ~= false or stripe ~= false then fail(scenario, "AccentCarriers: the marker off carries something") end
	-- One colour for every reason when the player says so.
	p.accentMode, p.accentByReason, p.accentColor = "both", false, { 0.2, 0.9, 0.3, 1 }
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	if not lightened(look.thread.top._color, { 0.2, 0.9, 0.3 }) or not lightened(look.iconRim._color, { 0.2, 0.9, 0.3 }) then
		fail(scenario, "the marker colour the player chose is not the thread's")
	end
	-- The icon off: no setting drawn, the tag's thread and the enamel carry it.
	p.accentByReason, p.showIcon, p.accentMode = true, false, "both"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	if FT.visible(look.iconRim) then fail(scenario, "the icon's setting is drawn with the icon off") end
	if sameColour(look.thread.top._color, CREAM[1], CREAM[2], CREAM[3], 0.01) then
		fail(scenario, "with the icon off the tag's thread does not carry the reason")
	end
end)

-- The outcomes colour the thread and the enamel in the verdict's green or red.
withTree("look-leather: the outcome keeps the name and writes the verdict, in the verdict's colour", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	Mock.advance(3)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if tostring(r.name:GetText()):find("Anna", 1, true) ~= 1 then fail(scenario, "a landed buff moved the name: " .. tostring(r.name:GetText())) end
	if r.sub:GetText() ~= "buffed" then fail(scenario, "a landed buff's verdict is " .. tostring(r.sub:GetText())) end
	local t = look.thread.top._color
	if not (t and t[2] > t[1] and t[2] > t[3]) then fail(scenario, "the thread is not green for a landed buff") end
	local e = look.enamel._color
	if not (e and e[2] > e[1]) then fail(scenario, "the enamel is not green for a landed buff") end
	Mock.advance(3)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if r.sub:GetText() ~= "Out of range." then fail(scenario, "a refusal's verdict is " .. tostring(r.sub:GetText())) end
	t = look.thread.top._color
	if not (t and t[1] > t[2] and t[1] > t[3]) then fail(scenario, "the thread is not red for a refusal") end
	Mock.advance(3)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if r.sub:GetText() ~= "sent, unconfirmed" then fail(scenario, "a cast nobody confirmed says " .. tostring(r.sub:GetText())) end
	-- And the next paint takes the reason back.
	Mock.advance(3)
	owe(ns, "Anna Aim")
	tick(ns)
	if r.sub:GetText() ~= "buffed you" then fail(scenario, "the reason did not come back: " .. tostring(r.sub:GetText())) end
end)

withTree("look-leather: a German client's outcome keeps the name and says the verdict in German", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local L = ns.L
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if r.sub:GetText() ~= L["buffed"] then fail(scenario, "the verdict is " .. tostring(r.sub:GetText()) .. ", not " .. L["buffed"]) end
	if tostring(r.name:GetText()):find("Anna", 1, true) ~= 1 then fail(scenario, "the name moved") end
	Mock.advance(3)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if r.sub:GetText() ~= L["sent, unconfirmed"] then fail(scenario, "the unconfirmed verdict is " .. tostring(r.sub:GetText())) end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 7
-- The text reads on the leather: the name and the reason against the brightest
-- the leather gets (its middle piece's mean and a margin, at its lightest end),
-- on a dark panel, a light one and with a text colour too dark for brown.
local function leatherLuminance(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	local w, h = data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
	local sum, sum2, n = 0, 0, 0
	for y = 12, h - 13, 3 do
		for x = 0, w - 1, 3 do
			local at = 18 + (y * w + x) * 4
			local b, g, r = data:byte(at + 1), data:byte(at + 2), data:byte(at + 3)
			local l = lum({ r / 255, g / 255, b / 255 })
			sum, sum2, n = sum + l, sum2 + l * l, n + 1
		end
	end
	local mean = sum / n
	return mean, math.sqrt(math.max(0, sum2 / n - mean * mean))
end

withTree("look-leather: the text reads on the leather", ANNA, function(ns, scenario)
	local mean, sd = leatherLuminance(dir .. "/Textures/Leather/Leather_BodyM.tga")
	if not mean then fail(scenario, "SKIPPED -- the leather's art cannot be read") return end
	-- The brightest the leather is behind a letter: its lightest end (the
	-- gradient's left), the mean and a deviation and a third, about the ninetieth percentile.
	local ground = { 1, 1, 1 }
	local function groundLum(look)
		local g = look.body[2]._gradient
		local c = g and g[2]
		local k = 1
		if c then
			local cr, cg, cb = c.r or c[1], c.g or c[2], c.b or c[3]
			-- The art's own colour scaled by the vertex colour: a luminance, as a
			-- grey scaled by the brightest channel is an upper bound.
			k = math.max(cr, cg, cb)
		end
		return math.min(1, (mean + 1.3 * sd) * k * k)
	end
	local function check(label, text, look, minimum)
		if type(text) ~= "table" or not (text[1] and text[2] and text[3]) then
			fail(scenario, label .. " has no colour to judge")
			return
		end
		local l = groundLum(look)
		local got = ratio(lum(text), l)
		if got < minimum then fail(scenario, ("%s is %.2f:1 on leather of luminance %.2f, under %.1f"):format(label, got, l, minimum)) end
	end
	for _, variant in ipairs({
		{ "dark panel", function(p) end },
		{ "light panel", function(p) p.bgColor = { 0.86, 0.84, 0.78, 0.92 } end },
		{ "a dark text colour", function(p) p.fontColor = { 0.10, 0.10, 0.12, 1 } end },
		{ "a blue panel", function(p) p.bgColor = { 0.30, 0.45, 0.80, 0.92 } end },
	}) do
		for _, palette in ipairs({ "standard", "colourblind" }) do
			local r, p, look = upIn(ns, scenario, function(pp) pp.reasonPalette = palette variant[2](pp) end)
			if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
			for _, reason in ipairs(REASONS) do
				ns.Prompt:ApplyStyle()
				ns.Prompt:PaintAccent(reason)
				check(("the name on the leather for %s (%s, %s)"):format(reason, palette, variant[1]), r.name._textColor, look, 4.5)
				check(("the reason on the leather for %s (%s, %s)"):format(reason, palette, variant[1]), r.sub._textColor, look, 4.0)
				for _, kind in ipairs({ "cast", "failed", "sent" }) do
					Mock.advance(3)
					ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
					check("the verdict on the leather (" .. kind .. ")", r.sub._textColor, look, 4.0)
				end
				Mock.advance(3)
			end
			-- The count and the list.
			check("the count on its patch", r.count._textColor, look, 4.5)
			for _, fs in ipairs(r.rows) do check("a list name on its tag", fs._textColor, look, 4.0) end
			-- A class colour as the look softens it, held to the 3:1 the prompt holds codes to.
			local soften = look.classSoften or 0
			for _, code in ipairs({ "c41e3a", "a330c9", "ff7c0a", "33937f", "aad372", "3fc7eb", "00ff98", "f48cba",
				"ffffff", "fff468", "0070dd", "8788ee", "c69b6d" }) do
				local cr, cg, cb = tonumber(code:sub(1, 2), 16) / 255, tonumber(code:sub(3, 4), 16) / 255, tonumber(code:sub(5, 6), 16) / 255
				cr, cg, cb = cr + (1 - cr) * soften, cg + (1 - cg) * soften, cb + (1 - cb) * soften
				local l = groundLum(look)
				if ratio(lum({ cr, cg, cb }), l) < 3 then
					fail(scenario, ("the class colour %s is under 3:1 on the leather (%s)"):format(code, variant[1]))
				end
			end
		end
	end
	-- Colour codes in the name are left as they were picked for a dark ground on a
	-- light panel: the prompt did not take them dark for a ground the leather is not.
	local r, p, look = upIn(ns, scenario, function(pp) pp.bgColor = { 0.86, 0.84, 0.78, 0.92 } end)
	r.name:SetText("x")
	ns.Prompt.lib.SetLine(r.name, "|cffffffffWhite|r")
	if tostring(r.name:GetText()):lower():find("|cff[0-4]", 1) then
		fail(scenario, "a light code in the name was taken dark on a light panel: " .. tostring(r.name:GetText()))
	end
end)

-- ------------------------------------------------------------------ 8
-- The fonts: the display serif for the name in the Latin alphabet, the
-- player's own choice wins, the other alphabets keep the client's.
for _, case in ipairs({
	{ "enUS", true }, { "enGB", true }, { "deDE", true }, { "esES", true }, { "esMX", true }, { "frFR", true },
	{ "itIT", true }, { "ptBR", true }, { "koKR", false }, { "zhCN", false }, { "zhTW", false }, { "ruRU", false },
}) do
	local locale, serif = case[1], case[2]
	withTree("look-leather: the name's face on a " .. locale .. " client", ANNA, function(ns, scenario)
		local r, p, look = upIn(ns, scenario)
		if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
		local path = r.name._font and r.name._font.path
		local fit = ns.Prompt.lib.fit
		if serif then
			if path ~= "Fonts\\MORPHEUS.TTF" then fail(scenario, "the name is in " .. tostring(path) .. ", not the display serif") end
			if r.sub._font and r.sub._font.path == "Fonts\\MORPHEUS.TTF" then fail(scenario, "the reason is in the display serif too") end
			if fit.paths[r.name] ~= "Fonts\\MORPHEUS.TTF" then fail(scenario, "FitLine does not keep the name in its face as it shrinks") end
		else
			if path == "Fonts\\MORPHEUS.TTF" then fail(scenario, "a " .. locale .. " client's name is in a Latin-only face") end
			if fit.paths[r.name] then fail(scenario, "a face is named for the name on a " .. locale .. " client") end
		end
		-- A line too long shrinks and stays in its face.
		r.name:SetText("A name far too long to fit the room it has been given on this tag")
		ns.Prompt.lib.FitLine(r.name)
		local shrunk = r.name._font and r.name._font.path
		if serif and shrunk ~= "Fonts\\MORPHEUS.TTF" then fail(scenario, "a shrunk name left the display serif for " .. tostring(shrunk)) end
		-- The player's own font wins.
		p.font = "Arial Narrow"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if r.name._font and r.name._font.path == "Fonts\\MORPHEUS.TTF" then
			fail(scenario, "the player's chosen font was not used for the name")
		end
		if fit.paths[r.name] then fail(scenario, "a face is named for the name with the player's own font chosen") end
	end, function() Mock.locale = locale end)
end

withTree("look-leather: leaving the look leaves the name's face to the next look", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if ns.Prompt.lib.fit.paths[r.name] then fail(scenario, "the name is still held to the display serif on glass") end
	if r.name._font and r.name._font.path == "Fonts\\MORPHEUS.TTF" then fail(scenario, "the name is still in the display serif on glass") end
end)

-- ------------------------------------------------------------------ 9
-- The list: tags hung on the same ring, each name a secure button on a frame,
-- each tag's enamel in its row's reason colour.
withTree("look-leather: the list hangs from the same ring, its names secure buttons on frames", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local panel = rectOf(r.art)
	local function check(label, above)
		local shown = 0
		for i, row in ipairs(r.rows) do
			if row:IsShown() and (row:GetText() or "") ~= "" then
				shown = shown + 1
				local at = row.points[#row.points]
				if not at then
					fail(scenario, label .. ": row " .. i .. " has no place")
				else
					local y = -at[5]
					if above and not (y < 0) then fail(scenario, label .. ": row " .. i .. " is not over the panel") end
					if not above and not (y > panel[4] - panel[2]) then fail(scenario, label .. ": row " .. i .. " is not under the panel") end
					local rel = at[2]
					if rel ~= r.art and rel ~= ns.Prompt:GetButton() then fail(scenario, label .. ": row " .. i .. " is not anchored to a frame") end
				end
				local tag = look.tags[i]
				local body = { rectOf(tag.body[1]), rectOf(tag.body[2]), rectOf(tag.body[3]) }
				local box = body[1] and body[3] and { body[1][1], math.min(body[1][2], body[3][2]), body[3][3], math.max(body[1][4], body[3][4]) }
				local text = rectOf(row)
				if not (box and FT.visible(tag.body[2])) then
					fail(scenario, label .. ": row " .. i .. " wears no tag")
				else
					if text and not inside(text, box) then fail(scenario, label .. ": row " .. i .. "'s text leaves its tag") end
					-- The eyelet hangs on the main tag's column, and the text stops short of it.
					local eye, main = rectOf(tag.eyelet), rectOf(look.eyelet)
					if not (eye and main and near((eye[1] + eye[3]) / 2, (main[1] + main[3]) / 2, 0.05)) then
						fail(scenario, label .. ": row " .. i .. "'s eyelet is not under the main tag's")
					end
					if eye and text and text[3] > eye[1] + 0.01 then fail(scenario, label .. ": row " .. i .. "'s text runs over its eyelet") end
					local dot = rectOf(tag.dot)
					if dot and text and dot[3] > text[1] + 0.01 then fail(scenario, label .. ": row " .. i .. "'s dot is over its text") end
					if dot and box and not inside(dot, box) then fail(scenario, label .. ": row " .. i .. "'s dot leaves its tag") end
					-- Inside the prompt's width.
					if box and (box[1] < panel[1] - 0.01 or box[3] > panel[3] + 0.01) then
						fail(scenario, label .. ": row " .. i .. "'s tag is wider than the prompt")
					end
					if above and not (box[2] >= panel[4] - 0.01) then fail(scenario, label .. ": tag " .. i .. " is not over the panel") end
					if not above and not (box[4] <= panel[2] + 0.01) then fail(scenario, label .. ": tag " .. i .. " is not under the panel") end
				end
			end
		end
		if shown == 0 then fail(scenario, label .. ": no row is shown") end
		-- Tags beyond the rows are gone.
		for i = shown + 1, #look.tags do
			if FT.visible(look.tags[i].body[2]) then fail(scenario, label .. ": tag " .. i .. " is up with no row") end
		end
		-- The click areas hang off the rows' text, on frames.
		local buttons = 0
		for _, button in ipairs(r.rowButtons or {}) do
			if button:IsShown() then
				buttons = buttons + 1
				for _, pt in ipairs(button.points or {}) do
					local rel = pt[2]
					if rel and (rel._kind == "Texture" or rel._kind == "FontString") then
						fail(scenario, label .. ": a name's button is anchored to a region")
					end
				end
			end
		end
		if buttons == 0 then fail(scenario, label .. ": no name is a button") end
	end
	check("below", false)
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	tick(ns)
	check("above", true)
	-- A row fewer: its tag goes, the others stay.
	ns.BlockPerson("Corwin Ash")
	tick(ns)
	local up = 0
	for _, tag in ipairs(look.tags) do if FT.visible(tag.body[2]) then up = up + 1 end end
	local rows = 0
	for _, row in ipairs(r.rows) do if row:IsShown() and (row:GetText() or "") ~= "" then rows = rows + 1 end end
	if up ~= rows then fail(scenario, ("%d tags are up for %d rows"):format(up, rows)) end
	-- Each row's enamel in the colour of its reason, both palettes.
	for _, palette in ipairs({ "standard", "colourblind" }) do
		ns.db.profile.prompt.reasonPalette = palette
		ns.Prompt:ApplyStyle()
		tick(ns)
		for i, tag in ipairs(look.tags) do
			if FT.visible(tag.dot) and tag.dot._color then
				local ok = false
				for _, reason in ipairs(REASONS) do
					local c = look.kit.ReasonColor(reason)
					local fits, t = lightened(tag.dot._color, c)
					-- Lightened, never all the way to white.
					if fits and t < 0.9 then ok = true end
				end
				if not ok then fail(scenario, ("tag %d's enamel is not in a colour of the %s set"):format(i, palette)) end
			end
		end
	end
	-- Gone with the list.
	ns.db.profile.prompt.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, tag in ipairs(look.tags) do
		if FT.visible(tag.body[2]) or FT.visible(tag.eyelet) or FT.visible(tag.dot) then
			fail(scenario, "tag " .. i .. " stays with the list off")
		end
	end
end)

-- ------------------------------------------------------------------ 10
-- The icon: a rounded square set in the leather, round when the player says so,
-- the sweep in its shape.
withTree("look-leather: the icon is set in square or round, and the sweep follows it", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local cd = r.cooldown
	if look.iconRim._file ~= ART .. "Leather_IconRim" or look.mask._file ~= ART .. "Leather_IconMask" then fail(scenario, "the square icon is not set in the square rim") end
	if cd and cd._swipeTexture ~= ART .. "Leather_IconMask" then fail(scenario, "the square icon's sweep is " .. tostring(cd._swipeTexture)) end
	if cd and cd._circular then fail(scenario, "the square icon's sweep has a round edge") end
	if r.icon._mask ~= look.mask then fail(scenario, "the icon is not cut by the look's mask") end
	p.roundIcon = true
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.iconRim._file ~= ART .. "Leather_IconRimRd" or look.mask._file ~= ART .. "Leather_IconMaskRd" then fail(scenario, "the round icon is not set in the round rim") end
	if cd and cd._swipeTexture ~= ART .. "Leather_IconMaskRd" then fail(scenario, "the round icon's sweep is " .. tostring(cd._swipeTexture)) end
	if cd and cd._circular ~= true then fail(scenario, "the round icon's sweep has a square edge") end
	local rings = look.fx.rings[1].tex._file
	if rings ~= ART .. "Leather_FxRing" then fail(scenario, "a round icon's rings are drawn in " .. tostring(rings)) end
	p.roundIcon = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.fx.rings[1].tex._file ~= ART .. "Leather_FxRingSq" then fail(scenario, "a square icon's rings are not square") end
	-- The sweep runs over the icon for the global cooldown.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if cd and not cd._cooldown then fail(scenario, "the global cooldown draws no sweep on the icon") end
end)

-- ------------------------------------------------------------------ 11
-- The motion. Each effect plays on its own event and on no other.
local function groups(look, r)
	local arrive, land, reject = {}, {}, {}
	for _, g in ipairs(look.arrive) do arrive[#arrive + 1] = g end
	for _, g in ipairs(look.landing) do land[#land + 1] = g end
	land[#land + 1], land[#land + 2], land[#land + 3] = look.fx.rings[1].land, look.fx.rings[2].land, r.settle
	for _, g in ipairs(look.refusal) do reject[#reject + 1] = g end
	reject[#reject + 1] = look.fx.rings[1].reject
	return {
		arrive = arrive, land = land, reject = reject,
		shake = { r.shake }, settle = { r.settle },
		ring = { look.fx.rings[1].land, look.fx.rings[2].land },
		refuseRing = { look.fx.rings[1].reject },
		swing = { look.swing }, lit = look.lit, flash = look.flash, band = { look.landing[1] },
		jerk = { look.refusal[1] },
	}
end

local function snapshot(g)
	local out = {}
	for key, list in pairs(g) do out[key] = total(list) end
	return out
end

withTree("look-leather: a favour arriving swings the tag in once, for somebody owed", { nameplate1 = { "Anna", "Aim" },
	nameplate2 = { "Bert", "Beside" } }, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	wipe(ns.owed)
	tick(ns)
	Mock.advance(3)
	tick(ns)
	local g = groups(look, r)
	local before = snapshot(g)
	Mock.advance(0.4)
	tick(ns)
	Mock.advance(0.4)
	tick(ns)
	if snapshot(g).arrive ~= before.arrive then fail(scenario, "a passer-by on the panel played the favour's arrival") end
	owe(ns, "Anna Aim")
	tick(ns)
	local after = snapshot(g)
	if after.arrive <= before.arrive then fail(scenario, "somebody buffing you did not swing the tag in") end
	if after.swing <= before.swing then fail(scenario, "the tag did not swing") end
	if plays(look.arrive[#look.arrive]) < 1 then fail(scenario, "the brass did not glint") end
	Mock.advance(0.4)
	tick(ns)
	Mock.advance(0.4)
	tick(ns)
	if snapshot(g).arrive ~= after.arrive then fail(scenario, "the arrival played again on a repaint of the same favour") end
	local now = snapshot(g)
	if now.ring ~= before.ring or now.settle ~= before.settle or now.refuseRing ~= before.refuseRing
		or now.shake ~= before.shake or now.lit ~= before.lit or now.flash ~= before.flash or now.jerk ~= before.jerk then
		fail(scenario, "an arrival played the landing's or the refusal's effects")
	end
	-- Not over an outcome the panel is still showing.
	ns.BlockPerson("Anna Aim")
	ns.owed["Anna Aim"] = nil
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	owe(ns, "Bert Beside")
	local during = snapshot(g).arrive
	Mock.advance(0.2)
	tick(ns)
	if snapshot(g).arrive ~= during then fail(scenario, "the arrival of the next favour played over the confirmation of the last") end
end)

-- The swing sums to nothing, on the art and not on the secure button, and what
-- hangs from the eyelet is held by the opposite movement.
withTree("look-leather: the swing sums to nothing and the eyelet is held still by the opposite movement", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local function steps(group)
		local out = {}
		for _, a in ipairs(group._anims) do
			out[#out + 1] = { order = a._order, dx = a._offset and a._offset[1] or 0, dy = a._offset and a._offset[2] or 0,
				d = a._duration, smooth = a._smoothing }
		end
		table.sort(out, function(a, b) return a.order < b.order end)
		return out
	end
	local function sum(list)
		local sx, sy = 0, 0
		for _, s in ipairs(list) do sx, sy = sx + s.dx, sy + s.dy end
		return sx, sy
	end
	local swing, button = look.swing, ns.Prompt:GetButton()
	if swing._owner ~= r.art then fail(scenario, "the swing is not on the art") end
	if swing._owner == button then fail(scenario, "the swing is on the secure button") end
	local own = steps(swing)
	local sx, sy = sum(own)
	if math.abs(sx) > 0.001 or math.abs(sy) > 0.001 then fail(scenario, ("the swing adds up to %.1f, %.1f, so the tag ends displaced"):format(sx, sy)) end
	if #own < 4 then fail(scenario, "the swing has only " .. #own .. " steps") end
	-- It dies away: after its largest step none is larger than the last.
	local peak, at = 0, 1
	for i, s in ipairs(own) do if math.abs(s.dy) > peak then peak, at = math.abs(s.dy), i end end
	for i = at + 1, #own do
		if math.abs(own[i].dy) > math.abs(own[i - 1].dy) then fail(scenario, "the swing grows again after its peak") end
	end
	if math.abs(own[#own].dy) >= peak / 2 then fail(scenario, "the swing ends nearly as hard as it began") end
	if peak > 10 then fail(scenario, "the swing is " .. peak .. " units, too far for a tag that stays in its box") end
	-- Each thing on the eyelet's frames moves the opposite way, step for step.
	local held = 0
	for _, f in ipairs({ look.ringFrame, look.ringGlowFrame, look.starFrame }) do
		local counter
		for _, g in ipairs(look.arrive) do if g._owner == f then counter = g end end
		if not counter then
			fail(scenario, "a frame of the eyelet has no movement of its own to hold it")
		else
			held = held + 1
			local theirs = steps(counter)
			if #theirs ~= #own then fail(scenario, "the eyelet's counter-movement has a different number of steps") end
			for i, s in ipairs(theirs) do
				if own[i] and (not near(s.dx, -own[i].dx, 0.001) or not near(s.dy, -own[i].dy, 0.001) or not near(s.d, own[i].d, 0.001)
					or s.smooth ~= own[i].smooth) then
					fail(scenario, "the eyelet's step " .. i .. " is not the swing's opposite")
				end
			end
		end
	end
	if held ~= 3 then fail(scenario, "the eyelet, its glow and the glint are not all held still") end
	-- The refusal's jerk the same, and it dies away.
	local jerk = steps(look.refusal[1])
	sx, sy = sum(jerk)
	if math.abs(sx) > 0.001 or math.abs(sy) > 0.001 then fail(scenario, ("the jerk adds up to %.1f, %.1f"):format(sx, sy)) end
	if FT.groupLength(look.refusal[1]) > 0.35 then fail(scenario, "the jerk is longer than the shake's 0.35 s") end
	local counters = 0
	for _, g in ipairs(look.refusal) do
		if g._owner == look.ringFrame or g._owner == look.ringGlowFrame or g._owner == look.starFrame then counters = counters + 1 end
	end
	if counters ~= 3 then fail(scenario, "the eyelet is not held still against the jerk") end
end)

withTree("look-leather: a landed buff lights the thread piece by piece and a refusal flashes it red and amber", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	Mock.advance(1)
	FT.settle()
	local g = groups(look, r)
	local s0 = snapshot(g)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local s1 = snapshot(g)
	if s1.ring - s0.ring < 2 then fail(scenario, "a buff the game confirmed did not spread both rings from the icon") end
	if s1.lit - s0.lit < #look.pieces then fail(scenario, "a landed buff did not light every piece of the thread") end
	if s1.band <= s0.band then fail(scenario, "a landed buff did not send the light across the leather") end
	if s1.settle <= s0.settle then fail(scenario, "a landed buff did not settle the panel") end
	if s1.shake ~= s0.shake or s1.refuseRing ~= s0.refuseRing or s1.jerk ~= s0.jerk or s1.flash ~= s0.flash then
		fail(scenario, "a landed buff shook the text, jerked the tag or flashed it red")
	end
	-- One after another round the tag: the delays rise along the order, from the
	-- top left, round the right end and back along the bottom to the left end.
	local last = -1
	for i, group in ipairs(look.lit) do
		local delay = group._anims[1]._startDelay or 0
		if delay <= last + 1e-6 then fail(scenario, "the thread's pieces do not light one after another (piece " .. i .. ")") break end
		last = delay
	end
	local kinds = {}
	for _, piece in ipairs(look.pieces) do kinds[#kinds + 1] = piece.kind end
	if kinds[1] ~= "top" or kinds[#kinds] ~= "left" or kinds[7] ~= "right" then
		fail(scenario, "the pieces are not in the order round the tag: " .. table.concat(kinds, " "))
	end
	local c = look.pieces[1].tex._color
	if not (c and c[2] > c[1] and c[2] > c[3]) then fail(scenario, "the lit thread is not green") end
	Mock.advance(1)
	FT.settle()
	local s2 = snapshot(g)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local s3 = snapshot(g)
	if s3.refuseRing <= s2.refuseRing then fail(scenario, "a refusal did not contract a ring onto the icon") end
	if s3.shake <= s2.shake then fail(scenario, "a refusal did not shake the text") end
	if s3.jerk <= s2.jerk then fail(scenario, "a refusal did not jerk the tag") end
	if s3.flash - s2.flash < #look.pieces then fail(scenario, "a refusal did not flash every piece of the thread") end
	if s3.ring ~= s2.ring or s3.settle ~= s2.settle or s3.lit ~= s2.lit or s3.band ~= s2.band then
		fail(scenario, "a refusal spread the landing's rings, lit the thread in turn or settled the panel as if it had landed")
	end
	-- Red and amber in turn.
	local reds, ambers = 0, 0
	for _, piece in ipairs(look.pieces) do
		local col = piece.tex._color
		if col and col[1] > 0.9 and col[2] < 0.4 then reds = reds + 1 end
		if col and col[1] > 0.9 and col[2] > 0.6 and col[2] < 0.85 and col[3] < 0.4 then ambers = ambers + 1 end
	end
	if reds < 3 or ambers < 3 then fail(scenario, ("the thread flashes %d red and %d amber, not both in turn"):format(reds, ambers)) end
	Mock.advance(1)
	FT.settle()
	local s4 = snapshot(g)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	local s5 = snapshot(g)
	if s5.land ~= s4.land or s5.reject ~= s4.reject or s5.shake ~= s4.shake then
		fail(scenario, "a cast nobody confirmed got a flourish, which claims more than the settle path knows")
	end
end)

withTree("look-leather: Calm is fades only: nothing moves, nothing loops", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local g = groups(look, r)
	local s0 = snapshot(g)
	local pulse0 = total(look.pulse)
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	tick(ns)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	local s1 = snapshot(g)
	for key, v in pairs(s1) do
		if v ~= s0[key] then fail(scenario, "with Effects on Calm the " .. key .. " still played") end
	end
	if total(look.pulse) ~= pulse0 or looping() > 0 then fail(scenario, "something glows in a loop on Calm") end
	for _, a in ipairs(r.introCalm._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "Calm's entrance has a " .. tostring(a._kind) .. " in it, not only a fade") end
	end
	-- What Calm does play is a fade and nothing else.
	for _, a in ipairs(look.soft._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "Calm's glow has a " .. tostring(a._kind) .. " in it, not only a fade") end
	end
	if plays(look.soft) < 1 then fail(scenario, "Calm gives a favour no soft glow at all") end
	-- Every light parked at nothing.
	Mock.advance(3)
	FT.settle()
	for _, f in ipairs({ look.glowFrame, look.ringGlowFrame, look.bandFrame }) do
		if (f._alpha or 0) > 0.001 then fail(scenario, "a light is left lit on Calm") end
	end
	for _, piece in ipairs(look.pieces) do
		if (piece.tex._alpha or 0) > 0.001 then fail(scenario, "a piece of the thread is left lit on Calm") break end
	end
end)

withTree("look-leather: owed glows three times and rests, and stops with the favour", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	if not look.pulse[1]._playing then fail(scenario, "somebody owed on top on Full, and the thread does not glow") end
	if #look.pulse ~= 2 or not look.pulse[2]._playing then fail(scenario, "the brass does not glow with the thread") end
	local breath
	for i, group in ipairs(look.pulse) do
		local d = group._anims[1]._duration
		if breath and d ~= breath then fail(scenario, "the thread and the brass glow at different rates") end
		breath = d
		if group._looping ~= "BOUNCE" then fail(scenario, "glow " .. i .. " does not bounce") end
	end
	if not breath or breath * 2 < 2 or breath * 2 > 3 then
		fail(scenario, ("the owed glow is %.2f s round, not 2 to 3"):format((breath or 0) * 2))
	end
	-- Warm: the brass's glow is amber, the thread's too.
	local warm = look.warmRing._color
	if not (warm and warm[1] > warm[3] + 0.3) then fail(scenario, "the brass's glow is not warm") end
	local w = look.glow.top._color
	if not (w and w[1] > w[3] + 0.3) then fail(scenario, "the thread's glow is not warm") end
	-- Let go as the third breath ends, not a scan later.
	Mock.runTimers(10)
	if look.pulse[1]._playing or looping() > 0 then fail(scenario, "the owed glow still loops after its three breaths") end
	if (look.glowFrame._alpha or 0) > 0.001 or (look.ringGlowFrame._alpha or 0) > 0.001 then
		fail(scenario, "after its breaths the glow is not let go")
	end
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "the scan started the spent glow again") end
	-- A new favour on top takes its own three breaths.
	wipe(ns.owed)
	tick(ns)
	if looping() > 0 then fail(scenario, "a loop kept going with nobody owed") end
	owe(ns, "Brannoc Vale")
	tick(ns)
	if not look.pulse[1]._playing then fail(scenario, "a new favour did not glow") end
	wipe(ns.owed)
	tick(ns)
	if look.pulse[1]._playing or (look.glowFrame._alpha or 0) > 0 or (look.ringGlowFrame._alpha or 0) > 0 then
		fail(scenario, "the glow stayed with nobody owed")
	end
	owe(ns, "Anna Aim")
	tick(ns)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if look.pulse[1]._playing then fail(scenario, "the owed glow kept going over an outcome") end
	for _, style in ipairs({ "once", "off" }) do
		Mock.advance(3)
		ns.db.profile.prompt.flashStyle = style
		wipe(ns.owed)
		tick(ns)
		owe(ns, "Anna Aim")
		tick(ns)
		if looping() > 0 then fail(scenario, ("%d loop(s) on '%s'"):format(looping(), style)) end
	end
end)

withTree("look-leather: the effects stay inside their time and their room under the text", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local function within(group, limit, what)
		if group and FT.groupLength(group) > limit then
			fail(scenario, ("%s lasts %.2f s, over %.2f"):format(what, FT.groupLength(group), limit))
		end
	end
	for i, g in ipairs(look.arrive) do within(g, 0.7, "an arrival's effect " .. i) end
	for i, g in ipairs(look.landing) do within(g, 0.7, "a landing's effect " .. i) end
	for i, g in ipairs(look.refusal) do within(g, 0.5, "a refusal's effect " .. i) end
	within(look.soft, 0.8, "Calm's glow")
	within(look.fx.rings[1].reject, 0.35, "a refusal's ring")
	-- Every frame of light is beneath the text's frame level, and the chips'
	-- patches under it too.
	local text = r.textLayer._level or 0
	for name, f in pairs({ thread = look.threadFrame, icon = look.iconFrame, ring = look.ringFrame, glow = look.glowFrame,
		ringGlow = look.ringGlowFrame, lit = look.litFrame, band = look.bandFrame, star = look.starFrame,
		chips = look.chipFrame, ring1 = look.fx.frames[1], ring2 = look.fx.frames[2] }) do
		if (f._level or 0) >= text then fail(scenario, name .. " is not beneath the text") end
	end
	-- The glow and the pieces are over the thread; the eyelet is over the leather.
	if not ((look.threadFrame._level or 0) < (look.glowFrame._level or 0)) then fail(scenario, "the thread's glow is not over the thread") end
	if not ((look.threadFrame._level or 0) < (look.litFrame._level or 0)) then fail(scenario, "the lit thread is not over the thread") end
	-- The band crosses the straight and starts past the left end, so it never
	-- lights the corners that are not leather.
	local band, panel = rectOf(look.bandFrame), rectOf(r.art)
	if band and panel then
		if band[1] < panel[1] + look.capL - 0.01 then fail(scenario, "the band starts over the left end") end
		local move = look.bandMove._offset and look.bandMove._offset[1] or 0
		if band[3] + move > panel[3] - look.capR + 0.5 then fail(scenario, "the band ends over the right end") end
		if band[2] < panel[2] or band[4] > panel[4] then fail(scenario, "the band is taller than the leather") end
	end
	-- Nothing that stays on screen is additive: the rested look draws only BLEND.
	Mock.advance(10)
	FT.settle()
	for i, x in ipairs(look.own) do
		if x._kind == "Texture" and x._blend == "ADD" and FT.visible(x) then
			local a = 1
			local node = x
			while node do
				a = a * (node._alpha == nil and 1 or node._alpha)
				node = node._parent
			end
			if a > 0.001 then fail(scenario, "an additive texture (" .. tostring(x._file):gsub("^.*Leather_", "") .. ") is lit at rest") end
		end
	end
	-- And no effect scales a thing over the text.
	for _, g in ipairs(FT.groups()) do
		local o = g._owner
		for _, a in ipairs(g._anims) do
			if a._kind == "Scale" and o and o._kind ~= "Frame" then fail(scenario, "a scale on a region") end
		end
	end
	for _, group in ipairs(look.anims) do
		for _, a in ipairs(group._anims) do
			if a._kind == "Scale" then fail(scenario, "the look scales something: the rings are the shared FX's, and nothing else") end
			if a._kind == "Rotation" then fail(scenario, "the look rotates something, which a frame cannot do") end
		end
	end
end)

withTree("look-leather: in a fight no effect touches a protected frame, and none plays when quiet", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local button = ns.Prompt:GetButton()
	Mock.protect(button)
	for _, row in ipairs(r.rowButtons or {}) do Mock.protect(row) end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.protectedCalls = {}
	local g = groups(look, r)
	local s0 = snapshot(g)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if #Mock.protectedCalls > 0 then
		fail(scenario, "an outcome's effects in a fight called " .. table.concat(Mock.protectedCalls, ", ") .. " on the secure frame")
	end
	if snapshot(g).shake <= s0.shake then fail(scenario, "SKIPPED -- the refusal did not play in the fight") end
	for _, group in ipairs(FT.groups()) do
		local o = group._owner
		if o == button or (o and o._protected) then fail(scenario, "an animation group is on a protected frame") break end
	end
	ns.db.profile.prompt.hideInCombat = true
	Mock.advance(1)
	local s2 = snapshot(g)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local s3 = snapshot(g)
	for _, key in ipairs({ "land", "reject", "shake", "settle", "lit", "flash", "jerk" }) do
		if s3[key] ~= s2[key] then fail(scenario, "with the prompt kept dim and still in combat the " .. key .. " still played") end
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
end)

withTree("look-leather: every effect stops on a repaint and on a restyle, and parks what it lit", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local g = groups(look, r)
	local function anyPlaying(skip)
		for _, key in ipairs({ "land", "reject", "shake" }) do
			for _, group in ipairs(g[key]) do
				if group._playing and not (skip and skip[group]) then return true end
			end
		end
		return false
	end
	if not anyPlaying() then fail(scenario, "SKIPPED -- nothing played for the landing") return end
	ns.Prompt:StopFlourishes()
	if anyPlaying() then fail(scenario, "an effect was still playing after a repaint stopped them") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if anyPlaying({ [r.settle] = true }) then fail(scenario, "an effect of Leather was still playing after the look changed") end
	for _, piece in ipairs(look.pieces) do
		if (piece.tex._alpha or 0) > 0.001 then fail(scenario, "a piece of the thread was left lit after the look changed") break end
	end
	for _, f in ipairs({ look.glowFrame, look.ringGlowFrame, look.bandFrame }) do
		if (f._alpha or 0) > 0.001 then fail(scenario, "a light was left lit after the look changed") end
	end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "a region of Leather (" .. i .. ") is still shown on glass") break end
	end
end)

-- ------------------------------------------------------------------ 12
-- A fight greys the leather and the brass and keeps the reason; all of it
-- comes back.
withTree("look-leather: a fight greys the leather and keeps the reason", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local rested = look.body[2]._gradient and look.body[2]._gradient[2]
	local rr, rg, rb = rested and (rested.r or rested[1]), rested and (rested.g or rested[2]), rested and (rested.b or rested[3])
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	for i, t in ipairs(look.body) do
		if not t._desaturated then fail(scenario, "leather piece " .. i .. " keeps its colour in a fight") end
	end
	if not (look.eyelet._desaturated and look.sheen._desaturated) then fail(scenario, "the brass keeps its colour in a fight") end
	local c = look.body[2]._gradient and look.body[2]._gradient[2]
	if c and rr and (c.r or c[1]) >= rr - 0.01 then fail(scenario, "the leather is no darker in a fight") end
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	if not near(r.name._alpha, 0.78) then fail(scenario, "the name is not dimmed in a fight: " .. tostring(r.name._alpha)) end
	if (r.sub._alpha or 1) < 0.999 or (r.textLayer._alpha or 1) < 0.999 then fail(scenario, "the reason is dimmed in a fight") end
	if not r.sub:IsShown() or tostring(r.sub._text or "") == "" then fail(scenario, "the reason is not kept in a fight") end
	if look.pulse[1]._playing or looping() > 0 then fail(scenario, "something still glows in a fight") end
	if sameColour(look.thread.top._color, 0.93, 0.76, 0.54, 0.01) then fail(scenario, "the thread is still cream in a fight") end
	if (r.art._alpha or 1) < 0.999 then fail(scenario, "the art itself is dimmed (the look dims its own parts): " .. tostring(r.art._alpha)) end
	if not FT.visible(r.sub) then fail(scenario, "the reason is hidden in a fight") end
	-- The thread's light does not play over the fight, and a restyle in the fight keeps it.
	p.width = 240
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	for i, t in ipairs(look.body) do
		if not t._desaturated then fail(scenario, "leather piece " .. i .. " came back during the fight") end
	end
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.advance(2)
	tick(ns)
	for i, t in ipairs(look.body) do
		if t._desaturated then fail(scenario, "leather piece " .. i .. " stays grey after the fight") end
	end
	if look.eyelet._desaturated or r.icon._desaturated then fail(scenario, "the brass or the icon stays grey after the fight") end
	if not near(r.name._alpha, 1) then fail(scenario, "the name stays dim after the fight") end
	c = look.body[2]._gradient and look.body[2]._gradient[2]
	if c and rr and not near(c.r or c[1], rr, 0.01) then fail(scenario, "the leather's colour did not come back") end
end)

-- ------------------------------------------------------------------ 13
-- Leaving the look gives the lines, the icon and the sweep back.
withTree("look-leather: leaving it gives the lines, the icon and the sweep back", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if r.icon._mask ~= nil and r.icon._mask == look.mask then fail(scenario, "the icon is still cut by Leather's mask") end
	if r.icon._desaturated then fail(scenario, "the icon is still grey on glass") end
	if r.icon._color and (r.icon._color[1] < 0.999 or r.icon._color[2] < 0.999) then fail(scenario, "the icon is still dimmed on glass") end
	if r.cooldown and (r.cooldown._circular or tostring(r.cooldown._swipeTexture or ""):find("Leather", 1, true) and false) then
		fail(scenario, "the sweep keeps a round edge on glass")
	end
	if r.cooldown and (r.cooldown._alpha or 1) < 0.999 then fail(scenario, "the sweep stays dimmed on glass") end
	if not near(r.name._alpha or 1, 1) or not near(r.textLayer._alpha or 1, 1) then fail(scenario, "the text stays dimmed on glass") end
	if not near(r.count._alpha or 1, 1) then fail(scenario, "the count stays dimmed on glass") end
	-- Once the outcome is over, the others waiting are counted on glass as ever.
	Mock.advance(3)
	owe(ns, "Anna Aim")
	tick(ns)
	if not r.count:IsShown() or tostring(r.count._text or "") == "" then fail(scenario, "the count stays hidden on glass") end
	if (r.textLayer._level or 0) ~= (r.art._level or 0) + ns.Prompt.lib.TEXT_LEVEL then fail(scenario, "the text's frame level was not put back") end
	if (r.name._shadowOffset or { 1 })[1] ~= 1 or (r.sub._shadowOffset or { 1 })[1] ~= 1 then fail(scenario, "the shadows were not given back") end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "a region of Leather (" .. i .. ") is still shown on glass") break end
	end
	-- And back again: nothing was left half done.
	p.style = "leather"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (r.icon._mask == look.mask and look.body[2]._shown ~= false) then fail(scenario, "coming back to Leather did not draw it") end
end)

-- ------------------------------------------------------------------ 14
-- The cursor lights the brass; unlocked, the prompt can still be dragged.
withTree("look-leather: the cursor lights the brass, and unlocked it can still be dragged", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLeather(look) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	local b = ns.Prompt:GetButton()
	local before = plays(look.hoverAnim)
	b.scripts.OnEnter(b)
	if plays(look.hoverAnim) <= before then fail(scenario, "the cursor on the prompt lit nothing") end
	Mock.advance(1)
	FT.settle()
	if (look.hoverLight._alpha or 0) < 0.4 then fail(scenario, "the brass does not stay lit under the cursor") end
	b.scripts.OnLeave(b)
	Mock.advance(1)
	FT.settle()
	if (look.hoverLight._alpha or 0) > 0.001 then fail(scenario, "the brass stays lit after the cursor leaves") end
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (r.name._text or ""):find("Drag to move", 1, true) then fail(scenario, "unlocked, the first line does not say it can be dragged: " .. tostring(r.name._text)) end
	if not b:IsShown() then fail(scenario, "unlocked, the prompt is not up") end
	p.locked = true
end)

-- ------------------------------------------------------------------ 15
-- The art ships: 32-bit uncompressed TGAs, power-of-two sides, none past 256.
local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { idLength = b[1], mapType = b[2], imageType = b[3], width = b[13] + b[14] * 256,
		height = b[15] + b[16] * 256, bits = b[17] }
end

local function powerOfTwo(n)
	if n < 1 then return false end
	while n % 2 == 0 do n = n / 2 end
	return n == 1
end

withTree("look-leather: its art is 32-bit, a power of two, and every file is named and shipped", ANNA, function(_, scenario)
	local source = slurp(dir .. "/Looks/Leather.lua") or ""
	for _, name in ipairs(FILES) do
		local h = header(dir .. "/Textures/Leather/" .. name .. ".tga")
		if not h then
			fail(scenario, name .. ".tga is not in the package")
		else
			if h.imageType ~= 2 or h.bits ~= 32 then fail(scenario, name .. ".tga is not a 32-bit uncompressed TGA") end
			if not (powerOfTwo(h.width) and powerOfTwo(h.height)) or h.width > 256 or h.height > 256 then
				fail(scenario, ("%s.tga is %dx%d, not a power of two up to 256"):format(name, h.width, h.height))
			end
		end
	end
	-- The body's three pieces are the design's: left and right 128 tall, the
	-- middle square, the stitch's period 16 (the Lua repeats it).
	local function size(name)
		local h = header(dir .. "/Textures/Leather/" .. name .. ".tga")
		return h and h.width, h and h.height
	end
	local w, h = size("Leather_BodyL")
	if not (w == 32 and h == 128) then fail(scenario, "BodyL is not 32x128") end
	w, h = size("Leather_BodyM")
	if not (w == 128 and h == 128) then fail(scenario, "BodyM is not 128x128") end
	w, h = size("Leather_BodyR")
	if not (w == 64 and h == 128) then fail(scenario, "BodyR is not 64x128") end
	w, h = size("Leather_StitchM")
	if not (w == 16 and h == 16) then fail(scenario, "StitchM is not 16x16") end
	for _, want in ipairs({ "local DESIGN, CAP_L, CAP_R, GRAIN = 128, 32, 64, 128", "local PERIOD, INSET, STRIP = 16, 9, 16" }) do
		if not source:find(want, 1, true) then fail(scenario, "the Lua's constants are not the art's: " .. want) end
	end
	-- The directory holds nothing that is not drawn: every file in the generator's
	-- list is the whole of what ships.
	local gen = slurp(dir .. "/tools/make_leather_textures.py") or ""
	local n = 0
	for name in gen:gmatch('save%("(Leather_[%w]+)"') do
		n = n + 1
		local named = false
		for _, f in ipairs(FILES) do if f == name then named = true end end
		if not named and not gen:find('"' .. name .. '"', 1, true) then fail(scenario, name .. " is written and not listed here") end
	end
	local extra = 0
	for name in gen:gmatch('"(Leather_[%w]+)"') do
		local named = false
		for _, f in ipairs(FILES) do if f == name then named = true end end
		if not named then extra = extra + 1 end
	end
	if extra > 0 then fail(scenario, "the generator writes " .. extra .. " file(s) this scenario does not know") end
end)

-- The generator draws the same bytes twice, and the bytes that ship.
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-leather: tools/make_leather_textures.py is deterministic and draws what ships", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-leather-a", tempDir() .. "-leather-b"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out ("'popen' not supported").
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_leather_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	-- CI's test job installs lupa only; the generators need numpy and Pillow,
	-- which every machine that draws the art has, and the full selftest that
	-- judges this check runs there.
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("([%w_]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, ("the generator wrote %d files, not %d: %s"):format(#names, #FILES, outA:sub(1, 200))) end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Leather/" .. file)
		local h = header(a .. "/" .. file)
		if h and (h.width > 256 or h.height > 256 or not powerOfTwo(h.width) or not powerOfTwo(h.height)
			or h.bits ~= 32 or h.imageType ~= 2) then
			fail(scenario, ("%s is %dx%d at %d bits, type %d"):format(file, h.width, h.height, h.bits, h.imageType))
		end
		if not one or not two then
			fail(scenario, file .. " was not written")
		elseif one ~= two then
			fail(scenario, file .. " differs between two runs with the same parameters")
		elseif not ships then
			fail(scenario, file .. " is drawn but does not ship")
		elseif one ~= ships then
			fail(scenario, file .. " does not match the file that ships: run the generator")
		end
		os.remove(a .. "/" .. file)
		os.remove(b .. "/" .. file)
	end
end)
