-- The Heritage look (Looks/Heritage.lua): what it promises beyond what every
-- look does, which tests/scenarios/looks.lua asks of it as well.
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows the
-- wrong thing. What it holds:
--   * it is registered, in the toc after the other looks, in all eight
--     languages, and draws only art of its own (no client texture at all);
--   * every state paints without an error on all five clients;
--   * the frame is fitted into the prompt at every size: the portrait is round,
--     as tall as the frame and taller than the body beside it, and everything the
--     look draws stays inside the prompt; the text stands on the banner and the
--     bar, apart from the ring, the wing and the border; the list's names are
--     secure buttons on frames;
--   * the banner carries the reason (both palettes, neutral with the marker off),
--     the bar the favour's time, and the global cooldown drains across it;
--   * the motion is the look's own and keeps to its time and its room: owed
--     breathes three times and settles, an arrival flashes the portrait once, a
--     landing flashes and radiates, a refusal reddens the portrait and the banner
--     and shakes it, a cast nobody confirmed does nothing; Calm is fades only;
--   * a fight puts the red glow on the frame and keeps the reason; leaving the
--     look puts everything it borrowed back;
--   * the text reads on the banner and on the bar;
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
	return look ~= nil and look.key == "heritage" and look.orn ~= nil and look.banner ~= nil and look.fill ~= nil
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

