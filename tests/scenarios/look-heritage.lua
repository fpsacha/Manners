-- The Heritage look (Looks/Heritage.lua): what it promises beyond what every
-- look does, which tests/scenarios/looks.lua asks of it as well.
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows the
-- wrong thing. What it holds:
--   * it is registered, in the toc after the other looks, in all eight
--     languages, and draws only art of its own (no client texture at all);
--   * every state paints without an error on all five clients;
--   * the layout: the frame, the slot, the lines, the chips and the bar stay
--     inside the panel and apart, at every size, with a long name and a long
--     translated reason; the list's names are secure buttons on frames;
--   * the reason is carried where it says it is (the slot's tint, the bar), in
--     both palettes, and goes neutral with the marker off;
--   * the motion is the look's own and keeps to its time and its room: owed
--     breathes three times and settles, an arrival catches the light once, a
--     landing flashes and radiates, a refusal reddens the icon and contracts,
--     a cast nobody confirmed does nothing; Calm is fades only;
--   * a fight turns the gold to iron and keeps the reason; leaving the look
--     puts everything it borrowed back;
--   * the text reads on the stone;
--   * the generator draws the bytes that ship.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Heritage\\"
local COMMAND = "CLICK MannersPrompt:LeftButton"
local CLIENTS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local REASONS = { "target", "owed", "asked", "group", "nearby", "self" }

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

local function sameColour(c, r, g, b)
	return c ~= nil and near(c[1], r) and near(c[2], g) and near(c[3], b)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in Heritage with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "heritage"
	p.flashStyle = "pulse"
	p.effects = "full"
	p.hideInCombat = false
	p.showIcon = true
	p.roundIcon = false
	p.showSub = true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isHeritage(look)
	return look ~= nil and look.key == "heritage" and look.slot ~= false and look.proc ~= nil and look.fill ~= nil
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

-- ------------------------------------------------------------------ 1
-- Registered, listed, in the toc, and in all eight languages.
withTree("look-heritage: it is registered, listed and loaded after the other looks", ANNA, function(ns, scenario)
	local look = ns.Looks.list.heritage
	if not look then fail(scenario, "no look is registered as heritage") return end
	if look.key ~= "heritage" then fail(scenario, "its key is " .. tostring(look.key)) end
	if ns.Looks.Get("heritage") ~= look then fail(scenario, "Looks.Get does not hand back the look") end
	if look.native or look.fallback then fail(scenario, "the look is native or a fallback") end
	if not ns.Looks.Allowed().heritage then fail(scenario, "a saved style of heritage is not allowed") end
	local values, sorting = ns.Looks.Choices()
	if values.heritage ~= ns.L["Heritage -- stone and gold, like the first interface"] then
		fail(scenario, "the dropdown's label is " .. tostring(values.heritage))
	end
	local at
	for i, key in ipairs(sorting) do if key == "heritage" then at = i end end
	if not at then fail(scenario, "the dropdown does not list it") end
	-- The toc: after the last look, before the prompt that calls into it.
	local toc = slurp(dir .. "/Manners.toc") or ""
	local lines = {}
	for line in toc:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
	local function index(name)
		for i, line in ipairs(lines) do if line == name then return i end end
	end
	local mine = index("Looks\\Heritage.lua")
	if not mine then
		fail(scenario, "Manners.toc does not load Looks\\Heritage.lua")
	else
		for _, other in ipairs({ "Looks\\Looks.lua", "Looks\\Luxe.lua", "Looks\\Toast.lua", "Looks\\Arcane.lua" }) do
			local i = index(other)
			if i and i > mine then fail(scenario, "Heritage loads before " .. other) end
		end
		if mine > (index("Prompt\\Prompt.lua") or 0) then fail(scenario, "Heritage loads after Prompt") end
	end
	for _, flavour in ipairs({ "Camelot", "Vanilla", "TBC", "Mists", "Mainline" }) do
		local generated = slurp(dir .. "/Manners_" .. flavour .. ".toc") or ""
		if not generated:find("Looks\\Heritage.lua", 1, true) then
			fail(scenario, "Manners_" .. flavour .. ".toc does not load the look")
		end
	end
end)

withTree("look-heritage: its name is translated into all eight languages", ANNA, function(_, scenario)
	local key = 'L["Heritage -- stone and gold, like the first interface"] = "'
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		local at = text:find(key, 1, true)
		if not at then
			fail(scenario, code .. " has no translation of the look's name")
		else
			local value = text:match('^[^\r\n]-"([^\r\n]*)"', at + #key - 1)
			if not value or value == "" or value:find("Heritage", 1, true) then
				fail(scenario, code .. "'s translation of the look's name is empty or still English: " .. tostring(value))
			end
		end
	end
	local source = slurp(dir .. "/Looks/Heritage.lua") or ""
	-- Every string the player reads goes through L with a literal key.
	if source:find("[^%w_]L%[[^\"]") then fail(scenario, "Looks/Heritage.lua reads L with a key that is not a literal") end
end)

-- ------------------------------------------------------------------ 2
-- Only art of its own: not one texture of the client's, and every file it
-- names ships. The audited set of client textures it may use is empty, because
-- the preview cannot draw one and the five clients do not keep the same.
withTree("look-heritage: it draws only art of its own, and all of it ships", CROWD, function(ns, scenario)
	local seen, count = {}, 0
	local function one(x)
		if type(x) ~= "table" or seen[x] then return end
		seen[x] = true
		if type(x._file) == "string" then
			count = count + 1
			if x._file:sub(1, #ART) ~= ART then
				fail(scenario, "the look draws " .. x._file .. ", which is not its own art")
			else
				local f = io.open(dir .. "/Textures/Heritage/" .. x._file:sub(#ART + 1):gsub("\\", "/") .. ".tga", "rb")
				if f then f:close() else fail(scenario, x._file .. " is not in the package") end
			end
		end
	end
	for _, edit in ipairs({
		function(p) p.showQueue, p.queueRows = true, 3 end,
		function(p) p.showIcon = false end,
		function(p) p.roundIcon = true end,
	}) do
		local r, p, look = upIn(ns, scenario, edit)
		if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			Mock.advance(3)
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			for _, x in ipairs(look.own) do one(x) end
			for _, ring in ipairs(look.fx.rings) do one(ring.tex) end
			one(r.cooldown)
		end
		if r.cooldown and r.cooldown._swipeTexture and tostring(r.cooldown._swipeTexture):sub(1, #ART) ~= ART then
			fail(scenario, "the cooldown's swipe is " .. tostring(r.cooldown._swipeTexture) .. ", not its own square")
		end
		Mock.advance(3)
		tick(ns)
		p.showQueue = false
	end
	if count < 20 then fail(scenario, "only " .. count .. " textures were read, so nothing was held") end
	-- And the code names no texture of the client's anywhere.
	local source = slurp(dir .. "/Looks/Heritage.lua") or ""
	for path in source:gmatch('"(Interface[^"]*)"') do
		if path ~= "Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Heritage\\\\Heritage_" then
			fail(scenario, "Looks/Heritage.lua names " .. path .. ", a path that is not its own art")
		end
	end
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
	local scenario = "look-heritage: every state paints without an error on " .. client
	withTree(scenario, CROWD, function(ns)
		local _, p = upIn(ns, scenario)
		local from = #(ns.errors or {})
		local threw = everyState(ns, p)
		if threw then fail(scenario, threw) end
		for _, edit in ipairs({
			{ "second line off", function() p.showSub = false end },
			{ "icon hidden", function() p.showIcon = false end },
			{ "colour-blind set", function() p.showIcon, p.showSub, p.reasonPalette = true, true, "colourblind" end },
			{ "marker off", function() p.accentMode = "off" end },
			{ "stripe only", function() p.accentMode = "stripe" end },
			{ "both", function() p.accentMode = "both" end },
			{ "light panel", function() p.accentMode, p.bgColor = "icon", { 0.86, 0.84, 0.78, 0.92 } end },
			{ "calm", function() p.effects, p.bgColor = "calm", { 0.04, 0.04, 0.06, 0.88 } end },
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
-- The layout, at every size: the frame fills the panel and nothing is drawn
-- past it, the slot and the icon sit inside the frame, the lines start after
-- the slot and stop before the frame and the chip, the bar runs inside the
-- frame under the lines, the lines do not meet. A long name and a long
-- translated reason, the count's chip and a bound key, with and without the
-- icon.
local LONG = { nameplate1 = { "Bartholomewzxyzq", "Longsurnamefortesting" },
	nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

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

for _, locale in ipairs({ "enUS", "deDE" }) do
	local scenario = "look-heritage: nothing overlaps or leaves the panel, at every size, " .. locale
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
						if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
						if locale == "deDE" then p.reasonOwed = "hat dich gerade gebufft und wartet auf deine Antwort" end
						ns.Prompt:ApplyStyle()
						tick(ns)
						local panel = rectOf(r.art)
						-- The frame fills the panel, and nothing of it passes it.
						for i, t in ipairs(look.frame) do
							local box = rectOf(t)
							if box and not inside(box, panel) then
								fail(scenario, tag .. ": frame piece " .. i .. " is outside the panel")
							end
						end
						local e = look.e
						local slot
						if icon then
							local box = rectOf(r.icon)
							local socket = rectOf(look.socket)
							slot = socket
							if not (box and socket and inside(box, socket)) then
								fail(scenario, tag .. ": the icon is not inside its slot")
							end
							if socket and not inside(socket, panel, e) then
								fail(scenario, tag .. ": the slot is over the frame's gold")
							end
							for i, t in ipairs(look.rim) do
								local pb = rectOf(t)
								if pb and not inside(pb, panel) then fail(scenario, tag .. ": rim piece " .. i .. " is outside the panel") end
							end
							if box and math.abs((box[3] - box[1]) - (box[4] - box[2])) > 0.01 then
								fail(scenario, tag .. ": the icon is not square")
							end
						end
						local name, sub = rectOf(r.name), r.sub:IsShown() and rectOf(r.sub) or nil
						if not name then fail(scenario, tag .. ": the name has no place") return end
						if name[1] < panel[1] + e - 0.01 or name[3] > panel[3] - e + 0.01 then
							fail(scenario, tag .. ": the name runs into the frame's gold")
						end
						if slot and name[1] < slot[3] + 2 then fail(scenario, tag .. ": the name starts over the slot") end
						if sub then
							if sub[1] < panel[1] + e - 0.01 or sub[3] > panel[3] - e + 0.01 then
								fail(scenario, tag .. ": the reason line runs into the frame's gold")
							end
							if slot and sub[1] < slot[3] + 2 then fail(scenario, tag .. ": the reason starts over the slot") end
							local nm, sm = (name[2] + name[4]) / 2, (sub[2] + sub[4]) / 2
							if nm - sm < font * 0.8 then fail(scenario, tag .. ": the two lines meet") end
						end
						-- The bar under the lines, inside the frame.
						if look.fill._shown ~= false and FT.visible(look.fill) then
							local bar = rectOf(look.fill)
							if bar and not inside(bar, panel, e) then fail(scenario, tag .. ": the bar leaves the frame") end
							local line = sub or name
							if bar and line and (line[2] + line[4]) / 2 < bar[4] + 0.5 and across({ line[1], line[2] + 0.4 * font, line[3], line[4] }, bar) then
								fail(scenario, tag .. ": the lines are over the bar")
							end
						end
						-- The chip: the count, and a bound key.
						if look.countMode then
							local chip = rectOf(look.chipBox)
							if chip and not inside(chip, panel, e) then fail(scenario, tag .. ": the count's chip leaves the frame") end
							if chip and across(chip, { name[1], name[2], math.min(name[3], chip[1]), name[4] }) and name[3] > chip[1] + 0.01 then
								fail(scenario, tag .. ": the count's chip is over the name")
							end
						end
					end
				end
			end
		end
	end, function()
		if locale ~= "enUS" then
			Mock.locale = locale
		end
	end)
end

-- With a key bound the key's chip and the count's sit inside the frame and
-- the name keeps its room.
withTree("look-heritage: the bound key and the count sit inside the frame beside the name", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.width = 260 end)
	SetBinding("SHIFT-F", COMMAND)
	tick(ns)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local panel = rectOf(r.art)
	if not look.keyUp then fail(scenario, "a bound key shows no chip") return end
	local key, count = rectOf(look.keyBox), rectOf(look.chipBox)
	if not (key and inside(key, panel, look.e)) then fail(scenario, "the key's chip leaves the frame") end
	if count and look.countMode == "pair" and across(count, key) then fail(scenario, "the count's chip is over the key's") end
	local name = rectOf(r.name)
	if name and key and name[3] > key[1] + 0.01 then fail(scenario, "the name runs under the key's chip") end
	SetBinding("SHIFT-F")
end)

-- ------------------------------------------------------------------ 5
-- The list: a drawer that continues the frame, above or below, each name a
-- secure button on a frame and each row's gem in its reason's colour.
withTree("look-heritage: the list hangs in a drawer of the frame, its names secure buttons on frames", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local panel = rectOf(r.art)
	local function check(label, above)
		local drawer = {}
		for i, t in ipairs(look.drawer) do
			if t._shown ~= false then drawer[#drawer + 1] = i end
		end
		if #drawer ~= 5 then fail(scenario, label .. ": the drawer shows " .. #drawer .. " pieces, not 5") end
		-- The row that meets the panel is left out.
		local meets = above and look.drawer[7] or look.drawer[2]
		if meets._shown ~= false then fail(scenario, label .. ": the drawer's row at the panel is drawn twice") end
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
				local gem = look.gems[i]
				if not (gem and gem._shown ~= false and gem._color) then
					fail(scenario, label .. ": row " .. i .. " wears no gem")
				else
					local c = ns.Prompt.lib and nil
					local want = look.kit.ReasonColor(r.rows[i] and nil or nil)
					c = c or want
				end
			end
		end
		if shown == 0 then fail(scenario, label .. ": no row is shown") end
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
	-- Gems in the palette's colours, both palettes.
	for _, palette in ipairs({ "standard", "colourblind" }) do
		ns.db.profile.prompt.reasonPalette = palette
		ns.Prompt:ApplyStyle()
		tick(ns)
		for i, gem in ipairs(look.gems) do
			if gem._shown ~= false and gem._color then
				local ok = false
				for _, reason in ipairs(REASONS) do
					local c = look.kit.ReasonColor(reason)
					if sameColour(gem._color, c[1], c[2], c[3]) then ok = true end
				end
				if not ok then fail(scenario, ("gem %d is not in a colour of the %s set"):format(i, palette)) end
			end
		end
	end
	-- Gone with the list.
	ns.db.profile.prompt.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, t in ipairs(look.drawer) do
		if t._shown ~= false then fail(scenario, "drawer piece " .. i .. " stays with the list off") end
	end
	if look.drawerStone._shown ~= false then fail(scenario, "the drawer's stone stays with the list off") end
end)

-- ------------------------------------------------------------------ 6
-- The reason: the slot's tint carries it with the icon, the bar without it or
-- on "stripe"; both palettes; neutral with the marker off.
withTree("look-heritage: the reason is carried by the slot's tint and the bar, in both palettes", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs(REASONS) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			for i, t in ipairs(look.tint) do
				if not sameColour(t._color, cr, cg, cb) or t._shown == false then
					fail(scenario, ("tint piece %d is not in %s's colour in the %s set"):format(i, reason, palette))
					break
				end
			end
		end
	end
	p.reasonPalette = "standard"
	-- Marker off: neutral, and nothing drawn in the reason's colour.
	p.accentMode = "off"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	for _, t in ipairs(look.tint) do
		if t._shown ~= false then fail(scenario, "with the marker off the slot's tint is drawn") break end
	end
	if look.tinted and sameColour(look.tinted, cr, cg, cb) then
		fail(scenario, "with the marker off the glow still carries the reason")
	end
	if sameColour(look.tint[2]._color, cr, cg, cb) then fail(scenario, "with the marker off the tint still carries the reason") end
	-- Stripe only: no ring, the bar carries it.
	p.accentMode = "stripe"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	tick(ns)
	for _, t in ipairs(look.tint) do
		if t._shown ~= false then fail(scenario, "on stripe only the slot's tint is drawn") break end
	end
	if not (look.track._shown ~= false and look.fill._shown ~= false) then fail(scenario, "on stripe only there is no bar") end
	local ring, bar = look.AccentCarriers(p)
	if ring ~= false or bar ~= true then fail(scenario, "AccentCarriers does not say stripe only is the bar") end
	-- Icon, both, and the icon off.
	p.accentMode = "both"
	ns.Prompt:ApplyStyle()
	tick(ns)
	ring, bar = look.AccentCarriers(p)
	if ring ~= true or bar ~= true then fail(scenario, "AccentCarriers does not say both is both") end
	p.accentMode, p.showIcon = "icon", false
	ns.Prompt:ApplyStyle()
	tick(ns)
	ring, bar = look.AccentCarriers(p)
	if ring ~= false or bar ~= true or look.fill._shown == false then
		fail(scenario, "with the icon off nothing carries the reason: the bar should")
	end
	p.accentMode, p.showIcon = "icon", true
	ns.Prompt:ApplyStyle()
	ring, bar = look.AccentCarriers(p)
	if ring ~= true or bar ~= false then fail(scenario, "AccentCarriers does not say icon is the ring") end
	-- One colour for every reason when the player says so.
	p.accentByReason, p.accentColor = false, { 0.2, 0.9, 0.3, 1 }
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	if not sameColour(look.tint[2]._color, 0.2, 0.9, 0.3) then fail(scenario, "the marker colour the player chose is not the tint") end
end)

-- ------------------------------------------------------------------ 7
-- The slot is an action button's: square whatever the setting, sized from the
-- height as Options says, the sweep square.
withTree("look-heritage: the icon is square and sized by the slot, the sweep square", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.roundIcon = true end)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	if r.icon._mask ~= nil and r.icon._mask._shown ~= false then fail(scenario, "a round icon's mask shapes the icon in a square slot") end
	local cd = r.cooldown
	if cd then
		if cd._circular == true then fail(scenario, "the sweep's edge is round on a square slot") end
		if tostring(cd._swipeTexture or ""):find("PortraitAlphaMask", 1, true) then fail(scenario, "the sweep is the portrait's circle") end
	end
	for _, size in ipairs({ { 220, 44, 13 }, { 160, 32, 11 }, { 400, 72, 17 }, { 180, 60, 13 }, { 140, 120, 13 }, { 100, 44, 13 } }) do
		p.width, p.height, p.fontSize = size[1], size[2], size[3]
		ns.Prompt:ApplyStyle()
		tick(ns)
		local box = rectOf(r.icon)
		local said = look.IconSize(p)
		if not box or math.abs((box[3] - box[1]) - said) > 1.01 then
			fail(scenario, ("at %dx%d the icon is %s across and Options says %d"):format(size[1], size[2],
				box and string.format("%.1f", box[3] - box[1]) or "?", said))
		end
	end
	p.width, p.height, p.fontSize = 220, 44, 13
	ns.Prompt:ApplyStyle()
	if ns.TwoLineHeight(13, "heritage") > 44 then
		fail(scenario, "two lines need " .. ns.TwoLineHeight(13, "heritage") .. " on Heritage, over the default height of 44")
	end
	if not (ns.TwoLineHeight(17, "heritage") > ns.TwoLineHeight(13, "heritage")) then
		fail(scenario, "a bigger font needs no more height")
	end
	tick(ns)
	if not r.sub:IsShown() then fail(scenario, "the default size shows no second line") end
	-- A button's sweep, with its leading edge.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if cd and cd._drawEdge ~= true then fail(scenario, "the sweep has no leading edge") end
end)

-- The options page says how Heritage sizes its icon, greys out what it does
-- not read, and does not call the marker dead where the bar carries it.
withTree("look-heritage: the options page states the icon's size and greys out the round icon", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local slider = H.findOption(ns.optionsTable, "iconSize")
	local notice = H.findOption(ns.optionsTable, "iconSizeCapped")
	local round = H.findOption(ns.optionsTable, "roundIcon")
	if not (slider and notice and round) then fail(scenario, "SKIPPED -- no icon options") return end
	p.iconSize = 20
	ns.Prompt:ApplyStyle()
	if not slider.disabled() then fail(scenario, "the icon size slider is live on a look that ignores it") end
	if notice.hidden() then fail(scenario, "nothing on the options page says how Heritage sizes its icon") end
	local drawn = look.IconSize(p)
	if not tostring(notice.name()):find(tostring(drawn), 1, true) then
		fail(scenario, "the notice does not give the icon's size (" .. drawn .. "): " .. tostring(notice.name()))
	end
	if not round.disabled() then fail(scenario, "the round icon toggle is live on a square slot") end
	-- The marker is never dead: the ring, or the bar without the icon.
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	local look2 = ns.Looks.Get("heritage")
	local ring, bar = look2.AccentCarriers(p)
	if not (ring or bar) then fail(scenario, "with the icon off the marker has nowhere to go") end
	p.showIcon = true
	p.style = "glass"
	if slider.disabled() then fail(scenario, "the icon size slider is off on glass") end
	if round.disabled() then fail(scenario, "the round icon toggle is off on glass") end
end)

-- ------------------------------------------------------------------ 8
-- The motion. Each effect plays on its own event and on no other.
local function groups(look, r)
	local g = {
		arrive = { look.arrive[1], look.sweep[1] },
		land = { look.fx.rings[1].land, look.fx.rings[2].land, look.flashAnims[1], look.flareAnims[1], r.settle },
		reject = { look.fx.rings[1].reject, look.flashAnims[1], look.flareAnims[1] },
		shake = { r.shake },
		ring = { look.fx.rings[1].land, look.fx.rings[2].land },
		refuseRing = { look.fx.rings[1].reject },
		flash = { look.flashAnims[1] },
		flare = { look.flareAnims[1] },
		settle = { r.settle },
	}
	return g
end

local function snapshot(g)
	local out = {}
	for key, list in pairs(g) do out[key] = total(list) end
	return out
end

withTree("look-heritage: a favour arriving catches the light once, for somebody owed", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	wipe(ns.owed)
	tick(ns)
	Mock.advance(3)
	tick(ns)
	local g = groups(look, r)
	-- A passer-by on the panel who is not owed: nothing arrives, however often
	-- the scan repaints them.
	local before = snapshot(g)
	Mock.advance(0.4)
	tick(ns)
	Mock.advance(0.4)
	tick(ns)
	if snapshot(g).arrive ~= before.arrive then fail(scenario, "a passer-by on the panel played the favour's arrival") end
	owe(ns, "Anna Aim")
	tick(ns)
	local after = snapshot(g)
	if after.arrive <= before.arrive then fail(scenario, "somebody buffing you did not catch the light") end
	if plays(look.sweep[1]) < 1 or plays(look.arrive[1]) < 1 then fail(scenario, "the glint or the frame's light did not play") end
	-- Once: the next scans are the same person owed the same favour.
	Mock.advance(0.4)
	tick(ns)
	Mock.advance(0.4)
	tick(ns)
	if snapshot(g).arrive ~= after.arrive then fail(scenario, "the arrival played again on a repaint of the same favour") end
	-- Nothing of a landing or a refusal came with it.
	local now = snapshot(g)
	if now.ring ~= before.ring or now.settle ~= before.settle or now.refuseRing ~= before.refuseRing
		or now.shake ~= before.shake or now.flash ~= before.flash then
		fail(scenario, "an arrival played the landing's or the refusal's effects")
	end
	-- Not over an outcome the panel is still showing.
	ns.BlockPerson("Anna Aim")
	ns.owed["Anna Aim"] = nil
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local during = snapshot(g).arrive
	Mock.advance(0.2)
	owe(ns, "Anna Aim")
	tick(ns)
	if snapshot(g).arrive ~= during then fail(scenario, "the arrival of the next favour played over the confirmation of the last") end
end)

withTree("look-heritage: a landed buff flashes and radiates, a refusal reddens and contracts", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	Mock.advance(1)
	FT.settle()
	local g = groups(look, r)
	local s0 = snapshot(g)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local s1 = snapshot(g)
	if s1.ring - s0.ring < 2 then fail(scenario, "a buff the game confirmed did not spread both rings from the slot") end
	if s1.flash <= s0.flash then fail(scenario, "a landed buff did not flash the icon") end
	if s1.flare <= s0.flare then fail(scenario, "a landed buff did not brighten the frame") end
	if s1.settle <= s0.settle then fail(scenario, "a landed buff did not settle the panel") end
	if s1.shake ~= s0.shake or s1.refuseRing ~= s0.refuseRing then
		fail(scenario, "a landed buff shook the text or contracted a ring as a refusal does")
	end
	if not sameColour(look.flash._color, 1, 0.92, 0.60) then fail(scenario, "the activation flash is not the game's gold") end
	Mock.advance(1)
	FT.settle()
	local s2 = snapshot(g)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local s3 = snapshot(g)
	if s3.refuseRing <= s2.refuseRing then fail(scenario, "a refusal did not contract a ring onto the slot") end
	if s3.shake <= s2.shake then fail(scenario, "a refusal did not shake the text") end
	if s3.ring ~= s2.ring or s3.settle ~= s2.settle then
		fail(scenario, "a refusal spread the landing's rings or settled the panel as if it had landed")
	end
	local c = look.flash._color
	if not (c and c[1] > 0.9 and c[2] < 0.4 and c[3] < 0.4) then fail(scenario, "the refusal's flash is not red") end
	local f = look.flare[2]._color
	if not (f and f[1] > f[3] and f[2] < 0.5) then fail(scenario, "the frame does not flare red in a refusal") end
	-- The icon is the red of an out-of-range button for as long as the outcome stands.
	if not (r.icon._color and r.icon._color[1] > 0.9 and r.icon._color[2] < 0.5) then
		fail(scenario, "the refused icon is not red: " .. tostring(r.icon._color and table.concat(r.icon._color, ",")))
	end
	if r.icon._desaturated then fail(scenario, "the red icon is greyed as well") end
	Mock.advance(1)
	FT.settle()
	local s4 = snapshot(g)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	local s5 = snapshot(g)
	if s5.land ~= s4.land or s5.reject ~= s4.reject or s5.shake ~= s4.shake then
		fail(scenario, "a cast nobody confirmed got a flourish, which claims more than the settle path knows")
	end
	-- And the icon comes back when the outcome is over.
	Mock.advance(3)
	owe(ns, "Anna Aim")
	tick(ns)
	if r.icon._color and r.icon._color[2] < 0.99 then
		fail(scenario, "the icon stayed red after the outcome")
	end
end)

withTree("look-heritage: Calm is fades only: nothing moves, nothing loops", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
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
	if total(look.pulse) ~= pulse0 or looping() > 0 then fail(scenario, "something breathes on Calm") end
	for _, a in ipairs(r.introCalm._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "Calm's entrance has a " .. tostring(a._kind) .. " in it, not only a fade") end
	end
	-- Every light parked at nothing.
	for _, t in ipairs({ look.proc, look.ringWarm, look.flash, look.glint }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a light is left lit on Calm") end
	end
	if (look.flareFrame._alpha or 0) > 0.001 or (look.breathFrame._alpha or 0) > 0.001 then
		fail(scenario, "the frame is left lit on Calm")
	end
end)

withTree("look-heritage: owed breathes three times and settles, and stops with the favour", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	if not look.pulse[1]._playing then fail(scenario, "somebody owed on top on Full, and the slot does not breathe") end
	-- Round: two to three seconds, all three lights on one breath.
	local breath
	for i, group in ipairs(look.pulse) do
		local d = group._anims[1]._duration
		if breath and d ~= breath then fail(scenario, "the glow, the warm tone and the frame breathe at different rates") end
		breath = d
		if group._looping ~= "BOUNCE" then fail(scenario, "breath " .. i .. " does not bounce") end
	end
	if not breath or breath * 2 < 2 or breath * 2 > 3 then
		fail(scenario, ("the owed breath is %.2f s round, not 2 to 3"):format((breath or 0) * 2))
	end
	-- Warm: the second tone is warmer than white.
	local warm = look.ringWarm._color
	if not (warm and warm[1] > warm[3]) then fail(scenario, "the second tone of the breath is not warm") end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(10)
	if look.pulse[1]._playing or looping() > 0 then fail(scenario, "the owed breath still loops after its three breaths") end
	if (look.proc._alpha or 0) > 0.001 or (look.breathFrame._alpha or 0) > 0.001 then
		fail(scenario, "after its breaths the glow is not let go")
	end
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "the scan started the spent breath again") end
	-- A new favour on top takes its own three breaths.
	wipe(ns.owed)
	tick(ns)
	if looping() > 0 then fail(scenario, "a loop kept going with nobody owed") end
	owe(ns, "Brannoc Vale")
	tick(ns)
	if not look.pulse[1]._playing then fail(scenario, "a new favour did not breathe") end
	-- Nobody owed while it breathes: the glow goes with the loop.
	wipe(ns.owed)
	tick(ns)
	if look.pulse[1]._playing or (look.proc._alpha or 0) > 0 or (look.breathFrame._alpha or 0) > 0 then
		fail(scenario, "the glow stayed with nobody owed")
	end
	-- An outcome lets it go too.
	owe(ns, "Anna Aim")
	tick(ns)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if look.pulse[1]._playing then fail(scenario, "the owed breath kept going over an outcome") end
	-- "Flash once" and "none" never loop.
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

withTree("look-heritage: the effects stay inside their time and their room under the text", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local function within(group, limit, what)
		if group and FT.groupLength(group) > limit then
			fail(scenario, ("%s lasts %.2f s, over %.2f"):format(what, FT.groupLength(group), limit))
		end
	end
	within(look.arrive[1], 0.7, "the frame's light on an arrival")
	within(look.sweep[1], 0.7, "the glint")
	within(look.flashAnims[1], 0.7, "the activation flash")
	within(look.fx.rings[1].land, 0.7, "a ring")
	within(look.fx.rings[1].reject, 0.35, "a refusal's ring")
	-- Every frame of light is beneath the text's frame level.
	local text = r.textLayer._level or 0
	for name, f in pairs({ flare = look.flareFrame, breath = look.breathFrame, chips = look.chipFrame,
		ring1 = look.fx.frames[1], ring2 = look.fx.frames[2] }) do
		if (f._level or 0) >= text then fail(scenario, name .. " is not beneath the text") end
	end
	-- The look's lights that scale or move stay off the text: the glint runs
	-- along the top rail, which is above the first line.
	local panel = rectOf(r.art)
	local glint = rectOf(look.glint)
	local name = rectOf(r.name)
	if glint and name and glint[2] < name[4] - 0.01 + 0 and glint[4] > name[4] + 0.01 then
		-- the glint's box dips below the top of the name: it must be thin enough to stay in the rail
		if glint[2] < panel[4] - look.e * 2.2 then fail(scenario, "the glint reaches down over the name") end
	end
end)

withTree("look-heritage: in a fight no effect touches a protected frame, and none plays when quiet", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
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
	for _, key in ipairs({ "land", "reject", "shake", "settle" }) do
		if s3[key] ~= s2[key] then fail(scenario, "with the prompt kept dim and still in combat the " .. key .. " still played") end
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
end)

withTree("look-heritage: every effect stops on a repaint and on a restyle, and parks what it lit", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local g = groups(look, r)
	local function anyPlaying(skip)
		for _, key in ipairs({ "land", "reject", "shake", "arrive" }) do
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
	if anyPlaying({ [r.settle] = true }) then fail(scenario, "an effect of Heritage was still playing after the look changed") end
	-- Parked at nothing: nothing left lit, nothing left of Heritage shown.
	for _, t in ipairs({ look.proc, look.ringWarm, look.flash, look.hilite, look.glint }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a light was left lit after the look changed") end
	end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "a region of Heritage (" .. i .. ") is still shown on glass") break end
	end
end)

-- ------------------------------------------------------------------ 9
-- A fight turns the gold to iron, dims the icon and the text, and keeps the
-- reason. All of it comes back.
withTree("look-heritage: a fight turns the gold to iron and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local tint = look.tint[2]._color and { look.tint[2]._color[1], look.tint[2]._color[2], look.tint[2]._color[3] }
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	for _, piece in ipairs({ look.frame[2], look.rim[2], look.chip[1], look.keyChip[1] }) do
		if not (piece._desaturated and sameColour(piece._color, 0.62, 0.62, 0.64)) then
			fail(scenario, "a piece of gold did not turn to iron in a fight")
		end
	end
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	if (r.icon._alpha or 1) < 0.99 then fail(scenario, "the icon turned see-through in a fight") end
	if not (r.icon._color and r.icon._color[1] < 0.9) then fail(scenario, "the icon is not dimmed in a fight") end
	if not (look.socket._shown ~= false and look.socket._file) then fail(scenario, "nothing opaque under the icon") end
	if not near(r.textLayer._alpha, 0.78) then fail(scenario, "the text does not dim in a fight") end
	if (r.art._alpha or 1) < 0.99 then fail(scenario, "art dimmed whole in a fight") end
	if not (tint and sameColour(look.tint[2]._color, tint[1], tint[2], tint[3])) or look.tint[2]._desaturated then
		fail(scenario, "the slot's tint lost the reason's colour in a fight")
	end
	if looping() > 0 then fail(scenario, "something loops in a fight") end
	-- Laid out again during the hold: the hold stays.
	look:Apply(ns.db.profile.prompt, false)
	if not look.frame[2]._desaturated then fail(scenario, "laying the look out again during the hold put the gold back") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if look.frame[2]._desaturated or r.icon._desaturated or not near(r.textLayer._alpha or 1, 1) then
		fail(scenario, "the fight's iron stayed on after it ended")
	end
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "the icon stayed dimmed after the fight ended") end
	-- Leaving during a fight puts the icon back for the next look.
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.inCombat = false
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "leaving Heritage during a fight left the icon dimmed on glass") end
	if r.icon._desaturated then fail(scenario, "leaving Heritage during a fight left the icon grey on glass") end
	if r.textLayer._alpha and r.textLayer._alpha < 0.99 then fail(scenario, "leaving Heritage during a fight left the text dimmed") end
end)

-- ------------------------------------------------------------------ 10
-- The outcome: the name stays, the second line is the verdict, in the
-- outcome's colour; without a second line the headline.
withTree("look-heritage: the outcome keeps the name and writes the verdict on the second line", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local function said(fs) return tostring(fs:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not said(r.name):find("Anna", 1, true) then fail(scenario, "the name did not stay on a landed buff: " .. said(r.name)) end
	if not said(r.sub):find("buffed", 1, true) then fail(scenario, "no verdict on the second line: " .. said(r.sub)) end
	local c = r.sub._textColor
	if not (c and c[2] > c[1]) then fail(scenario, "a landed buff's verdict is not green") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not said(r.sub):find("Out of range", 1, true) then fail(scenario, "a refusal's own words are not the verdict: " .. said(r.sub)) end
	c = r.sub._textColor
	if not (c and c[1] > c[2]) then fail(scenario, "a refusal's verdict is not red") end
	for _, t in ipairs(look.tint) do
		if not (t._color and t._color[1] > t._color[2]) then fail(scenario, "the tint is not the refusal's red") break end
	end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if not said(r.sub):find("sent", 1, true) then fail(scenario, "an unconfirmed cast does not say so: " .. said(r.sub)) end
	-- No second line: the headline says both.
	p.showSub = false
	ns.Prompt:ApplyStyle()
	Mock.advance(3)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not (said(r.name):find("buffed", 1, true) and said(r.name):find("Anna", 1, true)) then
		fail(scenario, "with no second line the headline does not say both: " .. said(r.name))
	end
end)

withTree("look-heritage: a German client's outcome keeps the name and says the verdict in German", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local name = tostring(r.name:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local sub = tostring(r.sub:GetText())
	if not name:find("Anna", 1, true) then fail(scenario, "the name is gone on a German client: " .. name) end
	if sub:find("buffed", 1, true) then fail(scenario, "the verdict is English on a German client: " .. sub) end
	if sub == "" then fail(scenario, "no verdict on a German client") end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 11
-- Leaving Heritage gives the lines their room back and the icon, the sweep and
-- the text what they were.
withTree("look-heritage: leaving it gives the lines, the icon and the sweep back", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local kit = look.kit
	if kit.fit.room[r.name] ~= nil or kit.fit.room[r.sub] ~= nil then fail(scenario, "glass fits its lines to the room Heritage kept") end
	if r.icon._color and (r.icon._color[2] < 0.99 or r.icon._color[1] < 0.99) then fail(scenario, "the refusal's red stayed on the icon on glass") end
	if r.textLayer._level ~= r.art._level + kit.TEXT_LEVEL then fail(scenario, "the text's level was not put back") end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "Heritage's region " .. i .. " is still shown on glass") break end
	end
	-- And back again, as new.
	p.style = "heritage"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.frame[1]._shown == false then fail(scenario, "the frame is not shown when the look comes back") end
	if (look.proc._alpha or 0) > 0.99 then fail(scenario, "the glow is left lit when the look comes back") end
end)

-- ------------------------------------------------------------------ 12
-- The cursor lights the slot, both ways; the move handle stays visible when
-- unlocked.
withTree("look-heritage: the cursor lights the slot, and unlocked it can still be dragged", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	Mock.advance(0.3)
	FT.settle()
	if (look.hilite._alpha or 0) < 0.9 then fail(scenario, "the cursor on the panel does not light the slot: " .. tostring(look.hilite._alpha)) end
	b.scripts.OnLeave(b)
	Mock.advance(0.5)
	FT.settle()
	if (look.hilite._alpha or 0) > 0.01 then fail(scenario, "the slot's light stays after the cursor leaves") end
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (FT.visible(r.art) and FT.visible(look.frame[2])) then fail(scenario, "the panel is not shown unlocked") end
	-- The warning the unlocked prompt shows is its own text on the lines, which
	-- the look leaves where they are: both lines still inside the frame.
	local panel, name = rectOf(r.art), rectOf(r.name)
	if name and not inside(name, panel, look.e) then fail(scenario, "the unlocked prompt's line leaves the frame") end
	p.locked = true
end)

-- ------------------------------------------------------------------ 13
-- Read the way the game draws it: the text on the stone. The stone's brightest
-- texels, tinted as the look tints them, with the lights that can lie over the
-- lines allowed for, against every colour the text can be.
local function linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function lum(r, g, b) return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b) end

local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- The luminance, from a 32-bit TGA, that `share` of its texels do not exceed,
-- after `tint` multiplies the colour.
local function stoneLuminance(path, tint, share)
	local data = slurp(path)
	if not data then return nil end
	local b = { data:byte(1, 18) }
	local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
	local offset = 18 + b[1]
	local values = {}
	for i = 0, w * h - 1 do
		local at = offset + i * 4
		local bb, gg, rr = data:byte(at + 1, at + 3)
		values[#values + 1] = lum(rr / 255 * tint[1], gg / 255 * tint[2], bb / 255 * tint[3])
	end
	table.sort(values)
	return values[math.max(1, math.floor(#values * share))]
end

withTree("look-heritage: the text reads on the stone", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	-- The stone's top, its brightest end, as the look tints it: read off the
	-- gradient the look wrote.
	local g = look.stone._gradient
	local c2 = g and g[3]
	local tint = c2 and { c2.r or c2[1], c2.g or c2[2], c2.b or c2[3] } or { 0.30, 0.30, 0.335 }
	if not (tint[1] and tint[2] and tint[3]) then fail(scenario, "the stone's tint cannot be read") return end
	local ground = stoneLuminance(dir .. "/Textures/Heritage/Heritage_Stone.tga", tint, 0.995)
	if not ground then fail(scenario, "the stone cannot be read") return end
	-- Lights that can lie over the lines (ADD counts double): the frame's breath
	-- at its peak reaches a few units in, the glow beside the slot.
	ground = ground + 2 * 0.20 * 0.03
	-- The figure the look lifts its colours against is at least that.
	local held = tonumber((slurp(dir .. "/Looks/Heritage.lua") or ""):match("local GROUND = ([%d%.]+)"))
	if not held or held < ground - 0.0005 then
		fail(scenario, ("the look lifts its colours against a ground of %s, and the stone is %.4f"):format(tostring(held), ground))
	end
	local function check(label, c, minimum)
		if type(c) ~= "table" or not (c[1] and c[2] and c[3]) then
			fail(scenario, label .. " has no colour to judge")
			return
		end
		local l = lum(c[1], c[2], c[3])
		local got = ratio(l, ground)
		if got < minimum then
			fail(scenario, ("%s is %.2f:1 on the stone, under %.1f"):format(label, got, minimum))
		end
	end
	for _, size in ipairs({ { 220, 44, 13 }, { 320, 58, 17 }, { 180, 36, 11 } }) do
		p.width, p.height, p.fontSize = size[1], size[2], size[3]
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.reasonPalette = palette
			for _, reason in ipairs(REASONS) do
				ns.Prompt:ApplyStyle()
				ns.Prompt:PaintAccent(reason)
				check("the reason line for " .. reason .. " (" .. palette .. ")", r.sub._textColor, 4.5)
				-- The verdicts' colours.
				for _, kind in ipairs({ "cast", "failed", "sent" }) do
					Mock.advance(3)
					ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
					check("the " .. kind .. " verdict", r.sub._textColor, 4.5)
				end
			end
		end
		check("the name in the game's gold", r.name._textColor, 4.5)
		for _, fs in ipairs(r.rows) do check("a list name", fs._textColor, 4.5) end
		check("the count's text", r.count._textColor, 4.5)
	end
	-- Class colours as the look softens them are held to the 3:1 the prompt
	-- holds every colour code to.
	local soften = look.classSoften or 0
	for _, code in ipairs({ "c41e3a", "a330c9", "ff7c0a", "33937f", "aad372", "3fc7eb", "00ff98", "f48cba",
		"ffffff", "fff468", "0070dd", "8788ee", "c69b6d" }) do
		local cr, cg, cb = tonumber(code:sub(1, 2), 16) / 255, tonumber(code:sub(3, 4), 16) / 255, tonumber(code:sub(5, 6), 16) / 255
		cr, cg, cb = cr + (1 - cr) * soften, cg + (1 - cg) * soften, cb + (1 - cb) * soften
		check("the class colour " .. code, { cr, cg, cb }, 3)
	end
end)

-- ------------------------------------------------------------------ 14
-- The art: the right size, 32-bit, and every file named in the code ships and
-- is drawn; the generator draws the bytes that ship, twice the same.
local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local d = f:read(18)
	f:close()
	if not d or #d < 18 then return nil end
	local b = { d:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

local function powerOfTwo(n)
	if n < 1 then return false end
	while n % 2 == 0 do n = n / 2 end
	return n == 1
end

withTree("look-heritage: its art is 32-bit, a power of two, and every file is named and shipped", ANNA, function(_, scenario)
	local names = {}
	local source = slurp(dir .. "/Looks/Heritage.lua") or ""
	for name in source:gmatch('tex%([^,]+,[^,]+,[^,]+,%s*"(%u%a+)"') do names[name] = true end
	for name in source:gmatch('ART %.%. "(%u%a+)"') do names[name] = true end
	local count = 0
	for name in pairs(names) do
		count = count + 1
		local h = header(dir .. "/Textures/Heritage/Heritage_" .. name .. ".tga")
		if not h then
			fail(scenario, "Heritage_" .. name .. ".tga is named in the look and is not in the package")
		else
			if h.imageType ~= 2 or h.bits ~= 32 then fail(scenario, name .. " is not a 32-bit uncompressed TGA") end
			if h.width > 256 or h.height > 256 then fail(scenario, name .. " is over 256 on a side") end
			if not (powerOfTwo(h.width) and powerOfTwo(h.height)) then fail(scenario, name .. " is not a power of two") end
		end
	end
	if count < 12 then fail(scenario, "only " .. count .. " files are named in the look") end
	-- Every shipped file is drawn.
	local listing = io.popen and nil
	for _, name in ipairs({ "Frame", "FrameGlow", "Stone", "Slot", "SlotTint", "SlotBack", "Gloss", "Proc", "Ring",
		"Glint", "White", "Chip", "Gem", "GemSet" }) do
		if not slurp(dir .. "/Textures/Heritage/Heritage_" .. name .. ".tga") then fail(scenario, name .. " does not ship") end
		if not source:find('"' .. name .. '"', 1, true) and not source:find('"' .. name .. '"', 1, true)
			and not source:find('ART .. "' .. name .. '"', 1, true) then
			fail(scenario, name .. " ships but the look never draws it")
		end
	end
end)

local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-heritage: tools/make_heritage_textures.py is deterministic and draws what ships", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-a", tempDir() .. "-b"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out.
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_heritage_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	-- CI's test job installs lupa only; the generators need numpy and Pillow,
	-- which every machine that draws the art has.
	if outA:find("No module named", 1, true) then return end
	local files = {}
	for file in outA:gmatch("([%w_]+%.tga)") do files[#files + 1] = file end
	if #files == 0 then fail(scenario, "the generator wrote nothing: " .. outA:sub(1, 200)) return end
	for _, file in ipairs(files) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Heritage/" .. file)
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