-- The colours of a gradient the look wrote: bottom, top.
local function ends(t)
	local g = t._gradient
	if not g then return nil end
	local function rgb(c) return { c.r or c[1], c.g or c[2], c.b or c[3] } end
	return rgb(g[2]), rgb(g[3])
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
	if look.order ~= 5 then fail(scenario, "its place in the dropdown is " .. tostring(look.order) .. ", not 5") end
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
			one(look.mask)
		end
		if r.cooldown and r.cooldown._swipeTexture and tostring(r.cooldown._swipeTexture):sub(1, #ART) ~= ART then
			fail(scenario, "the cooldown's swipe is " .. tostring(r.cooldown._swipeTexture) .. ", not its own round")
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
-- The layout, at every size: the frame is fitted into the prompt, the portrait
-- is round, as tall as the frame and taller than the body, the banner and the bar
-- are inside the body's border, and the lines stand on them apart from the
-- ring, the wing and the border. A long name and a long translated reason, the
-- count and a bound key, with and without the icon.
local LONG = { nameplate1 = { "Bartholomewzxyzq", "Longsurnamefortesting" },
	nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

-- Every texture the look keeps on the prompt itself, which must lie inside it:
-- not the list's tray and pips (outside by design) nor the rings' frames (which
-- are scaled to fit when they play).
local function mainTextures(look)
	local out = {}
	local skip = {}
	for _, set in ipairs({ look.tray, look.trayBody }) do
		for _, t in ipairs(set) do skip[t] = true end
	end
	for _, set in ipairs({ look.pips, look.pipRings }) do
		for _, t in ipairs(set) do skip[t] = true end
	end
	for i, x in ipairs(look.own) do
		if x._kind == "Texture" and not skip[x] and FT.visible(x) then out[#out + 1] = { i, x } end
	end
	return out
end

for _, locale in ipairs({ "enUS", "deDE" }) do
	local scenario = "look-heritage: nothing overlaps or leaves the prompt, at every size, " .. locale
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
						local g = look.g
						-- Fitted into the prompt: nothing the look draws is outside it.
						for _, item in ipairs(mainTextures(look)) do
							local box = rectOf(item[2])
							if box and not inside(box, panel) then
								fail(scenario, ("%s: a part of the frame (%d, %s) is outside the prompt"):format(
									tag, item[1], tostring(item[2]._file):gsub("^.*Heritage_", "")))
							end
						end
						if g.u > height + 0.01 or g.u > 0.38 * width + 0.01 then
							fail(scenario, tag .. ": the frame is taller than the prompt or than its share of the width")
						end
						local body = { panel[1] + g.bx0, panel[4] - g.bodyBottom, panel[1] + g.bx1, panel[4] - g.bodyTop }
						-- The plate under the body is whole: its middle meets its corners.
						local c1, c9, c8 = rectOf(look.plate[1]), rectOf(look.plate[9]), rectOf(look.plate[8])
						if c1 and c9 and c8 and not (c9[1] <= c1[3] + 0.01 and c9[4] >= c1[2] - 0.01
							and c9[3] >= c8[1] - 0.01 and c9[2] <= c8[4] + 0.01) then
							fail(scenario, tag .. ": the plate's middle does not meet its corners")
						end
						local banner, bar = rectOf(look.banner), rectOf(look.track)
						if not (banner and bar and inside(banner, { body[1], body[2] + g.ib - 0.5, body[3], body[4] - g.ib + 0.5 })) then
							fail(scenario, tag .. ": the banner is not inside the body's border")
						end
						if bar and banner and bar[4] > banner[2] + 0.01 then fail(scenario, tag .. ": the bar is over the banner") end
						if icon then
							local box = rectOf(r.icon)
							local orn = rectOf(look.orn)
							if not (box and orn and inside(box, orn)) then
								fail(scenario, tag .. ": the icon is not inside the ring's art")
							end
							if box and math.abs((box[3] - box[1]) - (box[4] - box[2])) > 0.01 then
								fail(scenario, tag .. ": the portrait is not round (its box is not square)")
							end
							-- Round: cut by the portrait's mask, whose box is the icon's.
							if not (r.icon._mask == look.mask and look.mask._shown ~= false) then
								fail(scenario, tag .. ": the icon is not cut round by the mask")
							end
							local mask = rectOf(look.mask)
							if box and mask and not (near(mask[1], box[1], 0.02) and near(mask[3], box[3], 0.02)
								and near(mask[2], box[2], 0.02) and near(mask[4], box[4], 0.02)) then
								fail(scenario, tag .. ": the mask is not the icon's size")
							end
							-- As tall as the frame, and taller than the body beside it.
							if orn and math.abs((orn[4] - orn[2]) - g.u) > 0.02 then
								fail(scenario, tag .. ": the portrait is not as tall as the frame")
							end
							if not (2 * g.ro > g.bodyH + 0.5) then
								fail(scenario, ("%s: the ring (%.1f) is not taller than the body (%.1f)"):format(tag, 2 * g.ro, g.bodyH))
							end
							if orn and (orn[2] < panel[2] - 0.01 or orn[4] > panel[4] + 0.01) then
								fail(scenario, tag .. ": the portrait's art leaves the prompt")
							end
						else
							if r.icon:IsShown() then fail(scenario, tag .. ": the icon is shown with the icon off") end
							if look.orn._shown ~= false and FT.visible(look.orn) then fail(scenario, tag .. ": the ring is drawn with the icon off") end
						end
						local name, sub = rectOf(r.name), r.sub:IsShown() and rectOf(r.sub) or nil
						if not name then fail(scenario, tag .. ": the name has no place") return end
						-- The lines stand on the banner and the bar: clear of the ring, the
						-- wing (left of the ring) and the border.
						local clear = icon and (panel[1] + g.cx + g.ro + 1) or (panel[1] + g.bx0 + g.ib)
						if name[1] < clear - 0.01 then fail(scenario, tag .. ": the name starts over the ring") end
						if name[3] > panel[1] + g.bannerX1 + 0.01 then fail(scenario, tag .. ": the name runs into the border") end
						if sub then
							if sub[1] < clear - 0.01 then fail(scenario, tag .. ": the reason starts over the ring") end
							if sub[3] > panel[1] + g.bannerX1 + 0.01 then fail(scenario, tag .. ": the reason runs into the border") end
							local nm, sm = (name[2] + name[4]) / 2, (sub[2] + sub[4]) / 2
							if nm - sm < font * 0.8 then fail(scenario, tag .. ": the two lines meet") end
							-- Each on its own row, in the middle of it: the name on the
							-- banner, the reason on the bar, and each the height of its row
							-- (two lines are only shown where the rows hold them).
							if banner and math.abs(nm - (banner[2] + banner[4]) / 2) > 0.25 * (banner[4] - banner[2]) + 1.5 then
								fail(scenario, tag .. ": the name is not on the banner")
							end
							if bar and math.abs(sm - (bar[2] + bar[4]) / 2) > 0.25 * (bar[4] - bar[2]) + 1.5 then
								fail(scenario, tag .. ": the reason is not on the bar")
							end
							if banner and name[4] - name[2] > banner[4] - banner[2] + 0.5 then
								fail(scenario, tag .. ": the name is taller than the banner it stands on")
							end
							if bar and sub[4] - sub[2] > bar[4] - bar[2] + 0.5 then
								fail(scenario, tag .. ": the reason is taller than the bar it stands on")
							end
						end
						if look.countMode then
							local box = look.countMode == "badge" and look.badgeBox or look.chipBox
							local chip = rectOf(box)
							if chip and not inside(chip, panel) then fail(scenario, tag .. ": the count leaves the prompt") end
							if look.countMode ~= "badge" and chip and across(chip, name) and name[3] > chip[1] + 0.01 then
								fail(scenario, tag .. ": the count's tab is over the name")
							end
							if look.countMode == "badge" and chip and (across(chip, name) or (sub and across(chip, sub))) then
								fail(scenario, tag .. ": the badge is over the lines")
							end
							-- The count is as tall as the badge holds.
							local count = rectOf(r.count)
							if look.countMode == "badge" and chip and count and count[4] - count[2] > chip[4] - chip[2] + 0.01 then
								fail(scenario, tag .. ": the count is taller than the badge it stands on")
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

-- With a key bound the key's tab sits inside the banner and the name keeps its
-- room; with the portrait off the count's tab sits beside it.
withTree("look-heritage: the bound key and the count sit inside the banner beside the name", CROWD, function(ns, scenario)
	for _, icon in ipairs({ true, false }) do
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.showIcon = 260, icon end)
		SetBinding("SHIFT-F", COMMAND)
		tick(ns)
		if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
		local panel = rectOf(r.art)
		if not look.keyUp then fail(scenario, "a bound key shows no tab") return end
		local key = rectOf(look.keyBox)
		local banner = rectOf(look.banner)
		if not (key and banner and inside(key, banner)) then fail(scenario, "the key's tab leaves the banner") end
		local name = rectOf(r.name)
		if name and key and name[3] > key[1] + 0.01 then fail(scenario, "the name runs under the key's tab") end
		if not icon then
			local count = rectOf(look.chipBox)
			if look.countMode ~= "pair" then fail(scenario, "with the portrait off the count and the key are not a pair") end
			if count and key and across(count, key) then fail(scenario, "the count's tab is over the key's") end
			if count and banner and not inside(count, banner) then fail(scenario, "the count's tab leaves the banner") end
		else
			if look.countMode ~= "badge" then fail(scenario, "with the portrait on the count is not on the badge") end
			-- The badge sits on the ring: its middle is on the ring's band.
			local badge, orn = rectOf(look.badgeBox), rectOf(look.orn)
			if badge and look.g then
				local bx, by = (badge[1] + badge[3]) / 2 - panel[1], panel[4] - (badge[2] + badge[4]) / 2
				local d = math.sqrt((bx - look.g.cx) ^ 2 + (by - look.g.cy) ^ 2)
				if d < look.g.ri or d > look.g.ro then fail(scenario, "the badge is not on the ring's band") end
			end
			if orn and badge and not inside(badge, panel) then fail(scenario, "the badge leaves the prompt") end
		end
		SetBinding("SHIFT-F")
	end
end)

-- ------------------------------------------------------------------ 5
-- The list: a tray of party frames under the frame or over it, each name a
-- secure button on a frame and each row's pip in its reason's colour.
withTree("look-heritage: the list hangs in a tray, its names secure buttons on frames", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local panel = rectOf(r.art)
	local function check(label, above)
		local up = 0
		for _, t in ipairs(look.tray) do if t._shown ~= false then up = up + 1 end end
		for _, t in ipairs(look.trayBody) do if t._shown ~= false then up = up + 1 end end
		if up ~= 17 then fail(scenario, label .. ": the tray shows " .. up .. " pieces, not 17") end
		local tl, br = rectOf(look.tray[1]), rectOf(look.tray[8])
		local tray = tl and br and { tl[1], br[2], br[3], tl[4] }
		if tray then
			if above and not (tray[2] >= panel[4] - 0.01) then fail(scenario, label .. ": the tray is not over the panel") end
			if not above and not (tray[4] <= panel[2] + 0.01) then fail(scenario, label .. ": the tray is not under the panel") end
		end
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
				local row_box = rectOf(row)
				if row_box and tray and not inside(row_box, tray) then
					fail(scenario, label .. ": row " .. i .. "'s text leaves the tray")
				end
				local pip = look.pips[i]
				if not (pip and pip._shown ~= false and pip._color and look.pipRings[i]._shown ~= false) then
					fail(scenario, label .. ": row " .. i .. " wears no pip")
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
	-- Pips in the palette's colours, both palettes.
	for _, palette in ipairs({ "standard", "colourblind" }) do
		ns.db.profile.prompt.reasonPalette = palette
		ns.Prompt:ApplyStyle()
		tick(ns)
		for i, pip in ipairs(look.pips) do
			if pip._shown ~= false and pip._color then
				local ok = false
				for _, reason in ipairs(REASONS) do
					local c = look.kit.ReasonColor(reason)
					if sameColour(pip._color, c[1], c[2], c[3]) then ok = true end
				end
				if not ok then fail(scenario, ("pip %d is not in a colour of the %s set"):format(i, palette)) end
			end
		end
	end
	-- Gone with the list.
	ns.db.profile.prompt.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, t in ipairs(look.tray) do
		if t._shown ~= false then fail(scenario, "tray piece " .. i .. " stays with the list off") end
	end
	for i, t in ipairs(look.trayBody) do
		if t._shown ~= false then fail(scenario, "tray border piece " .. i .. " stays with the list off") end
	end
end)

-- ------------------------------------------------------------------ 6
-- The reason: the banner carries it, in both palettes, and goes neutral with the
-- marker off; the ring on the portrait with the icon and "icon" or "both".
withTree("look-heritage: the reason is carried by the banner and the ring, in both palettes", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	-- The banner is the reason's colour taken towards black by one factor: the
	-- same hue, whatever the colour.
	local function sameHue(top, r1, g1, b1)
		if not top then return false end
		local k = math.max(top[1], top[2], top[3]) / math.max(r1, g1, b1)
		return near(top[1], r1 * k, 0.03) and near(top[2], g1 * k, 0.03) and near(top[3], b1 * k, 0.03)
	end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs(REASONS) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			local _, top = ends(look.banner)
			if not sameHue(top, cr, cg, cb) then
				fail(scenario, ("the banner is not in %s's colour in the %s set"):format(reason, palette))
			end
			if not sameColour(look.rim._color, cr, cg, cb) or look.rim._shown == false then
				fail(scenario, ("the portrait's ring is not in %s's colour in the %s set"):format(reason, palette))
			end
		end
	end
	-- Two reasons are two banners.
	p.reasonPalette = "standard"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	local _, owedTop = ends(look.banner)
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	local _, groupTop = ends(look.banner)
	if owedTop and groupTop and near(owedTop[1], groupTop[1], 0.02) and near(owedTop[3], groupTop[3], 0.02) then
		fail(scenario, "the banner is the same for owed and for a group member")
	end
	-- Marker off: neutral, and nothing drawn in the reason's colour.
	p.accentMode = "off"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if look.tinted and sameColour(look.tinted, cr, cg, cb) then
		fail(scenario, "with the marker off the banner still carries the reason")
	end
	local _, neutralTop = ends(look.banner)
	if neutralTop and sameHue(neutralTop, cr, cg, cb) and not sameHue(neutralTop, 0.66, 0.58, 0.36) then
		fail(scenario, "with the marker off the banner is still the reason's colour")
	end
	if look.rim._shown ~= false then fail(scenario, "with the marker off the ring on the portrait is drawn") end
	local ring, banner = look.AccentCarriers(p)
	if ring ~= false or banner ~= false then fail(scenario, "AccentCarriers says the marker off carries something") end
	-- Stripe only: the banner, no ring.
	p.accentMode = "stripe"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	tick(ns)
	if look.rim._shown ~= false then fail(scenario, "on stripe only the ring on the portrait is drawn") end
	ring, banner = look.AccentCarriers(p)
	if ring ~= false or banner ~= true then fail(scenario, "AccentCarriers does not say stripe only is the banner") end
	-- Icon, both, and the icon off.
	p.accentMode = "both"
	ns.Prompt:ApplyStyle()
	tick(ns)
	ring, banner = look.AccentCarriers(p)
	if ring ~= true or banner ~= true then fail(scenario, "AccentCarriers does not say both is both") end
	if look.rim._shown == false then fail(scenario, "on both the ring on the portrait is not drawn") end
	p.accentMode, p.showIcon = "icon", false
	ns.Prompt:ApplyStyle()
	tick(ns)
	ring, banner = look.AccentCarriers(p)
	if ring ~= false or banner ~= true then fail(scenario, "with the icon off the banner should carry the reason alone") end
	if look.rim._shown ~= false then fail(scenario, "the ring is drawn with the icon off") end
	p.accentMode, p.showIcon = "icon", true
	ns.Prompt:ApplyStyle()
	ring, banner = look.AccentCarriers(p)
	if ring ~= true or banner ~= true then fail(scenario, "AccentCarriers does not say icon is the ring and the banner") end
	-- One colour for every reason when the player says so.
	p.accentByReason, p.accentColor = false, { 0.2, 0.9, 0.3, 1 }
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	_, groupTop = ends(look.banner)
	if not sameHue(groupTop, 0.2, 0.9, 0.3) then fail(scenario, "the marker colour the player chose is not the banner's") end
	if not sameColour(look.rim._color, 0.2, 0.9, 0.3) then fail(scenario, "the marker colour the player chose is not the ring's") end
end)

-- ------------------------------------------------------------------ 7
-- The bar is the favour's time: its fill is as long as the time left, drained
-- from the right, green while there is plenty and red when there is little; a bar
-- with no clock stands full in blue. The cooldown drains a blue bar across it.
withTree("look-heritage: the bar tracks the favour's time and the global cooldown", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local len = look.g.barLen
	local function width() local b = rectOf(look.fill) return b and (b[3] - b[1]) end
	local function fillTop() local _, top = ends(look.fill) return top end
	local window = ns.db.profile.timing.reciprocateWindow or 300
	local function setLeft(frac)
		ns.owed["Anna Aim"] = { expires = GetTime() + window * frac, at = GetTime() - window * (1 - frac), class = "PRIEST" }
		tick(ns)
	end
	-- Full: the whole bar, and green.
	setLeft(1)
	if not near(width(), len, 0.6) then fail(scenario, ("a favour with all its time left fills %s of %.1f"):format(tostring(width()), len)) end
	local top = fillTop()
	if not (top and top[2] > top[1] and top[2] > top[3]) then fail(scenario, "a favour with plenty of time is not green") end
	-- Half, a quarter: shorter, from the left; yellow and then red.
	setLeft(0.5)
	if not near(width(), len * 0.5, 0.06 * len + 0.6) then fail(scenario, ("half the time left fills %s of %.1f"):format(tostring(width()), len)) end
	local fillLeft = rectOf(look.fill)[1]
	local trackLeft = rectOf(look.track)[1]
	if math.abs(fillLeft - trackLeft - 0.7) > 0.2 then fail(scenario, "the fill is not drained from the right: it does not start at the bar's left") end
	setLeft(0.30)
	local before = width()
	top = fillTop()
	if not (top and top[1] > top[3] and top[2] > top[3]) then fail(scenario, "a favour with a third of its time left is not yellow") end
	setLeft(0.05)
	local after = width()
	if not (after < before - 0.01) then fail(scenario, "a nearly spent favour does not have a shorter bar") end
	top = fillTop()
	if not (top and top[1] > top[2] * 2 and top[1] > top[3] * 2) then fail(scenario, "a nearly spent favour is not red") end
	-- Time passing shortens it, a scan at a time.
	setLeft(0.8)
	local w1 = width()
	Mock.advance(window * 0.3)
	tick(ns)
	if not (width() < w1 - 0.5) then fail(scenario, "the bar does not shorten as the favour's time runs out") end
	-- No clock: full, and blue, for a passer-by.
	wipe(ns.owed)
	tick(ns)
	if not near(width(), len, 0.6) then fail(scenario, "a bar with no clock to show is not full") end
	top = fillTop()
	if not (top and top[3] > top[1] and top[3] > top[2]) then fail(scenario, "a bar with no clock to show is not the blue of a mana bar") end
	-- The global cooldown: a blue bar covers it from the left and drains.
	owe(ns, "Anna Aim")
	tick(ns)
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.3, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if not look.coolRun._playing then fail(scenario, "the global cooldown does not drain a bar across the favour's") return end
	if (look.coolTex._alpha or 0) < 0.5 then fail(scenario, "the cooldown's bar is not drawn while it runs") end
	local slide = look.coolSlide
	local left = 1.2
	if not near(slide._duration, left, 0.1) then
		fail(scenario, ("the bar drains over %s s, not the %.1f s the cooldown has left"):format(tostring(slide._duration), left))
	end
	local offset = slide._offset and slide._offset[1]
	if not (offset and near(offset, -(1 - 0.2) * len, 0.05 * len)) then
		fail(scenario, "the bar slides " .. tostring(offset) .. " from where the cooldown has got to, not to the left end")
	end
	if not look.barBox:DoesClipChildren() then fail(scenario, "the draining bar is not cut at the bar's edges") end
	-- It goes with the cooldown.
	Mock.advance(3)
	FT.settle()
	if (look.coolTex._alpha or 0) > 0.01 then fail(scenario, "the cooldown's bar stays after the cooldown") end
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.1, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	Mock.spellCooldowns = nil
	look:CoolStop()
	if look.coolRun._playing or (look.coolTex._alpha or 0) > 0.01 then fail(scenario, "a cooldown cleared leaves the bar draining") end
end)

-- ------------------------------------------------------------------ 8
-- The portrait is round whatever "Round the icon off" says, and sized from the
-- frame's height as Options says; the sweep round.
withTree("look-heritage: the icon is round and sized by the portrait, the sweep round", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.roundIcon = false end)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local cd = r.cooldown
	if cd then
		if cd._circular ~= true then fail(scenario, "the sweep's edge is not round on a round portrait") end
		if tostring(cd._swipeTexture or "") ~= ART .. "Heritage_Mask" then fail(scenario, "the sweep is not cut by the portrait's mask: " .. tostring(cd._swipeTexture)) end
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
	-- A round button's sweep, with its leading edge.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if cd and cd._drawEdge ~= true then fail(scenario, "the sweep has no leading edge") end
end)

-- The options page says how Heritage sizes its icon, greys out what it does
-- not read, and does not call the marker dead where the banner carries it.
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
	if not round.disabled() then fail(scenario, "the round icon toggle is live on a portrait that is always round") end
	-- The marker is never dead: the banner carries it, with the icon off too.
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	local look2 = ns.Looks.Get("heritage")
	local ring, banner = look2.AccentCarriers(p)
	if not (ring or banner) then fail(scenario, "with the icon off the marker has nowhere to go") end
	p.showIcon = true
	p.style = "glass"
	if slider.disabled() then fail(scenario, "the icon size slider is off on glass") end
	if round.disabled() then fail(scenario, "the round icon toggle is off on glass") end
end)

-- ------------------------------------------------------------------ 9
-- The motion. Each effect plays on its own event and on no other.
local function groups(look, r)
	return {
		arrive = { look.arrive[1], look.sweep[1] },
		land = { look.fx.rings[1].land, look.fx.rings[2].land, look.flashAnims[1], look.flareAnims[1],
			look.landAnims[1], look.landAnims[2], r.settle },
		reject = { look.fx.rings[1].reject, look.flashAnims[1], look.flareAnims[1], look.refuseAnims[1] },
		shake = { r.shake },
		ring = { look.fx.rings[1].land, look.fx.rings[2].land },
		refuseRing = { look.fx.rings[1].reject },
		flash = { look.flashAnims[1] },
		flare = { look.flareAnims[1] },
		settle = { r.settle },
		bar = { look.landAnims[1], look.landAnims[2] },
		banner = { look.refuseAnims[1], look.shakes[1], look.shakes[2], look.shakes[3] },
	}
end

local function snapshot(g)
	local out = {}
	for key, list in pairs(g) do out[key] = total(list) end
	return out
end

withTree("look-heritage: a favour arriving flashes the portrait once, for somebody owed", ANNA, function(ns, scenario)
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
	if after.arrive <= before.arrive then fail(scenario, "somebody buffing you did not flash the portrait") end
	if plays(look.sweep[1]) < 1 or plays(look.arrive[1]) < 1 then fail(scenario, "the glint or the portrait's flash did not play") end
	-- Once: the next scans are the same person owed the same favour.
	Mock.advance(0.4)
	tick(ns)
	Mock.advance(0.4)
	tick(ns)
	if snapshot(g).arrive ~= after.arrive then fail(scenario, "the arrival played again on a repaint of the same favour") end
	-- Nothing of a landing or a refusal came with it.
	local now = snapshot(g)
	if now.ring ~= before.ring or now.settle ~= before.settle or now.refuseRing ~= before.refuseRing
		or now.shake ~= before.shake or now.flare ~= before.flare or now.bar ~= before.bar or now.banner ~= before.banner then
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

withTree("look-heritage: a landed buff flashes and radiates, a refusal reddens and shakes", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	Mock.advance(1)
	FT.settle()
	local g = groups(look, r)
	local s0 = snapshot(g)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local s1 = snapshot(g)
	if s1.ring - s0.ring < 2 then fail(scenario, "a buff the game confirmed did not spread both rings from the portrait") end
	if s1.flash <= s0.flash then fail(scenario, "a landed buff did not flash the portrait") end
	if s1.flare <= s0.flare then fail(scenario, "a landed buff did not brighten the border") end
	if s1.bar - s0.bar < 2 then fail(scenario, "a landed buff did not run the glint and the green along the bar") end
	if s1.settle <= s0.settle then fail(scenario, "a landed buff did not settle the panel") end
	if s1.shake ~= s0.shake or s1.refuseRing ~= s0.refuseRing or s1.banner ~= s0.banner then
		fail(scenario, "a landed buff shook the text, flashed the banner red or contracted a ring as a refusal does")
	end
	if not sameColour(look.flash._color, 1, 0.92, 0.60) then fail(scenario, "the flash on the portrait is not gold") end
	Mock.advance(1)
	FT.settle()
	local s2 = snapshot(g)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local s3 = snapshot(g)
	if s3.refuseRing <= s2.refuseRing then fail(scenario, "a refusal did not contract a ring onto the portrait") end
	if s3.shake <= s2.shake then fail(scenario, "a refusal did not shake the text") end
	if s3.banner - s2.banner < 4 then fail(scenario, "a refusal did not flash the banner red and shake it") end
	if s3.ring ~= s2.ring or s3.settle ~= s2.settle or s3.bar ~= s2.bar then
		fail(scenario, "a refusal spread the landing's rings, ran the bar or settled the panel as if it had landed")
	end
	local c = look.flash._color
	if not (c and c[1] > 0.9 and c[2] < 0.4 and c[3] < 0.4) then fail(scenario, "the refusal's flash on the portrait is not red") end
	local b = look.bannerFlash._color
	if not (b and b[1] > 0.9 and b[2] < 0.4 and b[3] < 0.4) then fail(scenario, "the banner does not flash red in a refusal") end
	local f = look.flare[2]._color
	if not (f and f[1] > f[3] and f[2] < 0.5) then fail(scenario, "the border does not flare red in a refusal") end
	-- The banner's shake is small and sums to nothing.
	for _, shake in ipairs(look.shakes) do
		local sum, reach, pos = 0, 0, 0
		for _, a in ipairs(shake._anims) do
			local dx = a._offset and a._offset[1] or 0
			sum, pos = sum + dx, pos + dx
			reach = math.max(reach, math.abs(pos))
		end
		if math.abs(sum) > 0.01 or reach > 3.01 then fail(scenario, ("the banner's shake does not settle (%.1f) or strays %.1f"):format(sum, reach)) end
	end
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
	if s5.land ~= s4.land or s5.reject ~= s4.reject or s5.shake ~= s4.shake or s5.banner ~= s4.banner then
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
	for _, t in ipairs({ look.aura, look.flash, look.bannerGlint, look.bannerFlash, look.barGlint, look.landTex }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a light is left lit on Calm") end
	end
	if (look.flareFrame._alpha or 0) > 0.001 or (look.breathFrame._alpha or 0) > 0.001 then
		fail(scenario, "the border is left lit on Calm")
	end
end)

withTree("look-heritage: owed breathes three times and settles, and stops with the favour", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	if not look.pulse[1]._playing then fail(scenario, "somebody owed on top on Full, and the ring does not breathe") end
	if #look.pulse ~= 2 or not look.pulse[2]._playing then fail(scenario, "the border does not breathe with the ring") end
	-- Round: two to three seconds, the aura and the border on one breath.
	local breath
	for i, group in ipairs(look.pulse) do
		local d = group._anims[1]._duration
		if breath and d ~= breath then fail(scenario, "the ring and the border breathe at different rates") end
		breath = d
		if group._looping ~= "BOUNCE" then fail(scenario, "breath " .. i .. " does not bounce") end
	end
	if not breath or breath * 2 < 2 or breath * 2 > 3 then
		fail(scenario, ("the owed breath is %.2f s round, not 2 to 3"):format((breath or 0) * 2))
	end
	-- Warm: the ring's glow is gold.
	local warm = look.aura._color
	if not (warm and warm[1] > warm[3]) then fail(scenario, "the ring's glow is not warm") end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(10)
	if look.pulse[1]._playing or looping() > 0 then fail(scenario, "the owed breath still loops after its three breaths") end
	if (look.aura._alpha or 0) > 0.001 or (look.breathFrame._alpha or 0) > 0.001 then
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
	if look.pulse[1]._playing or (look.aura._alpha or 0) > 0 or (look.breathFrame._alpha or 0) > 0 then
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
	-- With the icon off there is no ring to glow: nothing breathes.
	ns.db.profile.prompt.flashStyle = "pulse"
	ns.db.profile.prompt.showIcon = false
	ns.Prompt:ApplyStyle()
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	tick(ns)
	if looping() > 0 then fail(scenario, "with the icon off something breathes with no ring to glow") end
end)

withTree("look-heritage: the effects stay inside their time and their room under the text", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local function within(group, limit, what)
		if group and FT.groupLength(group) > limit then
			fail(scenario, ("%s lasts %.2f s, over %.2f"):format(what, FT.groupLength(group), limit))
		end
	end
	within(look.arrive[1], 0.7, "the flash on the portrait for an arrival")
	within(look.sweep[1], 0.7, "the glint along the banner")
	within(look.flashAnims[1], 0.7, "the flash on the portrait")
	within(look.flareAnims[1], 0.7, "the border's light")
	within(look.landAnims[1], 0.7, "the glint along the bar")
	within(look.landAnims[2], 0.7, "the bar's green")
	within(look.refuseAnims[1], 0.7, "the banner's red")
	for i, shake in ipairs(look.shakes) do within(shake, 0.35, "the banner's shake " .. i) end
	within(look.fx.rings[1].land, 0.7, "a ring")
	within(look.fx.rings[1].reject, 0.35, "a refusal's ring")
	-- Every frame of light is beneath the text's frame level.
	local text = r.textLayer._level or 0
	for name, f in pairs({ flare = look.flareFrame, breath = look.breathFrame, light = look.lightFrame,
		fight = look.fightFrame, orn = look.ornFrame, bar = look.barBox, chips = look.chipFrame,
		ring1 = look.fx.frames[1], ring2 = look.fx.frames[2] }) do
		if (f._level or 0) >= text then fail(scenario, name .. " is not beneath the text") end
	end
	-- And the ring and the wing are over the bar's overlays, the lights over the
	-- ring, the badge over the lights.
	if not ((look.barBox._level or 0) < (look.ornFrame._level or 0)) then fail(scenario, "the bar's overlays are not under the ring") end
	if not ((look.ornFrame._level or 0) < (look.lightFrame._level or 0)) then fail(scenario, "the lights are not over the ring") end
	if not ((look.lightFrame._level or 0) < (look.chipFrame._level or 0)) then fail(scenario, "the badge is not over the lights") end
	-- The glint runs along the banner's middle, inside it.
	local glint, banner = rectOf(look.bannerGlint), rectOf(look.banner)
	if glint and banner and not (glint[1] >= banner[1] - 0.01 and glint[3] <= banner[3] + 0.01) then
		fail(scenario, "the glint starts outside the banner")
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
	for _, key in ipairs({ "land", "reject", "shake", "settle", "banner", "bar" }) do
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
		for _, key in ipairs({ "land", "reject", "shake", "arrive", "banner" }) do
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
	for _, t in ipairs({ look.aura, look.flash, look.hilite, look.bannerGlint, look.bannerFlash, look.barGlint,
		look.landTex, look.coolTex }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a light was left lit after the look changed") end
	end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "a region of Heritage (" .. i .. ") is still shown on glass") break end
	end
end)

-- ------------------------------------------------------------------ 10
-- A fight puts the red glow of the frame on the ring and the border and keeps
-- the reason, dims the icon and the text a little. All of it comes back.
withTree("look-heritage: a fight puts the red glow on the frame and keeps the reason", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local _, bannerTop = ends(look.banner)
	if (look.fightFrame._alpha or 0) > 0.001 then fail(scenario, "the fight's glow is lit with no fight") end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if (look.fightFrame._alpha or 0) < 0.99 or (look.fightAura._alpha or 0) < 0.3 then
		fail(scenario, "a fight does not light the red glow round the ring")
	end
	for i, t in ipairs(look.fightGlow) do
		if (t._alpha or 0) < 0.3 or not (t._color and t._color[1] > 0.9 and t._color[2] < 0.4 and t._color[3] < 0.4) then
			fail(scenario, "the fight's glow on the border (" .. i .. ") is not red") break
		end
	end
	local fa = look.fightAura._color
	if not (fa and fa[1] > 0.9 and fa[2] < 0.4) then fail(scenario, "the glow round the ring is not red") end
	-- The glow is steady: nothing loops, nothing breathes in a fight.
	if looping() > 0 then fail(scenario, "something loops in a fight") end
	-- The gold stays gold.
	for _, piece in ipairs({ look.body[2], look.orn }) do
		if piece._desaturated or (piece._color and not sameColour(piece._color, 1, 1, 1)) then
			fail(scenario, "the gold is greyed in a fight, which the red glow replaces")
		end
	end
	if r.icon._desaturated then fail(scenario, "the icon is greyed in a fight") end
	if (r.icon._alpha or 1) < 0.99 then fail(scenario, "the icon turned see-through in a fight") end
	if not (r.icon._color and r.icon._color[1] < 0.9) then fail(scenario, "the icon is not dimmed in a fight") end
	if not (look.socket._shown ~= false and look.socket._file) then fail(scenario, "nothing opaque under the icon") end
	if not near(r.textLayer._alpha, 0.88) then fail(scenario, "the text does not dim in a fight") end
	if (r.art._alpha or 1) < 0.99 then fail(scenario, "art dimmed whole in a fight") end
	local _, held = ends(look.banner)
	if not (bannerTop and held and sameColour(held, bannerTop[1], bannerTop[2], bannerTop[3])) then
		fail(scenario, "the banner lost the reason's colour in a fight")
	end
	-- Laid out again during the hold: the hold stays.
	look:Apply(ns.db.profile.prompt, false)
	if (look.fightFrame._alpha or 0) < 0.99 then fail(scenario, "laying the look out again during the hold put the glow out") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if (look.fightFrame._alpha or 0) > 0.001 or r.icon._desaturated or not near(r.textLayer._alpha or 1, 1) then
		fail(scenario, "the fight's glow stayed on after it ended")
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
	if (look.fightFrame._alpha or 0) > 0.001 then fail(scenario, "leaving Heritage during a fight left the red glow lit") end
end)

-- ------------------------------------------------------------------ 11
-- The outcome: the name stays, the second line is the verdict, on the bar; the
-- banner takes the outcome's colour; without a second line the headline.
withTree("look-heritage: the outcome keeps the name and writes the verdict on the bar", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local function said(fs) return tostring(fs:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not said(r.name):find("Anna", 1, true) then fail(scenario, "the name did not stay on a landed buff: " .. said(r.name)) end
	if not said(r.sub):find("buffed", 1, true) then fail(scenario, "no verdict on the second line: " .. said(r.sub)) end
	local _, top = ends(look.banner)
	if not (top and top[2] > top[1] and top[2] > top[3]) then fail(scenario, "a landed buff's banner is not green") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not said(r.sub):find("Out of range", 1, true) then fail(scenario, "a refusal's own words are not the verdict: " .. said(r.sub)) end
	_, top = ends(look.banner)
	if not (top and top[1] > top[2] and top[1] > top[3]) then fail(scenario, "a refusal's banner is not red") end
	if not sameColour(look.rim._color, 1.00, 0.40, 0.34) then fail(scenario, "the ring is not the refusal's red") end
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

-- ------------------------------------------------------------------ 12
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
	if r.name._justifyH ~= nil and r.name._justifyH ~= "LEFT" then fail(scenario, "the name is still centred on glass") end
	if r.sub._justifyH ~= nil and r.sub._justifyH ~= "LEFT" then fail(scenario, "the reason line is still centred on glass") end
	if r.icon._mask ~= nil and look.mask._shown ~= false then fail(scenario, "the portrait's mask still cuts the icon on glass") end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "Heritage's region " .. i .. " is still shown on glass") break end
	end
	-- And back again, as new.
	p.style = "heritage"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.body[1]._shown == false then fail(scenario, "the border is not shown when the look comes back") end
	if (look.aura._alpha or 0) > 0.99 then fail(scenario, "the glow is left lit when the look comes back") end
	if r.icon._mask ~= look.mask then fail(scenario, "the portrait is not cut round when the look comes back") end
end)

-- ------------------------------------------------------------------ 13
-- The cursor lights the portrait, both ways; the move handle stays visible when
-- unlocked.
withTree("look-heritage: the cursor lights the portrait, and unlocked it can still be dragged", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	Mock.advance(0.3)
	FT.settle()
	if (look.hilite._alpha or 0) < 0.9 then fail(scenario, "the cursor on the panel does not light the portrait: " .. tostring(look.hilite._alpha)) end
	b.scripts.OnLeave(b)
	Mock.advance(0.5)
	FT.settle()
	if (look.hilite._alpha or 0) > 0.01 then fail(scenario, "the portrait's light stays after the cursor leaves") end
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (FT.visible(r.art) and FT.visible(look.body[2])) then fail(scenario, "the panel is not shown unlocked") end
	-- The warning the unlocked prompt shows is its own text on the lines, which
	-- the look leaves where they are: both lines still inside the banner and bar.
	local name, banner = rectOf(r.name), rectOf(look.banner)
	if name and banner and not (name[1] >= banner[1] - 0.01 and name[3] <= banner[3] + 0.01) then
		fail(scenario, "the unlocked prompt's line leaves the banner")
	end
	p.locked = true
end)

-- ------------------------------------------------------------------ 14
-- Read the way the game draws it: the name on the banner and the reason on the
-- bar, against every colour the banner and the bar can be.
local function linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function lum(c) return 0.2126 * linear(c[1]) + 0.7152 * linear(c[2]) + 0.0722 * linear(c[3]) end

local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- A colour over a white that is `alpha` of it: the bar's shine.
local function shined(c, alpha)
	return { c[1] + (1 - c[1]) * alpha, c[2] + (1 - c[2]) * alpha, c[3] + (1 - c[3]) * alpha }
end

withTree("look-heritage: the text reads on the banner and on the bar", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isHeritage(look) then fail(scenario, "SKIPPED -- Heritage is not the look in use") return end
	local function check(label, text, ground, minimum)
		if type(text) ~= "table" or not (text[1] and text[2] and text[3]) then
			fail(scenario, label .. " has no colour to judge")
			return
		end
		local got = ratio(lum(text), lum(ground))
		if got < minimum then fail(scenario, ("%s is %.2f:1, under %.1f"):format(label, got, minimum)) end
	end
	-- The bar's text against the brightest the bar is: its top, with the shine.
	local shine = 0.10
	local sg = look.fillShine._gradient
	if sg then
		local c2 = sg[3]
		shine = c2.a or c2[4] or shine
	end
	local function onBar(label)
		local _, top = ends(look.fill)
		if not top then fail(scenario, label .. ": the bar has no colour") return end
		check("the reason line on the bar (" .. label .. ")", r.sub._textColor, shined(top, shine), 4.5)
	end
	local window = ns.db.profile.timing.reciprocateWindow or 300
	for _, size in ipairs({ { 220, 44, 13 }, { 320, 58, 17 }, { 180, 36, 11 } }) do
		p.width, p.height, p.fontSize = size[1], size[2], size[3]
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.reasonPalette = palette
			for _, reason in ipairs(REASONS) do
				ns.Prompt:ApplyStyle()
				ns.Prompt:PaintAccent(reason)
				local _, top = ends(look.banner)
				check(("the name on the banner for %s (%s)"):format(reason, palette), r.name._textColor, top, 4.5)
				for _, kind in ipairs({ "cast", "failed", "sent" }) do
					Mock.advance(3)
					ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
					_, top = ends(look.banner)
					check("the name on the " .. kind .. " banner", r.name._textColor, top, 4.5)
				end
			end
		end
		-- The bar at every colour it takes.
		for _, frac in ipairs({ 1, 0.7, 0.5, 0.4, 0.3, 0.25, 0.2, 0.1, 0.05 }) do
			ns.owed["Anna Aim"] = { expires = GetTime() + window * frac, at = GetTime() - window * (1 - frac), class = "PRIEST" }
			ns.addon:Tick()
			onBar(("%d%% left"):format(frac * 100))
		end
		wipe(ns.owed)
		ns.addon:Tick()
		onBar("no clock")
		-- Class colours as the look softens them are held to the 3:1 the prompt
		-- holds every colour code to, against the banner's brightest.
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent("target")
		local _, top = ends(look.banner)
		local soften = look.classSoften or 0
		for _, code in ipairs({ "c41e3a", "a330c9", "ff7c0a", "33937f", "aad372", "3fc7eb", "00ff98", "f48cba",
			"ffffff", "fff468", "0070dd", "8788ee", "c69b6d" }) do
			local cr, cg, cb = tonumber(code:sub(1, 2), 16) / 255, tonumber(code:sub(3, 4), 16) / 255, tonumber(code:sub(5, 6), 16) / 255
			cr, cg, cb = cr + (1 - cr) * soften, cg + (1 - cg) * soften, cb + (1 - cb) * soften
			check("the class colour " .. code .. " on the banner", { cr, cg, cb }, top, 3)
		end
		owe(ns, "Anna Aim")
		ns.addon:Tick()
	end
	-- A light panel: dark text on a pale banner.
	p.width, p.height, p.fontSize = 220, 44, 13
	p.bgColor = { 0.86, 0.84, 0.78, 0.92 }
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs(REASONS) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local _, top = ends(look.banner)
			local bottom = ends(look.banner)
			check(("the name on the pale banner for %s (%s)"):format(reason, palette), r.name._textColor, bottom, 4.5)
			check(("the name on the pale banner for %s (%s), top"):format(reason, palette), r.name._textColor, top, 4.5)
			onBar("light panel")
		end
	end
end)

-- ------------------------------------------------------------------ 15
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
	-- Every shipped file is drawn, and none is left over from an earlier design.
	local drawn = { "Portrait", "Mask", "Rim", "Aura", "Ring", "Body", "Plate", "Glow", "Badge", "Pip", "Glint", "White" }
	for _, name in ipairs(drawn) do
		if not slurp(dir .. "/Textures/Heritage/Heritage_" .. name .. ".tga") then fail(scenario, name .. " does not ship") end
		if not names[name] then fail(scenario, name .. " ships but the look never draws it") end
	end
	for _, old in ipairs({ "Chip", "Frame", "FrameGlow", "Gem", "GemSet", "Gloss", "Proc", "Slot", "SlotBack", "SlotTint", "Stone" }) do
		if slurp(dir .. "/Textures/Heritage/Heritage_" .. old .. ".tga") then fail(scenario, old .. " still ships and nothing draws it") end
	end
	-- The files the look is cut from say what the code expects of them: the
	-- portrait's cell is as the Lua lays it, the aura's ring where it says.
	local port = header(dir .. "/Textures/Heritage/Heritage_Portrait.tga")
	if port and not (port.width == 256 and port.height == 256) then fail(scenario, "the portrait's file is not 256 square") end
	local body = header(dir .. "/Textures/Heritage/Heritage_Body.tga")
	if body and not (body.width == 128 and body.height == 128) then fail(scenario, "the body's file is not 128 square") end
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
