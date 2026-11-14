-- The Letter look (Looks/Letter.lua): what it promises beyond what every look
-- does, which tests/scenarios/looks.lua asks of it as well.
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows the
-- wrong thing. What it holds:
--   * it is registered, in the toc after the other looks, in all eight
--     languages, and draws only art of its own (no client texture at all); an
--     unknown saved style is the default;
--   * every state paints without an error on all five clients;
--   * the letter is fitted into the prompt at every size, in English and in
--     German: the rods, the paper and the wax inside it, the text between the
--     seal and the right rod and between the paper's burnt edges, the slips for
--     the count and the key beside the lines, the list's rows written on the
--     paper, which is lengthened over them, their names secure buttons on frames;
--   * the sheet is torn at its long edges, not cut, and folded twice, and the
--     lines stand clear of the tear at every size;
--   * the paper is opaque at rest inside its torn edges, light (a panel colour
--     only tints it), and the
--     ink on it is dark enough: 4.5:1 for every colour the text can be, class
--     colours included, tinted or dimmed for a fight;
--   * the wax carries the reason in both palettes (red for somebody owed), the
--     thin stroke of ink does too, and the marker's modes choose between them;
--   * the motion is the look's own and keeps to its time and its room: the
--     scroll unrolls and the seal presses down for an arrival, and the letter is
--     written in by a quill, from under a cover that is the paper itself; owed
--     breathes three times and settles; a landing flashes the seal gold, glows,
--     passes a light over the paper and is signed with a flourish; a refusal
--     flares and cracks the seal, the crack staying, and shakes the scroll; a
--     cast nobody confirmed does nothing; at rest the lamp glints on the wax,
--     the one loop with nobody owed; Calm is fades only;
--   * the fight dims the letter and keeps the reason; leaving the look puts back
--     everything it borrowed;
--   * its font is Morpheus on the Latin clients, the client's own on Korean and
--     Chinese, the player's choice when there is one;
--   * the art is 32-bit and drawn by a generator that draws the bytes that ship;
--   * what a review of the pictures found (the last section): nothing that rests
--     on the seal is additive; the spell comes with the stamp, not before the
--     wax; the landing's light starts whole and is soft on every side; a tall or
--     a short sheet repeats its paper; the sheet is one paper from rod to rod;
--     the list keeps clear of the seal; the glint and the flourish can be seen.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Letter\\"
local COMMAND = "CLICK MannersPrompt:LeftButton"
local CLIENTS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local REASONS = { "target", "owed", "asked", "group", "nearby", "self" }
local LOCALES = { "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }

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

-- The prompt up in the Letter with Anna owed on top (or `who`). Returns the
-- regions, the settings and the look.
local function upIn(ns, scenario, edit, who)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "letter"
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

local function isLetter(look)
	return look ~= nil and look.key == "letter" and look.body ~= nil and look.paperL ~= nil and look.rodL ~= nil
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

-- How many groups loop; `skip`: the look's own at rest (its `idle`), where the
-- question is whether anything else does.
local function looping(skip)
	local _, loops = FT.playing()
	local resting, n = {}, 0
	for _, g in ipairs(skip or {}) do resting[g] = true end
	for _, g in ipairs(loops) do
		if not resting[g] then n = n + 1 end
	end
	return n
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

-- A box as the panel sees it: x from the panel's left, y from its top.
local function rel(box, panel)
	return { box[1] - panel[1], panel[4] - box[4], box[3] - panel[1], panel[4] - box[2] }
end

-- The rectangle a texture is seen in: cut by every frame above it that cuts what
-- it holds, and, for the files whose art does not fill them (the wax's), shrunk
-- to how far out the art is seen.
local EDGE = { Seal = 0.96, SealRim = 0.96, SealGloss = 0.96, Crack = 0.96 }
local function seen(t)
	local box = rectOf(t)
	if not box then return nil end
	local name = tostring(t._file or ""):match("Letter_(%a+)$")
	local edge = name and EDGE[name]
	if edge then
		local cx, cy = (box[1] + box[3]) / 2, (box[2] + box[4]) / 2
		box = { cx + (box[1] - cx) * edge, cy + (box[2] - cy) * edge, cx + (box[3] - cx) * edge, cy + (box[4] - cy) * edge }
	end
	local up = t._parent
	while up do
		if up.DoesClipChildren and up:DoesClipChildren() then
			local c = rectOf(up)
			if c then
				box = { math.max(box[1], c[1]), math.max(box[2], c[2]), math.min(box[3], c[3]), math.min(box[4], c[4]) }
			end
		end
		up = up._parent
	end
	if box[3] <= box[1] or box[4] <= box[2] then return nil end
	return box
end

-- ------------------------------------------------------------------ 1
-- Registered, listed, in the toc, and in all eight languages.
withTree("look-letter: it is registered, listed and loaded after the other looks", ANNA, function(ns, scenario)
	local look = ns.Looks.list.letter
	if not look then fail(scenario, "no look is registered as letter") return end
	if look.key ~= "letter" then fail(scenario, "its key is " .. tostring(look.key)) end
	if ns.Looks.Get("letter") ~= look then fail(scenario, "Looks.Get does not hand back the look") end
	if look.native or look.fallback then fail(scenario, "the look is native or a fallback") end
	if not ns.Looks.Allowed().letter then fail(scenario, "a saved style of letter is not allowed") end
	local values, sorting = ns.Looks.Choices()
	if values.letter ~= ns.L["Letter -- parchment and a red wax seal"] then
		fail(scenario, "the dropdown's label is " .. tostring(values.letter))
	end
	local at
	for i, key in ipairs(sorting) do if key == "letter" then at = i end end
	if not at then fail(scenario, "the dropdown does not list it") end
	if look.order ~= 5 then fail(scenario, "its place in the dropdown is " .. tostring(look.order) .. ", not 5") end
	if look.title ~= ns.L["Letter"] or look.description ~= ns.L["parchment and a red wax seal"] then
		fail(scenario, "its card has the wrong title or line")
	end
	local title, line = ns.Looks.Card("letter")
	if title ~= "Letter" or line ~= "parchment and a red wax seal" then
		fail(scenario, "the card reads " .. tostring(title) .. " / " .. tostring(line))
	end
	-- The toc: after the last look, before the prompt that calls into it.
	local toc = slurp(dir .. "/Manners.toc") or ""
	local lines = {}
	for line2 in toc:gmatch("[^\r\n]+") do lines[#lines + 1] = line2 end
	local function index(name)
		for i, line2 in ipairs(lines) do if line2 == name then return i end end
	end
	local mine = index("Looks\\Letter.lua")
	if not mine then
		fail(scenario, "Manners.toc does not load Looks\\Letter.lua")
	else
		for _, other in ipairs({ "Looks\\Looks.lua", "Looks\\Luxe.lua", "Looks\\Toast.lua", "Looks\\Arcane.lua" }) do
			local i = index(other)
			if i and i > mine then fail(scenario, "Letter loads before " .. other) end
		end
		if mine > (index("Prompt\\Prompt.lua") or 0) then fail(scenario, "Letter loads after Prompt") end
	end
	for _, flavour in ipairs({ "Camelot", "Vanilla", "TBC", "Mists", "Mainline" }) do
		local generated = slurp(dir .. "/Manners_" .. flavour .. ".toc") or ""
		if not generated:find("Looks\\Letter.lua", 1, true) then
			fail(scenario, "Manners_" .. flavour .. ".toc does not load the look")
		end
	end
end)

withTree("look-letter: its name, title and line are translated into all eight languages", ANNA, function(_, scenario)
	local keys = { "Letter -- parchment and a red wax seal", "Letter", "parchment and a red wax seal" }
	for _, code in ipairs(LOCALES) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, key in ipairs(keys) do
			local head = 'L["' .. key .. '"] = "'
			local at = text:find(head, 1, true)
			if not at then
				fail(scenario, code .. " has no translation of " .. key)
			else
				local value = text:match('^[^\r\n]-"([^\r\n]*)"', at + #head - 1)
				if not value or value == "" or value == key then
					fail(scenario, code .. "'s translation of " .. key .. " is empty or still English: " .. tostring(value))
				end
			end
		end
	end
	local source = slurp(dir .. "/Looks/Letter.lua") or ""
	-- Every string the player reads goes through L with a literal key.
	if source:find("[^%w_]L%[[^\"]") then fail(scenario, "Looks/Letter.lua reads L with a key that is not a literal") end
	-- Russian is never translated.
	if slurp(dir .. "/Locales/ruRU.lua") then fail(scenario, "a Russian locale exists") end
end)

-- A style saved by a build that had a look this one does not is the default,
-- not a prompt drawn with nothing.
withTree("look-letter: an unknown saved style becomes the default", ANNA, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	for _, old in ipairs({ "heritage", "nonsense", "" }) do
		p.style = old
		ns.ClampSettings()
		if p.style ~= ns.defaults.profile.prompt.style then
			fail(scenario, ("a saved style of %q is %q after ClampSettings, not the default"):format(old, tostring(p.style)))
		end
	end
	p.style = "letter"
	ns.ClampSettings()
	if p.style ~= "letter" then fail(scenario, "ClampSettings took the letter for an unknown style") end
end)

-- ------------------------------------------------------------------ 2
-- Only art of its own: not one texture of the client's, and every file it
-- names ships. The preview cannot draw one of the client's and the five clients
-- do not keep the same ones.
withTree("look-letter: it draws only art of its own, and all of it ships", CROWD, function(ns, scenario)
	local seenFile, count = {}, 0
	local function one(x)
		if type(x) ~= "table" or seenFile[x] then return end
		seenFile[x] = true
		if type(x._file) == "string" then
			count = count + 1
			if x._file:sub(1, #ART) ~= ART then
				fail(scenario, "the look draws " .. x._file .. ", which is not its own art")
			else
				local f = io.open(dir .. "/Textures/Letter/" .. x._file:sub(#ART + 1):gsub("\\", "/") .. ".tga", "rb")
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
		if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			Mock.advance(3)
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			for _, x in ipairs(look.own) do one(x) end
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
	if count < 60 then fail(scenario, "only " .. count .. " textures were read, so nothing was held") end
	-- And the code names no texture of the client's anywhere.
	local source = slurp(dir .. "/Looks/Letter.lua") or ""
	for path in source:gmatch('"(Interface[^"]*)"') do
		if path ~= "Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Letter\\\\Letter_" then
			fail(scenario, "Looks/Letter.lua names " .. path .. ", a path that is not its own art")
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
	local scenario = "look-letter: every state paints without an error on " .. client
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
			{ "a custom marker colour", function()
				p.accentMode, p.accentByReason, p.accentColor = "icon", false, { 0.2, 0.9, 0.3, 1 }
			end },
			{ "light panel", function() p.accentMode, p.accentByReason, p.bgColor = "icon", true, { 0.86, 0.84, 0.78, 0.92 } end },
			{ "black panel", function() p.bgColor = { 0, 0, 0, 1 } end },
			{ "white text chosen", function() p.bgColor, p.fontColor = { 0.04, 0.04, 0.06, 0.88 }, { 1, 1, 1, 1 } end },
			{ "calm", function() p.effects = "calm" end },
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
-- The layout, at every size: the letter is fitted into the prompt, the rods
-- stand over the paper, the seal is round and holds the icon, and the lines
-- stand on the paper between the seal and the right rod, between its burnt
-- edges. A long name and a long translated reason, with and without the icon.
local LONG = { nameplate1 = { "Bartholomewzxyzq", "Longsurnamefortesting" },
	nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

-- Every texture the look keeps on the prompt itself, which must lie inside it:
-- not the list's drops and lines, which hang outside it when there is a list.
local function mainTextures(look)
	local out = {}
	local skip = {}
	for _, set in ipairs({ look.drops, look.lines }) do
		for _, t in ipairs(set) do skip[t] = true end
	end
	for i, x in ipairs(look.own) do
		if x._kind == "Texture" and not skip[x] and FT.visible(x) then out[#out + 1] = { i, x } end
	end
	return out
end

for _, locale in ipairs({ "enUS", "deDE" }) do
	local scenario = "look-letter: nothing overlaps or leaves the prompt, at every size, " .. locale
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
						if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
						if locale == "deDE" then p.reasonOwed = "hat dich gerade gebufft und wartet auf deine Antwort" end
						ns.Prompt:ApplyStyle()
						tick(ns)
						local panel = rectOf(r.art)
						local g = look.g
						-- Fitted into the prompt: nothing the look draws is outside it.
						for _, item in ipairs(mainTextures(look)) do
							local box = seen(item[2])
							if box and not inside(box, panel) then
								fail(scenario, ("%s: a part of the letter (%d, %s) is outside the prompt"):format(
									tag, item[1], tostring(item[2]._file):gsub("^.*Letter_", "")))
							end
						end
						local W, Hh = panel[3] - panel[1], panel[4] - panel[2]
						-- The rods stand over the paper, at the ends, inside the room a shake takes.
						local rodL, rodR = rel(seen(look.rodL[1]), panel), rel(seen(look.rodR[1]), panel)
						local rodBox = { rodL[1], rodL[2], rodL[3], rel(seen(look.rodL[3]), panel)[4] }
						local paper = look.paperTop and { g.x0, look.paperTop, g.x1, look.paperBottom }
						if rodL[1] < 1.99 or rodR[3] > W - 1.99 then fail(scenario, tag .. ": a rod is nearer the edge than a shake's room") end
						if not (paper and rodBox[2] < paper[2] - 0.5 and rodBox[4] > paper[4] + 0.5) then
							fail(scenario, tag .. ": the rods do not stand over the paper")
						end
						if rodR[1] < rodL[3] + 20 then fail(scenario, tag .. ": the rods are nearly touching") end
						-- The paper is continuous: its pieces meet in each column.
						for c = 1, 3 do
							local top, bottom
							for _, set in ipairs({ look.paperL[c], look.paperR[c] }) do
								local prev
								for _, t in ipairs(set) do
									if FT.visible(t) then
										local b = rectOf(t)
										if b then
											local y0, y1 = panel[4] - b[4], panel[4] - b[2]
											if prev and math.abs(y0 - prev) > 0.6 then
												fail(scenario, tag .. ": the paper's pieces do not meet (" .. y0 .. " after " .. prev .. ")")
											end
											prev = y1
											top = top and math.min(top, y0) or y0
											bottom = bottom and math.max(bottom, y1) or y1
										end
									end
								end
							end
							if top and (math.abs(top - look.paperTop) > 0.3 or math.abs(bottom - look.paperBottom) > 0.6) then
								fail(scenario, ("%s: the paper's column %d runs %.1f to %.1f, not %.1f to %.1f"):format(
									tag, c, top, bottom, look.paperTop, look.paperBottom))
							end
						end
						-- The seal: round, as tall as the prompt allows, the icon in it.
						local wax = rel(seen(look.body), panel)
						if not (wax[2] >= 1.2 and wax[4] <= Hh - 1.2) then fail(scenario, tag .. ": the wax is outside the prompt") end
						if math.abs((wax[3] - wax[1]) - (wax[4] - wax[2])) > 0.05 then fail(scenario, tag .. ": the wax is not round") end
						if icon then
							local box = rectOf(r.icon)
							if not box or math.abs((box[3] - box[1]) - (box[4] - box[2])) > 0.01 then
								fail(scenario, tag .. ": the icon is not square")
							else
								local ib = rel(box, panel)
								if not inside(ib, wax) then fail(scenario, tag .. ": the icon leaves the wax") end
								if math.abs((ib[1] + ib[3]) / 2 - (wax[1] + wax[3]) / 2) > 0.6 then fail(scenario, tag .. ": the icon is not in the middle of the wax") end
							end
							if not (r.icon._mask == look.mask and look.mask._shown ~= false) then
								fail(scenario, tag .. ": the icon is not cut round by the mask")
							end
							local mask = rectOf(look.mask)
							if box and mask and not (near(mask[1], box[1], 0.02) and near(mask[3], box[3], 0.02)
								and near(mask[2], box[2], 0.02) and near(mask[4], box[4], 0.02)) then
								fail(scenario, tag .. ": the mask is not the icon's size")
							end
							if look.rim._shown == false or look.mark._shown ~= false then fail(scenario, tag .. ": the lip is not on and the mark off with the icon on") end
						else
							if r.icon:IsShown() then fail(scenario, tag .. ": the icon is shown with the icon off") end
							if look.mark._shown == false or look.rim._shown ~= false then fail(scenario, tag .. ": the seal has no mark with the icon off") end
						end
						-- The text: right of the seal, left of the right rod, inside the paper's
						-- height, the two lines apart.
						local name, sub = rectOf(r.name), r.sub:IsShown() and rectOf(r.sub) or nil
						if not name then fail(scenario, tag .. ": the name has no place") return end
						local limits = { panel[1] + g.sealRight, panel[1] + g.textRight }
						local function line(label, box)
							if box[1] < limits[1] - 0.01 then fail(scenario, ("%s: the %s starts over the seal"):format(tag, label)) end
							if box[3] > limits[2] + 0.01 then fail(scenario, ("%s: the %s runs under the right rod"):format(tag, label)) end
							local b = rel(box, panel)
							if b[1] < rodL[3] or b[3] > rodR[1] then fail(scenario, ("%s: the %s runs over a rod"):format(tag, label)) end
							-- The paper's own edge is the height: the text is on it.
							if b[2] < look.paperTop - 0.6 or b[4] > look.paperBottom + 0.6 then
								fail(scenario, ("%s: the %s leaves the paper (%.1f to %.1f, the paper %.1f to %.1f)"):format(
									tag, label, b[2], b[4], look.paperTop, look.paperBottom))
							end
						end
						line("name", name)
						if sub then
							line("reason", sub)
							local nm, sm = (name[2] + name[4]) / 2, (sub[2] + sub[4]) / 2
							if nm - sm < font * 0.8 then fail(scenario, tag .. ": the two lines meet") end
						end
						-- The stroke of ink runs between the lines, on the paper.
						if look.ruleOn and look.rule._shown ~= false then
							local rule = rectOf(look.rule)
							if rule then
								local rr = rel(rule, panel)
								if rr[1] < limits[1] - panel[1] - 0.01 or rr[3] > g.textRight + 0.01 then fail(scenario, tag .. ": the stroke of ink leaves the text's room") end
								if sub and (across(rule, name) and (rule[4] - rule[2]) > 4) then fail(scenario, tag .. ": the stroke of ink is over the name") end
							end
						end
						if look.countMode == "seal" then
							-- Pinned on the seal's edge: in the prompt, its middle on the wax's
							-- edge, clear of both lines.
							local chip = rectOf(look.countBox)
							if not icon then fail(scenario, tag .. ": a slip pinned on a seal that is not there") end
							if chip and not inside(rel(chip, panel), { 0, 0, panel[3] - panel[1], panel[4] - panel[2] }) then
								fail(scenario, tag .. ": the count's slip leaves the prompt")
							end
							if chip then
								local c = rel(chip, panel)
								local dist = math.sqrt(((c[1] + c[3]) / 2 - g.cx) ^ 2 + ((c[2] + c[4]) / 2 - g.cy) ^ 2)
								if dist > g.sealD / 2 + 1 or dist < g.sealD / 2 * 0.6 then
									fail(scenario, ("%s: the count's slip is %.1f from the seal's middle, not on the wax's edge (%.1f)"):format(
										tag, dist, g.sealD / 2))
								end
								if across(chip, name) then fail(scenario, tag .. ": the count's slip is over the name") end
								if sub and across(chip, sub) then fail(scenario, tag .. ": the count's slip is over the reason") end
							end
						elseif look.countMode then
							local chip = rectOf(look.countBox)
							if chip and not inside(rel(chip, panel), { g.textX, look.paperTop, g.textRight, look.paperBottom }) then
								fail(scenario, tag .. ": the count's slip leaves the paper's text")
							end
							if chip and across(chip, name) and name[3] > chip[1] + 0.01 then
								fail(scenario, tag .. ": the count's slip is over the name")
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

-- ------------------------------------------------------------------ 5
-- The bound key is a slip of paper at the reason line's end and the count a
-- smaller one pinned on the seal's edge, so the name has its whole line. With no
-- seal to pin it on (the icon off) the count's slip stands beside the key's on
-- the reason line; with no reason line, both stand side by side on the name line.
withTree("look-letter: the bound key and the count are slips beside the lines", CROWD, function(ns, scenario)
	for _, case in ipairs({ { two = true, icon = true }, { two = false, icon = true },
		{ two = true, icon = false }, { two = false, icon = false } }) do
		local two, icon = case.two, case.icon
		local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.showSub, pp.showIcon = 260, two, icon end)
		SetBinding("SHIFT-F", COMMAND)
		tick(ns)
		if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		local panel = rectOf(r.art)
		local g = look.g
		local tag = (two and "two lines" or "one line") .. (icon and ", a seal" or ", no seal")
		if not look.keyUp then fail(scenario, tag .. ": a bound key shows no slip") return end
		if not look.countMode then fail(scenario, tag .. ": the count shows no slip") return end
		local key, count = rectOf(look.keyBox), rectOf(look.countBox)
		local name = rectOf(r.name)
		local paper = { g.textX, look.paperTop, g.textRight, look.paperBottom }
		if not (key and inside(rel(key, panel), paper)) then fail(scenario, tag .. ": the key's slip leaves the paper") end
		if icon then
			if look.countMode ~= "seal" then fail(scenario, tag .. ": the count is not pinned on the seal: " .. tostring(look.countMode)) end
			local c = count and rel(count, panel)
			if not (c and c[1] >= 0 and c[3] <= g.textX) then fail(scenario, tag .. ": the count's slip is not on the seal") end
		elseif not (count and inside(rel(count, panel), paper)) then
			fail(scenario, tag .. ": the count's slip leaves the paper")
		end
		if name and key and across(name, key) then fail(scenario, tag .. ": the key's slip is over the name") end
		if name and count and across(name, count) then fail(scenario, tag .. ": the count's slip is over the name") end
		if count and key and across(count, key) then fail(scenario, tag .. ": the two slips overlap") end
		-- Each on its own line: the key's middle is the reason's.
		local function mid(b) return (b[2] + b[4]) / 2 end
		if two then
			local sub = rectOf(r.sub)
			if sub and key and math.abs(mid(key) - mid(sub)) > 3 then fail(scenario, tag .. ": the key's slip is not on the reason line") end
			if sub and key and across(sub, key) then fail(scenario, tag .. ": the key's slip is over the reason") end
			if sub and count and across(sub, count) then fail(scenario, tag .. ": the count's slip is over the reason") end
			if not icon then
				if look.countMode ~= "sub" then fail(scenario, tag .. ": the count is not beside the key on the reason line: " .. tostring(look.countMode)) end
				if sub and count and math.abs(mid(count) - mid(sub)) > 3 then fail(scenario, tag .. ": the count's slip is not on the reason line") end
				if count and key and not (count[3] <= key[1] + 0.01) then fail(scenario, tag .. ": the count is not left of the key") end
			end
		elseif not icon then
			if look.countMode ~= "pair" then fail(scenario, tag .. ": the count and the key are not a pair") end
			if count and key and not (count[3] <= key[1] + 0.01) then fail(scenario, tag .. ": the count is not left of the key") end
		end
		-- Both slips are paper, with writing in the ink.
		for _, slip in ipairs({ look.countSlip, look.keySlip }) do
			for i, t in ipairs(slip) do
				if t._shown == false then fail(scenario, tag .. ": a piece of a slip is hidden (" .. i .. ")") end
			end
		end
		SetBinding("SHIFT-F")
		tick(ns)
		if look.keyUp then fail(scenario, tag .. ": the key's slip stays with the key unbound") end
	end
end)

-- Where the reason has no room for both slips, or there is no seal, the count's
-- slip stands at the name line's end, and the name keeps clear of it.
withTree("look-letter: where the reason has no room the count's slip stands at the name line's end", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.width, pp.showIcon = 220, false
		pp.reasonOwed = "hat dich gerade gebufft und wartet auf deine Antwort"
	end)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	SetBinding("SHIFT-F", COMMAND)
	tick(ns)
	local name, sub = rectOf(r.name), rectOf(r.sub)
	if look.countMode == "chip" then
		local count = rectOf(look.countBox)
		if not count then fail(scenario, "the count's slip has no place") return end
		if across(name, count) then fail(scenario, "the count's slip is over the name") end
		if sub and across(sub, count) then fail(scenario, "the count's slip is over the reason") end
		if name and math.abs((count[2] + count[4]) / 2 - (name[2] + name[4]) / 2) > 3 then
			fail(scenario, "the count's slip is not on the name line")
		end
		if name[3] > count[1] + 0.01 then fail(scenario, "the name runs under the count's slip") end
	elseif look.countMode == "sub" then
		local count = rectOf(look.countBox)
		if sub and count and sub[3] > count[1] + 0.01 then fail(scenario, "the reason runs under the count's slip") end
	elseif look.countMode then
		fail(scenario, "the count's slip is in an unexpected place: " .. tostring(look.countMode))
	end
	-- Wherever it stood, nothing of either line is under any slip.
	for _, box in ipairs({ look.countBox, look.keyBox }) do
		local b = rectOf(box)
		if b and ((look.countMode and box == look.countBox) or (look.keyUp and box == look.keyBox)) then
			if name and across(name, b) then fail(scenario, "the name is under a slip") end
			if sub and across(sub, b) then fail(scenario, "the reason is under a slip") end
		end
	end
end)

-- An ordinary name is whole at the default size with the count and the key up:
-- "Elowen Thistledown" (18 letters) in English and a German two-part name of the
-- same length, on a 220 x 44 prompt at 13 pt with a 30 icon, +2 behind them and
-- F bound. The count's slip is pinned on the seal and the key's stands on the
-- reason line, so the name has the line's room; measured the way a display serif
-- is (0.58 of the size a letter, the width the stand-in for Morpheus draws),
-- which the mock's half a size a letter flatters.
for _, case in ipairs({ { "enUS", { "Elowen", "Thistledown" } }, { "deDE", { "Friedrich", "Eichwald" } } }) do
	local locale, who = case[1], case[2]
	local full = who[1] .. " " .. who[2]
	local scenario = ("look-letter: %s with a count and a key is not cut at the default size, %s"):format(full, locale)
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
			if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
			SetBinding("F", COMMAND)
			tick(ns)
			if not tostring(r.name:GetText()):find(who[1], 1, true) then
				fail(scenario, "the name on the prompt is not " .. full .. ": " .. tostring(r.name:GetText()))
				return
			end
			if not look.countMode then fail(scenario, "the count has no slip: it stepped aside for the name") end
			if not tostring(r.count:GetText()):find("^%+2") then fail(scenario, "the count does not say +2: " .. tostring(r.count:GetText())) end
			if not look.keyUp then fail(scenario, "the key has no slip: it stepped aside for the name") end
			local room = rectOf(r.name)
			local width = r.name:GetUnboundedStringWidth()
			local size = select(2, r.name:GetFont())
			local base = look.kit.fit.base[r.name]
			if room and type(width) == "number" and width > room[3] - room[1] + 0.6 then
				fail(scenario, ("the name is %.1f wide in a room of %.1f: it is cut"):format(width, room[3] - room[1]))
			end
			if type(size) == "number" and type(base) == "number" and size < base * 0.9 then
				fail(scenario, ("the name is drawn at %s, shrunk from %s for the slips"):format(tostring(size), tostring(base)))
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

-- ------------------------------------------------------------------ 6
-- The list: more of the letter. The paper and the rods are lengthened over the
-- rows, which are written on the paper in ink with a drop of wax each, over the
-- paper but under the text's frame; each name a secure button on a frame.
withTree("look-letter: the list is written on the paper, which is lengthened over it", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local panel = rectOf(r.art)
	local g = look.g
	local function check(label, above)
		local H0 = panel[4] - panel[2]
		-- The rods and the paper cover the list's side of the prompt.
		if above and not (look.paperTop < -2) then fail(scenario, label .. ": the paper is not lengthened upwards") end
		if not above and not (look.paperBottom > H0 + 2) then fail(scenario, label .. ": the paper is not lengthened downwards") end
		if not (look.rodY0 <= look.paperTop - g.pv + 1.01 and look.rodY0 + look.rodH >= look.paperBottom + g.pv - 1.01) then
			fail(scenario, ("%s: the rods (%.1f to %.1f) do not stand over the paper (%.1f to %.1f)"):format(
				label, look.rodY0, look.rodY0 + look.rodH, look.paperTop, look.paperBottom))
		end
		-- The rods are whole: their three pieces meet.
		for _, rod in ipairs({ look.rodL, look.rodR }) do
			local a, b, c = rectOf(rod[1]), rectOf(rod[2]), rectOf(rod[3])
			if a and b and c and not (math.abs(a[2] - b[4]) < 0.05 and math.abs(b[2] - c[4]) < 0.05) then
				fail(scenario, label .. ": a rod's pieces do not meet")
			end
		end
		-- The paper is cut from tiles of its middle band, none of them stretched much
		-- more or less than the caps (a long list stretched from one tile is a smear).
		for c = 1, 3 do
			for _, set in ipairs({ look.paperL[c], look.paperR[c] }) do
				local cap
				for _, t in ipairs(set) do
					local tc = t._texCoord
					if FT.visible(t) and tc and tc[4] > tc[3] then
						local b = rectOf(t)
						local scale = b and (b[4] - b[2]) / (tc[4] - tc[3])
						if scale then
							cap = cap or scale
							if scale < cap * 0.6 or scale > cap * 1.6 then
								fail(scenario, ("%s: a piece of the paper's column %d is stretched %.2f times its cap's scale"):format(label, c, scale / cap))
							end
						end
					end
				end
			end
		end
		-- The rows: text over the paper, over the paper's frames and under the text's.
		local shown = 0
		local rowLevel = look.rowFrame._level or 0
		for _, f in ipairs({ look.paperFrame, look.paperSlide, look.paperSheet, look.shadowFrame, look.rodFrame, look.chipFrame }) do
			if (f._level or 0) >= rowLevel and f ~= look.chipFrame then fail(scenario, "the rows' frame is not over the paper's") end
		end
		if rowLevel >= (r.textLayer._level or 0) then fail(scenario, "the rows' frame is not under the text's") end
		for i, row in ipairs(r.rows) do
			if row:IsShown() and (row:GetText() or "") ~= "" then
				shown = shown + 1
				if row._parent ~= look.rowFrame then fail(scenario, label .. ": row " .. i .. " is not on the rows' frame") end
				local at = row.points[#row.points]
				if not at then
					fail(scenario, label .. ": row " .. i .. " has no place")
				else
					local y = -at[5]
					if above and not (y < 0) then fail(scenario, label .. ": row " .. i .. " is not over the panel") end
					if not above and not (y > H0) then fail(scenario, label .. ": row " .. i .. " is not under the panel") end
					local relTo = at[2]
					if relTo ~= r.art and relTo ~= ns.Prompt:GetButton() then fail(scenario, label .. ": row " .. i .. " is not anchored to a frame") end
				end
				local box = rectOf(row)
				if box then
					local b = rel(box, panel)
					if b[1] < g.textX - 0.01 or b[3] > g.textRight + 0.01 then fail(scenario, label .. ": row " .. i .. "'s text leaves the paper's width") end
					if b[2] < look.paperTop - 0.01 or b[4] > look.paperBottom + 0.01 then fail(scenario, label .. ": row " .. i .. "'s text leaves the paper") end
				end
				local drop, line = look.drops[i], look.lines[i]
				if not (drop and drop._shown ~= false and drop._color and line and line._shown ~= false) then
					fail(scenario, label .. ": row " .. i .. " has no drop of wax or ruled line")
				else
					local d = rectOf(drop)
					if d and not (math.abs((rel(d, panel)[1] + rel(d, panel)[3]) / 2 - g.cx) < 0.6) then
						fail(scenario, label .. ": row " .. i .. "'s drop of wax is not under the seal")
					end
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
					local relTo = pt[2]
					if relTo and (relTo._kind == "Texture" or relTo._kind == "FontString") then
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
	-- The drops of wax in the wax of their reasons, both palettes: strangers are
	-- "nearby".
	for _, palette in ipairs({ "standard", "colourblind" }) do
		ns.db.profile.prompt.reasonPalette = palette
		ns.Prompt:ApplyStyle()
		tick(ns)
		local nr, ng, nb = look:WaxFor(0, 0, 0, "nearby", "icon")
		for i, drop in ipairs(look.drops) do
			if drop._shown ~= false and drop._color and not sameColour(drop._color, nr, ng, nb) then
				fail(scenario, ("drop %d is not the %s set's wax for a stranger"):format(i, palette))
			end
		end
	end
	-- Gone with the list: the paper and the rods are the prompt's again.
	ns.db.profile.prompt.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (near(look.paperTop, g.pv, 0.01) and near(look.paperBottom, panel[4] - panel[2] - g.pv, 0.01)) then
		fail(scenario, "the paper stays long with the list off")
	end
	for i, t in ipairs(look.drops) do
		if t._shown ~= false then fail(scenario, "drop " .. i .. " stays with the list off") end
	end
	for i, t in ipairs(look.lines) do
		if t._shown ~= false then fail(scenario, "ruled line " .. i .. " stays with the list off") end
	end
end)

-- ------------------------------------------------------------------ 7
-- The reason: the wax carries it, in both palettes, red for somebody owed; the
-- thin stroke of ink carries it with "stripe" or "both"; neither with the marker
-- off.
local function lin(c)
	if c <= 0.04045 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function lab(c)
	local r, g, b = lin(c[1]), lin(c[2]), lin(c[3])
	local X = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	local Y = 0.2126 * r + 0.7152 * g + 0.0722 * b
	local Z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	local function f(t) return t > 0.008856 and t ^ (1 / 3) or 7.787 * t + 16 / 116 end
	return { 116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z)) }
end

local PROTAN = { { 0.152286, 1.052583, -0.204868 }, { 0.114503, 0.786281, 0.099216 }, { -0.003882, -0.048116, 1.051998 } }
local DEUTAN = { { 0.367322, 0.860646, -0.227968 }, { 0.280085, 0.672501, 0.047413 }, { -0.011820, 0.042940, 0.968881 } }

-- A colour as sight with a missing cone sees it (Machado et al., severity 1).
local function simulate(c, m)
	local v = { lin(c[1]), lin(c[2]), lin(c[3]) }
	local out = {}
	for i = 1, 3 do
		local s = m[i][1] * v[1] + m[i][2] * v[2] + m[i][3] * v[3]
		s = math.max(0, math.min(1, s))
		out[i] = s <= 0.0031308 and s * 12.92 or 1.055 * s ^ (1 / 2.4) - 0.055
	end
	return out
end

local function distance(a, b, m)
	if m then a, b = simulate(a, m), simulate(b, m) end
	local la, lb = lab(a), lab(b)
	return math.sqrt((la[1] - lb[1]) ^ 2 + (la[2] - lb[2]) ^ 2 + (la[3] - lb[3]) ^ 2)
end

withTree("look-letter: the wax carries the reason in both palettes, red for somebody owed", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	-- The default look is the mockup's: red wax, no stroke of ink.
	local c = look.body._color
	if not (c and c[1] > 0.7 and c[2] < 0.2 and c[3] < 0.2) then fail(scenario, "the default seal is not red wax") end
	if look.rule._shown ~= false then fail(scenario, "the default look draws a stroke of ink though the marker is the icon") end
	local waxes = {}
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		waxes[palette] = {}
		for _, reason in ipairs(REASONS) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			local wr, wg, wb = look:WaxFor(cr, cg, cb, reason, "icon")
			if not sameColour(look.body._color, wr, wg, wb) then
				fail(scenario, ("the wax is not %s's in the %s set"):format(reason, palette))
			end
			if not sameColour(look.rim._color, wr, wg, wb) then
				fail(scenario, ("the lip is not %s's wax in the %s set"):format(reason, palette))
			end
			waxes[palette][reason] = { wr, wg, wb }
		end
		-- Your own buff wears your group's wax, as it wears your group's colour.
		local own, group = waxes[palette].self, waxes[palette].group
		if not sameColour(own, group[1], group[2], group[3]) then fail(scenario, "a self-buff's wax is not the group's in the " .. palette .. " set") end
		-- Far apart: five waxes, in CIE76, for normal sight, and for the colourblind
		-- set under protanopia and deuteranopia too.
		local five = { "target", "owed", "asked", "group", "nearby" }
		for i = 1, #five do
			for j = i + 1, #five do
				local a, b = waxes[palette][five[i]], waxes[palette][five[j]]
				local need = palette == "colourblind" and 40 or 38
				if distance(a, b) < need then
					fail(scenario, ("%s and %s wax are only %.1f apart in the %s set"):format(five[i], five[j], distance(a, b), palette))
				end
				if palette == "colourblind" then
					for name, m in pairs({ protan = PROTAN, deutan = DEUTAN }) do
						if distance(a, b, m) < 20 then
							fail(scenario, ("%s and %s wax are only %.1f apart under %s"):format(five[i], five[j], distance(a, b, m), name))
						end
					end
				end
			end
		end
		-- Owed is red wax in the standard set and orange in the colourblind one, as
		-- the palettes' owed is amber and orange.
	end
	local o = waxes.standard.owed
	if not (o[1] > 0.7 and o[2] < 0.2 and o[3] < 0.2) then fail(scenario, "owed is not red in the standard set") end
	-- Marker off: nothing carries the reason; the classic red and no stroke.
	p.reasonPalette, p.accentMode = "standard", "off"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	if not sameColour(look.body._color, 0.80, 0.10, 0.13) then fail(scenario, "with the marker off the wax still carries the reason") end
	if look.rule._shown ~= false then fail(scenario, "with the marker off the stroke of ink is drawn") end
	local ring, stripe = look.AccentCarriers(p)
	if ring ~= false or stripe ~= false then fail(scenario, "AccentCarriers says the marker off carries something") end
	-- Stripe only: the stroke, in the reason's colour made dark enough; the wax is
	-- the classic red.
	p.accentMode = "stripe"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	if not sameColour(look.body._color, 0.80, 0.10, 0.13) then fail(scenario, "on stripe only the wax carries the reason") end
	if look.rule._shown == false then fail(scenario, "on stripe only the stroke of ink is not drawn") end
	ring, stripe = look.AccentCarriers(p)
	if ring ~= false or stripe ~= true then fail(scenario, "AccentCarriers does not say stripe only is the stroke") end
	-- Both.
	p.accentMode = "both"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	ring, stripe = look.AccentCarriers(p)
	if ring ~= true or stripe ~= true then fail(scenario, "AccentCarriers does not say both is both") end
	if look.rule._shown == false then fail(scenario, "on both the stroke of ink is not drawn") end
	if sameColour(look.body._color, 0.80, 0.10, 0.13) then fail(scenario, "on both the wax is the classic red for a group member") end
	-- The icon off: the wax still carries it (it is the seal).
	p.accentMode, p.showIcon = "icon", false
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	ring, stripe = look.AccentCarriers(p)
	if ring ~= true or stripe ~= false then fail(scenario, "with the icon off the wax should carry the reason alone") end
	if sameColour(look.body._color, 0.80, 0.10, 0.13) then fail(scenario, "with the icon off the wax lost the reason") end
	p.showIcon = true
	-- The stroke in each reason's colour, dark enough to read on the paper (3:1)
	-- and its hue the reason's, in both palettes.
	local function luminance(col) return 0.2126 * lin(col[1]) + 0.7152 * lin(col[2]) + 0.0722 * lin(col[3]) end
	p.accentMode = "stripe"
	local darks = {}
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		darks[palette] = {}
		for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby" }) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local col = look.rule._color
			if not col then fail(scenario, "the stroke has no colour") else
				local ground = look.kit.ink.lo
				if (ground + 0.05) / (luminance(col) + 0.05) < 3 - 0.02 then
					fail(scenario, ("the stroke for %s (%s) is under 3:1 on the paper"):format(reason, palette))
				end
				local cr, cg, cb = ns.Prompt:AccentColor(reason)
				-- The same hue as the palette's colour: scaled towards black by one factor.
				local k = math.max(col[1], col[2], col[3]) / math.max(cr, cg, cb)
				if not (near(col[1], cr * k, 0.04) and near(col[2], cg * k, 0.04) and near(col[3], cb * k, 0.04)) then
					fail(scenario, ("the stroke for %s (%s) is not the palette's hue"):format(reason, palette))
				end
				darks[palette][reason] = { col[1], col[2], col[3] }
			end
		end
	end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		local five = { "target", "owed", "asked", "group", "nearby" }
		for i = 1, #five do
			for j = i + 1, #five do
				local a, b = darks[palette][five[i]], darks[palette][five[j]]
				if a and b and distance(a, b) < 9 then
					fail(scenario, ("the strokes for %s and %s are only %.1f apart in the %s set"):format(five[i], five[j], distance(a, b), palette))
				end
			end
		end
	end
	-- One colour for every reason when the player says so: the wax itself.
	p.accentMode, p.accentByReason, p.accentColor = "icon", false, { 0.2, 0.9, 0.3, 1 }
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	if not sameColour(look.body._color, 0.2, 0.9, 0.3) then fail(scenario, "the marker colour the player chose is not the wax") end
end)

-- ------------------------------------------------------------------ 8
-- The icon is round whatever "Round the icon off" says, and sized by the seal
-- as Options says; the sweep round.
withTree("look-letter: the icon is round and sized by the seal, the sweep round", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.roundIcon = false end)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local cd = r.cooldown
	if cd then
		if cd._circular ~= true then fail(scenario, "the sweep's edge is not round on a round icon") end
		if tostring(cd._swipeTexture or "") ~= ART .. "Letter_Mask" then fail(scenario, "the sweep is not cut by the seal's mask: " .. tostring(cd._swipeTexture)) end
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
	if ns.TwoLineHeight(13, "letter") > 44 then
		fail(scenario, "two lines need " .. ns.TwoLineHeight(13, "letter") .. " on the Letter, over the default height of 44")
	end
	if not (ns.TwoLineHeight(17, "letter") > ns.TwoLineHeight(13, "letter")) then
		fail(scenario, "a bigger font needs no more height")
	end
	tick(ns)
	if not r.sub:IsShown() then fail(scenario, "the default size shows no second line") end
	-- At the default size the icon reads: at least 22 across (the wax, which it
	-- is pressed into, has the rest of the prompt's height).
	local box = rectOf(r.icon)
	if box and (box[3] - box[1]) < 22 then fail(scenario, "the icon is " .. (box[3] - box[1]) .. " across at the default size") end
	-- A round button's sweep, with its leading edge.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if cd and cd._drawEdge ~= true then fail(scenario, "the sweep has no leading edge") end
end)

-- The options page says how the Letter sizes its icon and greys out what it does
-- not read, and does not call the marker dead where the wax carries it.
withTree("look-letter: the options page states the icon's size and greys out the round icon", ANNA, function(ns, scenario)
	local _, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local slider = H.findOption(ns.optionsTable, "iconSize")
	local notice = H.findOption(ns.optionsTable, "iconSizeCapped")
	local round = H.findOption(ns.optionsTable, "roundIcon")
	if not (slider and notice and round) then fail(scenario, "SKIPPED -- no icon options") return end
	p.iconSize = 20
	ns.Prompt:ApplyStyle()
	if not slider.disabled() then fail(scenario, "the icon size slider is live on a look that ignores it") end
	if notice.hidden() then fail(scenario, "nothing on the options page says how the Letter sizes its icon") end
	local drawn = look.IconSize(p)
	if not tostring(notice.name()):find(tostring(drawn), 1, true) then
		fail(scenario, "the notice does not give the icon's size (" .. drawn .. "): " .. tostring(notice.name()))
	end
	if not round.disabled() then fail(scenario, "the round icon toggle is live on a seal that is always round") end
	-- The marker is never dead: the wax carries it, with the icon off too.
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	local ring, stripe = look.AccentCarriers(p)
	if not (ring or stripe) then fail(scenario, "with the icon off the marker has nowhere to go") end
	p.showIcon = true
	p.style = "glass"
	if slider.disabled() then fail(scenario, "the icon size slider is off on glass") end
	if round.disabled() then fail(scenario, "the round icon toggle is off on glass") end
end)

-- ------------------------------------------------------------------ 9
-- The motion. Each effect plays on its own event and on no other.
local function groups(look, r)
	return {
		unroll = look.unrollGroups,
		stamp = look.stamp,
		land = { look.flashAnims[1], look.passAnims[1], r.settle },
		reject = { look.flashAnims[1], look.crackAnims[1] },
		shake = { r.shake },
		flash = { look.flashAnims[1] },
		pass = { look.passAnims[1] },
		crack = { look.crackAnims[1] },
		settle = { r.settle },
		scroll = look.shakes,
	}
end

local function snapshot(g)
	local out = {}
	for key, list in pairs(g) do out[key] = total(list) end
	return out
end

withTree("look-letter: a favour arriving unrolls the scroll and presses the seal, once, for somebody owed", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
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
	if snapshot(g).unroll ~= before.unroll then fail(scenario, "a passer-by on the panel unrolled the scroll") end
	owe(ns, "Anna Aim")
	tick(ns)
	local after = snapshot(g)
	if after.unroll - before.unroll < 3 then fail(scenario, "somebody buffing you did not unroll the scroll (the window, the paper and the rod)") end
	if after.stamp - before.stamp < 4 then fail(scenario, "somebody buffing you did not press the seal down") end
	-- The unroll: the window opens as the paper holds still (the two slide the same
	-- way and the other), and the right rod runs out with the window's edge.
	local b, pp, rod = look.slideB, look.slideP, look.slideR
	if not (b and pp and rod and near(b._offset[1], -pp._offset[1], 0.01) and near(b._offset[1], rod._offset[1], 0.01) and b._offset[1] > 10) then
		fail(scenario, "the unroll's window, paper and rod do not move together")
	end
	if not (near(b._duration, pp._duration, 0.001) and near(b._duration, rod._duration, 0.001)
		and b._smoothing == pp._smoothing and b._smoothing == rod._smoothing) then
		fail(scenario, "the unroll's three slides do not keep time")
	end
	if not look.paperSlide:DoesClipChildren() then fail(scenario, "the window onto the paper does not cut what it holds") end
	-- At the start the window is to the left of its place, the paper to the right
	-- of it, so that the paper is where it belongs; at the end all is at rest.
	local rod0 = look.rodRight.points[1]
	if not (rod0 and rod0[4] < look.g.rodR - 5) then fail(scenario, "the right rod does not start out to the left of its place") end
	Mock.advance(0.6)
	FT.settle()
	local win, sheet, rodp = look.paperSlide.points[1], look.paperSheet.points[1], look.rodRight.points[1]
	if not (win and near(win[4], look.g.splitX, 0.01) and sheet and near(sheet[4], 0, 0.01) and rodp and near(rodp[4], look.g.rodR, 0.01)) then
		fail(scenario, "after the unroll the window, the paper and the rod are not at rest")
	end
	-- Once: the next scans are the same person owed the same favour.
	Mock.advance(0.4)
	tick(ns)
	Mock.advance(0.4)
	tick(ns)
	if snapshot(g).unroll ~= after.unroll or snapshot(g).stamp ~= after.stamp then fail(scenario, "the arrival played again on a repaint of the same favour") end
	-- Nothing of a landing or a refusal came with it.
	local now = snapshot(g)
	if now.settle ~= before.settle or now.shake ~= before.shake or now.flash ~= before.flash or now.pass ~= before.pass
		or now.crack ~= before.crack or now.scroll ~= before.scroll then
		fail(scenario, "an arrival played the landing's or the refusal's effects")
	end
	-- Not over an outcome the panel is still showing.
	ns.BlockPerson("Anna Aim")
	ns.owed["Anna Aim"] = nil
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local during = snapshot(g).unroll
	Mock.advance(0.2)
	owe(ns, "Anna Aim")
	tick(ns)
	if snapshot(g).unroll ~= during then fail(scenario, "the arrival of the next favour played over the confirmation of the last") end
end)

withTree("look-letter: a landed buff flashes the seal gold and passes a light, a refusal cracks it and shakes", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	Mock.advance(1)
	FT.settle()
	local g = groups(look, r)
	local s0 = snapshot(g)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local s1 = snapshot(g)
	if s1.flash <= s0.flash then fail(scenario, "a landed buff did not flash the seal") end
	if s1.pass <= s0.pass then fail(scenario, "a landed buff did not pass a light over the paper") end
	if s1.settle <= s0.settle then fail(scenario, "a landed buff did not settle the panel") end
	if s1.shake ~= s0.shake or s1.crack ~= s0.crack or s1.scroll ~= s0.scroll then
		fail(scenario, "a landed buff shook the scroll, cracked the seal or shook the text as a refusal does")
	end
	if not sameColour(look.flash._color, 1.00, 0.86, 0.46) then fail(scenario, "the flash on the seal is not gold") end
	if not (look.sweepWarm._color and look.sweepWarm._color[1] > look.sweepWarm._color[3]) then fail(scenario, "the light over the paper is not warm") end
	-- The light crosses the paper from the seal to the end, inside the paper.
	local move = look.passAnims[1].move
	if not (move._offset and move._offset[1] > look.paperW) then fail(scenario, "the light does not cross the whole paper") end
	if not look.lightClip:DoesClipChildren() then fail(scenario, "the light is not cut at the paper's edges") end
	Mock.advance(1)
	FT.settle()
	local s2 = snapshot(g)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	local s3 = snapshot(g)
	if s3.crack <= s2.crack then fail(scenario, "a refusal did not crack the seal") end
	if s3.flash <= s2.flash then fail(scenario, "a refusal did not flare the seal") end
	if s3.shake <= s2.shake then fail(scenario, "a refusal did not shake the text") end
	if s3.scroll - s2.scroll < 8 then fail(scenario, "a refusal did not shake the scroll's parts") end
	-- Every part of it: the paper, the rods, the shadow, the light, the seal, the
	-- slips and the icon go together, or the scroll comes apart.
	local owners = {}
	for _, group in ipairs(look.shakes) do owners[group._owner] = group end
	for name, obj in pairs({ paper = look.paperFrame, rods = look.rodFrame, light = look.lightFrame, shadow = look.shadowFrame,
		seal = look.sealFrame, slips = look.chipFrame, wax = look.body, icon = r.icon, ["the paper under the seal"] = look.paperL[1][2] }) do
		if not (owners[obj] and owners[obj]._playing) then fail(scenario, "the scroll's " .. name .. " does not shake with it") end
	end
	if s3.pass ~= s2.pass or s3.settle ~= s2.settle then fail(scenario, "a refusal passed the landing's light or settled the panel as if it had landed") end
	local c = look.flash._color
	if not (c and c[1] > 0.9 and c[2] < 0.5 and c[3] < 0.3) then fail(scenario, "the refusal's flare on the seal is not red and amber") end
	-- The scroll's shake is small and sums to nothing, on every part of it.
	for _, group in ipairs(look.shakes) do
		local sum, reach, pos = 0, 0, 0
		for _, a in ipairs(group._anims) do
			local dx = a._offset and a._offset[1] or 0
			sum, pos = sum + dx, pos + dx
			reach = math.max(reach, math.abs(pos))
		end
		if math.abs(sum) > 0.01 or reach > 2.01 then fail(scenario, ("the scroll's shake does not settle (%.1f) or strays %.1f"):format(sum, reach)) end
	end
	-- The seal keeps the refusal's wax and the crack for as long as the outcome stands.
	if not (look.body._color and look.body._color[1] > 0.6 and look.body._color[2] < 0.3) then fail(scenario, "the refused seal is not red-orange") end
	if (look.crack._alpha or 0) < 0.5 then fail(scenario, "the crack is not on the seal during the outcome") end
	Mock.advance(1)
	FT.settle()
	local s4 = snapshot(g)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	local s5 = snapshot(g)
	if s5.land ~= s4.land or s5.reject ~= s4.reject or s5.shake ~= s4.shake or s5.scroll ~= s4.scroll then
		fail(scenario, "a cast nobody confirmed got a flourish, which claims more than the settle path knows")
	end
	-- The crack goes with the outcome.
	Mock.advance(3)
	owe(ns, "Anna Aim")
	tick(ns)
	if (look.crack._alpha or 0) > 0.001 then fail(scenario, "the crack stayed after the outcome") end
	if not sameColour(look.body._color, 0.80, 0.10, 0.13) then fail(scenario, "the seal did not go back to the reason's wax after the outcome") end
end)

withTree("look-letter: Calm is fades only: nothing moves, nothing loops", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
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
	-- Every light parked at nothing, the scroll at rest.
	for _, t in ipairs({ look.glow, look.core, look.flash, look.crack }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a light is left lit on Calm") end
	end
	if (look.sweepFrame._alpha or 0) > 0.001 then fail(scenario, "the light over the paper is left lit on Calm") end
	local sheet = look.paperSheet.points[1]
	if not (sheet and near(sheet[4], 0, 0.01)) then fail(scenario, "the paper is not at rest on Calm") end
end)

withTree("look-letter: owed breathes three times and settles, and stops with the favour", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	if not look.pulse[1]._playing then fail(scenario, "somebody owed on top on Full, and the candle does not breathe") end
	if #look.pulse ~= 2 or not look.pulse[2]._playing then fail(scenario, "the hot core does not breathe with the glow") end
	-- Round: two to three seconds for the glow, the core quicker.
	local glow, core = look.pulse[1]._anims[1]._duration, look.pulse[2]._anims[1]._duration
	for i, group in ipairs(look.pulse) do
		if group._looping ~= "BOUNCE" then fail(scenario, "breath " .. i .. " does not bounce") end
	end
	if not glow or glow * 2 < 2 or glow * 2 > 3 then fail(scenario, ("the owed breath is %.2f s round, not 2 to 3"):format((glow or 0) * 2)) end
	if not (core and core < glow) then fail(scenario, "the core is not quicker than the glow, so the light is regular") end
	-- Warm: a candle's.
	local warm = look.glow._color
	if not (warm and warm[1] > warm[3] + 0.3) then fail(scenario, "the glow is not warm") end
	-- Held as the third breath ends, not a scan later.
	Mock.runTimers(10)
	if look.pulse[1]._playing or looping(look.idle) > 0 then fail(scenario, "the owed breath still loops after its three breaths") end
	if (look.glow._alpha or 0) > 0.001 or (look.core._alpha or 0) > 0.001 then fail(scenario, "after its breaths the glow is not let go") end
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "the scan started the spent breath again") end
	-- A new favour on top takes its own three breaths.
	wipe(ns.owed)
	tick(ns)
	if looping(look.idle) > 0 then fail(scenario, "a loop kept going with nobody owed") end
	owe(ns, "Brannoc Vale")
	tick(ns)
	if not look.pulse[1]._playing then fail(scenario, "a new favour did not breathe") end
	-- Nobody owed while it breathes: the glow goes with the loop.
	wipe(ns.owed)
	tick(ns)
	if look.pulse[1]._playing or (look.glow._alpha or 0) > 0 or (look.core._alpha or 0) > 0 then
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
		if looping(look.idle) > 0 then fail(scenario, ("%d loop(s) on '%s'"):format(looping(look.idle), style)) end
	end
	-- With the icon off the seal still breathes: it is the seal that is lit.
	ns.db.profile.prompt.flashStyle = "pulse"
	ns.db.profile.prompt.showIcon = false
	ns.Prompt:ApplyStyle()
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	tick(ns)
	if not look.pulse[1]._playing then fail(scenario, "with the icon off the seal does not breathe") end
end)

withTree("look-letter: the effects stay inside their time and their room under the text", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local function within(group, limit, what)
		if group and FT.groupLength(group) > limit then
			fail(scenario, ("%s lasts %.2f s, over %.2f"):format(what, FT.groupLength(group), limit))
		end
	end
	for i, group in ipairs(look.unrollGroups) do within(group, 0.45, "the unroll's slide " .. i) end
	for i, group in ipairs(look.stamp) do within(group, 0.45, "the seal's press " .. i) end
	within(look.flashAnims[1], 0.7, "the flash on the seal")
	within(look.passAnims[1], 0.7, "the light over the paper")
	within(look.crackAnims[1], 0.7, "the crack")
	for i, shake in ipairs(look.shakes) do within(shake, 0.35, "the scroll's shake " .. i) end
	-- Every frame of light is beneath the text's frame level.
	local text = r.textLayer._level or 0
	for name, f in pairs({ paper = look.paperFrame, window = look.paperSlide, sheet = look.paperSheet, seal = look.sealFrame,
		shadow = look.shadowFrame, light = look.lightFrame, rods = look.rodFrame, chips = look.chipFrame,
		rows = look.rowFrame, candle = look.glowFrame }) do
		if (f._level or 0) >= text then fail(scenario, name .. " is not beneath the text") end
	end
	-- And in their order: the paper under the shadow under the rods under the slips
	-- under the candle; the rim over the icon's frame.
	local order = { look.paperSheet, look.shadowFrame, look.rodFrame, look.chipFrame, look.glowFrame }
	for i = 1, #order - 1 do
		if not ((order[i]._level or 0) <= (order[i + 1]._level or 0)) then fail(scenario, "the frames of the letter are not in their order (" .. i .. ")") end
	end
	if not ((look.paperSheet._level or 0) > (r.art._level or 0)) or not ((look.sealFrame._level or 0) > (r.art._level or 0)) then
		fail(scenario, "the paper's or the seal's frame is not over art")
	end
	-- The paper under the seal is on art itself, below the icon, whichever frames it
	-- would otherwise be over.
	for c = 1, 3 do
		for i, t in ipairs(look.paperL[c]) do
			if t._parent ~= r.art then fail(scenario, ("a piece of the paper under the seal (%d, %d) is not on art itself"):format(c, i)) end
		end
	end
	-- The right part of the paper is over art (its icon is a region of art): the
	-- paper over the icon would hide it, so none of it is under the icon's room.
	if look.g and look.paperR[1][1]._shown ~= false then
		local icon = rectOf(r.icon)
		for c = 1, 3 do
			for _, t in ipairs(look.paperR[c]) do
				if FT.visible(t) and icon then
					local b = rectOf(t)
					if b and across(b, icon) then fail(scenario, "a piece of the paper over art's frames covers the icon") break end
				end
			end
		end
	end
	-- The light crosses inside the paper: its window is the paper's.
	local clip, sheet = rectOf(look.lightClip), rectOf(look.paperSheet)
	if clip and sheet and not (near(clip[1], sheet[1], 0.05) and near(clip[3], sheet[3], 0.05)) then
		fail(scenario, "the light's window is not the paper's right part")
	end
end)

withTree("look-letter: in a fight no effect touches a protected frame, and none plays when quiet", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
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
	for _, key in ipairs({ "land", "reject", "shake", "settle", "scroll", "crack" }) do
		if s3[key] ~= s2[key] then fail(scenario, "with the prompt kept dim and still in combat the " .. key .. " still played") end
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
end)

withTree("look-letter: every effect stops on a repaint and on a restyle, and parks what it lit", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local g = groups(look, r)
	local function anyPlaying(skip)
		for _, key in ipairs({ "land", "reject", "shake", "unroll", "stamp", "scroll", "crack" }) do
			for _, group in ipairs(g[key]) do
				if group._playing and not (skip and skip[group]) then return true end
			end
		end
		return false
	end
	if not anyPlaying() then fail(scenario, "SKIPPED -- nothing played for the landing") return end
	ns.Prompt:StopFlourishes()
	if anyPlaying() then fail(scenario, "an effect was still playing after a repaint stopped them") end
	-- An unroll begun again while one runs begins from its start, not from rest.
	look:StartUnroll()
	Mock.advance(0.05)
	look:StartUnroll()
	local back = look.unrollBack
	local win2, sheet2, rod2 = look.paperSlide.points[1], look.paperSheet.points[1], look.rodRight.points[1]
	if not (win2 and near(win2[4], look.g.splitX - back, 0.01) and sheet2 and near(sheet2[4], back, 0.01)
		and rod2 and near(rod2[4], look.g.rodR - back, 0.01)) then
		fail(scenario, "an unroll begun while one runs does not start from its start")
	end
	ns.Prompt:StopFlourishes()
	-- An unroll cut short leaves the paper at rest, not half out.
	owe(ns, "Brannoc Vale")
	look:StartUnroll()
	Mock.advance(0.05)
	ns.Prompt:StopFlourishes()
	local sheet, win, rod = look.paperSheet.points[1], look.paperSlide.points[1], look.rodRight.points[1]
	if not (sheet and near(sheet[4], 0, 0.01) and win and near(win[4], look.g.splitX, 0.01) and rod and near(rod[4], look.g.rodR, 0.01)) then
		fail(scenario, "a stopped unroll leaves the paper out of its place")
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if anyPlaying({ [r.settle] = true }) then fail(scenario, "an effect of the Letter was still playing after the look changed") end
	-- Parked at nothing: nothing left lit, nothing left of the Letter shown.
	for _, t in ipairs({ look.glow, look.core, look.flash, look.hilite, look.crack }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a light was left lit after the look changed") end
	end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "a region of the Letter (" .. i .. ") is still shown on glass") break end
	end
end)

-- ------------------------------------------------------------------ 10
-- A fight dims the whole letter and keeps the reason; all of it comes back.
withTree("look-letter: a fight dims the letter, keeps the reason and the ink", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local wax = { look.body._color[1], look.body._color[2], look.body._color[3] }
	local paper0 = look.paperR[2][1]._color
	if (look.glow._alpha or 0) > 0.001 and look.pulse[1]._playing == false then fail(scenario, "the glow is lit with no breath") end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	-- Dimmer: the paper, the rods, the wax, the icon and the text, none see-through.
	local paper = look.paperR[2][1]._color
	if not (paper and paper0 and paper[1] < paper0[1] - 0.05) then fail(scenario, "the paper is not dimmer in a fight") end
	if not (look.rodL[2]._color and look.rodL[2]._color[1] < 0.95) then fail(scenario, "the rods are not dimmer in a fight") end
	if not (look.body._color[1] < wax[1] - 0.05) then fail(scenario, "the wax is not dimmer in a fight") end
	if not (r.icon._color and r.icon._color[1] < 0.9) then fail(scenario, "the icon is not dimmed in a fight") end
	if r.icon._desaturated then fail(scenario, "the icon is greyed in a fight") end
	if (r.icon._alpha or 1) < 0.99 then fail(scenario, "the icon turned see-through in a fight") end
	if (r.textLayer._alpha or 1) < 0.99 then fail(scenario, "the text is made fainter in a fight, on paper that is dim already") end
	if (r.art._alpha or 1) < 0.99 then fail(scenario, "art dimmed whole in a fight") end
	-- The paper is still opaque, and still light enough for the ink.
	for _, t in ipairs({ look.paperR[2][1], look.paperL[1][2] }) do
		if (t._alpha or 1) < 0.99 or (t._color and (t._color[4] or 1) < 0.99) then fail(scenario, "the paper turned see-through in a fight") end
	end
	-- The reason stays: the wax is the owed red, dimmed in proportion.
	local k = look.body._color[1] / wax[1]
	if not (near(look.body._color[2], wax[2] * k, 0.02) and near(look.body._color[3], wax[3] * k, 0.02)) then
		fail(scenario, "the wax lost the reason's colour in a fight")
	end
	-- The glow does not loop in a fight.
	if looping() > 0 then fail(scenario, "something loops in a fight") end
	-- Laid out again during the hold: the hold stays.
	look:Apply(ns.db.profile.prompt, false)
	if not (look.paperR[2][1]._color[1] < paper0[1] - 0.05 and look.body._color[1] < wax[1] - 0.05) then
		fail(scenario, "laying the look out again during the hold dimmed nothing")
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if r.icon._desaturated or not near(r.textLayer._alpha or 1, 1) then fail(scenario, "the fight's dim stayed on after it ended") end
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "the icon stayed dimmed after the fight ended") end
	if not sameColour(look.paperR[2][1]._color, paper0[1], paper0[2], paper0[3], 0.01) then fail(scenario, "the paper stayed dim after the fight ended") end
	-- Leaving during a fight puts the icon back for the next look.
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.inCombat = false
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "leaving the Letter during a fight left the icon dimmed on glass") end
	if r.icon._desaturated then fail(scenario, "leaving the Letter during a fight left the icon grey on glass") end
	if r.textLayer._alpha and r.textLayer._alpha < 0.99 then fail(scenario, "leaving the Letter during a fight left the text dimmed") end
end)

-- ------------------------------------------------------------------ 11
-- The outcome: the name stays, the second line is the verdict, the seal takes
-- the outcome's wax; without a second line the headline.
withTree("look-letter: the outcome keeps the name and writes the verdict under it", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local function said(fs) return (tostring(fs:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not said(r.name):find("Anna", 1, true) then fail(scenario, "the name did not stay on a landed buff: " .. said(r.name)) end
	if not said(r.sub):find("buffed", 1, true) then fail(scenario, "no verdict on the second line: " .. said(r.sub)) end
	local c = look.body._color
	if not (c and c[2] > c[1] and c[2] > c[3]) then fail(scenario, "a landed buff's wax is not green") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not said(r.sub):find("Out of range", 1, true) then fail(scenario, "a refusal's own words are not the verdict: " .. said(r.sub)) end
	c = look.body._color
	if not (c and c[1] > c[2] and c[1] > c[3]) then fail(scenario, "a refusal's wax is not red") end
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

withTree("look-letter: a German client's outcome keeps the name and says the verdict in German", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local name = tostring(r.name:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local sub = tostring(r.sub:GetText())
	if not name:find("Anna", 1, true) then fail(scenario, "the name is gone on a German client: " .. name) end
	if sub:find("buffed", 1, true) then fail(scenario, "the verdict is English on a German client: " .. sub) end
	if sub == "" then fail(scenario, "no verdict on a German client") end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 12
-- Leaving the Letter gives the lines their room back and the icon, the sweep, the
-- rows and the text what they were.
withTree("look-letter: leaving it gives the lines, the icon, the rows and the sweep back", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 2 end)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	for _, row in ipairs(r.rows) do
		if row._parent ~= look.rowFrame then fail(scenario, "SKIPPED -- the rows are not on the letter's frame") return end
	end
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local kit = look.kit
	if kit.fit.room[r.name] ~= nil or kit.fit.room[r.sub] ~= nil then fail(scenario, "glass fits its lines to the room the Letter kept") end
	if r.icon._color and (r.icon._color[2] < 0.99 or r.icon._color[1] < 0.99) then fail(scenario, "the refusal's dim stayed on the icon on glass") end
	if r.textLayer._level ~= r.art._level + kit.TEXT_LEVEL then fail(scenario, "the text's level was not put back") end
	if r.name._justifyH ~= nil and r.name._justifyH ~= "LEFT" then fail(scenario, "the name is not left-justified on glass") end
	if r.icon._mask ~= nil and look.mask._shown ~= false then fail(scenario, "the seal's mask still cuts the icon on glass") end
	for i, row in ipairs(r.rows) do
		if row._parent ~= r.art then fail(scenario, "row " .. i .. " is still on the letter's frame on glass") end
	end
	for i, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "Frame" then fail(scenario, "the Letter's region " .. i .. " is still shown on glass") break end
	end
	-- The face of the text is glass's own: a size the letter chose is not left on.
	if r.name._font and r.name._font.size ~= p.fontSize then fail(scenario, "the name keeps the letter's size on glass: " .. tostring(r.name._font.size)) end
	if r.name._font and tostring(r.name._font.path):find("MORPHEUS", 1, true) then fail(scenario, "the name is still in Morpheus on glass") end
	-- And back again, as new.
	p.style = "letter"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.rodL[1]._shown == false then fail(scenario, "the rods are not shown when the look comes back") end
	if (look.glow._alpha or 0) > 0.99 then fail(scenario, "the glow is left lit when the look comes back") end
	if r.icon._mask ~= look.mask then fail(scenario, "the icon is not cut round when the look comes back") end
	for i, row in ipairs(r.rows) do
		if row._parent ~= look.rowFrame then fail(scenario, "row " .. i .. " is not back on the letter's frame") end
	end
end)

-- ------------------------------------------------------------------ 13
-- The cursor lights the seal, both ways; unlocked, the prompt can still be
-- dragged.
withTree("look-letter: the cursor lights the seal, and unlocked it can still be dragged", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	Mock.advance(0.3)
	FT.settle()
	-- To the light's own strength (HILITE_PEAK), and no further: its colour
	-- carries no alpha, so the fade's end is what the game shows.
	if not near(look.hilite._alpha or 0, 0.20) then fail(scenario, "the cursor on the panel does not light the seal: " .. tostring(look.hilite._alpha)) end
	b.scripts.OnLeave(b)
	Mock.advance(0.5)
	FT.settle()
	if (look.hilite._alpha or 0) > 0.01 then fail(scenario, "the seal's light stays after the cursor leaves") end
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (FT.visible(r.art) and FT.visible(look.rodL[1]) and FT.visible(look.body)) then fail(scenario, "the panel is not shown unlocked") end
	local name = rectOf(r.name)
	local panel = rectOf(r.art)
	if name and panel then
		local n = rel(name, panel)
		if n[1] < look.g.textX - 0.01 or n[3] > look.g.textRight + 0.01 then fail(scenario, "the unlocked prompt's line leaves the paper's text") end
	end
	p.locked = true
end)

-- ------------------------------------------------------------------ 14
-- The paper is opaque at rest and light, the panel colour only tints it; the
-- ink on it is dark enough. Read from the file as the game draws it.
local function readTGA(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	local b = { data:byte(1, 18) }
	if #b < 18 or b[3] ~= 2 or b[17] ~= 32 then return nil end
	local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
	local offset = 18 + b[1]
	return { w = w, h = h, at = function(_, x, y)
		local i = offset + (y * w + x) * 4
		local bb, g, rr, a = data:byte(i + 1, i + 4)
		return rr / 255, g / 255, bb / 255, a / 255
	end }
end

local function linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function lum(c) return 0.2126 * linear(c[1]) + 0.7152 * linear(c[2]) + 0.0722 * linear(c[3]) end

local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- The paper's lines are written across this part of the file (generator: TEXT_U,
-- the middle band).
-- The paper in a fight, which is as dim as it gets (Looks/Letter.lua: DIM_PAPER).
local DIM_PAPER = tonumber((slurp(dir .. "/Looks/Letter.lua") or ""):match("local DIM_PAPER, DIM_SEAL = ([%d%.]+),")) or 0.9

local function paperStats(tint, k)
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Paper.tga")
	if not tga then return nil end
	local values = {}
	local mean = 0
	for y = 16, 47 do
		for x = math.floor(0.30 * tga.w), math.floor(0.92 * tga.w) - 1 do
			local r, g, b = tga:at(x, y)
			local l = lum({ r * tint[1] * k, g * tint[2] * k, b * tint[3] * k })
			values[#values + 1] = l
			mean = mean + l
		end
	end
	table.sort(values)
	return { mean = mean / #values, low = values[math.max(1, math.floor(#values * 0.02))] }
end

withTree("look-letter: the paper is opaque and light, and a panel colour only tints it", ANNA, function(ns, scenario)
	-- The file: opaque across inside its torn edges (the generator's DECKLE_MAX
	-- rows at the top, and the shadow's room more at the bottom; a TGA's rows are
	-- kept from the bottom up).
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Paper.tga")
	if not tga then fail(scenario, "Letter_Paper.tga cannot be read as a 32-bit TGA") return end
	local clear = 0
	for y = 9, tga.h - 7 do
		for x = 0, tga.w - 1 do
			local _, _, _, a = tga:at(x, y)
			if a < 0.995 then clear = clear + 1 end
		end
	end
	if clear > 0 then fail(scenario, clear .. " texels of the paper's file are see-through inside its torn edges") end
	local rod = readTGA(dir .. "/Textures/Letter/Letter_Rod.tga")
	if rod then
		for y = 90, 160, 10 do
			local _, _, _, a = rod:at(math.floor(rod.w / 2), y)
			if a < 0.995 then fail(scenario, "the middle of the rod's shaft is see-through at row " .. y) end
		end
	end
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local function opaque(label)
		for c = 1, 3 do
			for _, set in ipairs({ look.paperL[c], look.paperR[c] }) do
				for i, t in ipairs(set) do
					if FT.visible(t) then
						local a = (t._alpha or 1)
						if a < 0.999 or (t._color and (t._color[4] or 1) < 0.999) then
							fail(scenario, label .. ": a piece of the paper (" .. c .. "," .. i .. ") is see-through")
							return
						end
						local up = t._parent
						while up do
							if (up._alpha or 1) < 0.999 then fail(scenario, label .. ": a frame over the paper is see-through at rest") return end
							up = up._parent
						end
					end
				end
			end
		end
		for _, t in ipairs({ look.body, look.rodL[2], look.rodR[2] }) do
			if (t._alpha or 1) < 0.999 or (t._color and (t._color[4] or 1) < 0.999) then fail(scenario, label .. ": the wax or a rod is see-through") end
		end
	end
	-- Whatever the panel's own opacity, the paper is opaque.
	for _, bg in ipairs({ { 0.04, 0.04, 0.06, 0.88 }, { 0.04, 0.04, 0.06, 0.1 }, { 1, 1, 1, 0 }, { 0.5, 0.2, 0.2, 0.5 } }) do
		p.bgColor = bg
		ns.Prompt:ApplyStyle()
		tick(ns)
		Mock.advance(3)
		FT.settle()
		opaque(("panel %.2f %.2f %.2f %.2f"):format(bg[1], bg[2], bg[3], bg[4]))
	end
	-- Light: the paper's mean luminance is the parchment's by default, and never
	-- under the floor, whatever the panel colour; a chosen colour tints it.
	local d = ns.defaults.profile.prompt.bgColor
	p.bgColor = { d[1], d[2], d[3], d[4] }
	ns.Prompt:ApplyStyle()
	local default = look.paperR[2][1]._color
	if not (default and near(default[1], 1, 0.001) and near(default[2], 1, 0.001) and near(default[3], 1, 0.001)) then
		fail(scenario, "the default panel colour tints the parchment")
	end
	local bare = paperStats({ 1, 1, 1 }, 1)
	if not (bare and bare.mean > 0.60 and bare.mean < 0.85) then fail(scenario, "the parchment's luminance is " .. tostring(bare and bare.mean)) end
	local tints = {
		{ 0, 0, 0, 1 }, { 1, 1, 1, 1 }, { 0.1, 0.1, 0.5, 1 }, { 0.5, 0.1, 0.1, 1 }, { 0.1, 0.5, 0.1, 1 },
		{ 0.86, 0.84, 0.78, 0.92 }, { 0.9, 0.7, 0.2, 1 }, { 0.02, 0.02, 0.9, 1 }, { 0.3, 0.3, 0.3, 1 },
	}
	local first
	for _, bg in ipairs(tints) do
		p.bgColor = bg
		ns.Prompt:ApplyStyle()
		tick(ns)
		local t = look.paperR[2][1]._color
		if not t then fail(scenario, "the paper has no colour") break end
		for c = 1, 3 do
			local piece = look.paperL[c][1]._color
			if piece and not sameColour(piece, t[1], t[2], t[3], 0.001) then fail(scenario, "the paper's pieces are not one tint") end
		end
		local stats = paperStats(t, 1)
		if stats.mean < 0.50 then
			fail(scenario, ("a panel colour of %.2f %.2f %.2f makes the parchment %.2f in luminance, too dark for paper"):format(bg[1], bg[2], bg[3], stats.mean))
		end
		-- The tint is the colour's hue, not its darkness: the dark blue is not darker than the pale.
		first = first or stats.mean
		-- The ground the ink is read on is what the file and the tint make.
		local ink = look.kit.ink
		if ink.lo > stats.low + 0.02 then
			fail(scenario, ("the shared code reads the ink on a ground of %.3f, but the paper's darkest 2%% is %.3f"):format(ink.lo, stats.low))
		end
		if ink.light then fail(scenario, "the Letter's ground is called a dark one") end
	end
	-- The tint carries the hue: a blue panel makes a bluer sheet.
	p.bgColor = { 0.1, 0.1, 0.9, 1 }
	ns.Prompt:ApplyStyle()
	local blue = look.paperR[2][1]._color
	p.bgColor = { 0.9, 0.1, 0.1, 1 }
	ns.Prompt:ApplyStyle()
	local red = look.paperR[2][1]._color
	if not (blue and red and blue[3] > blue[1] and red[1] > red[3]) then fail(scenario, "the panel colour's hue is not in the tint") end
end)

-- Every colour the text can be, against the paper under it (tinted, dimmed for a
-- fight): 4.5:1.
local function codes(text)
	local out = {}
	for hex in tostring(text):gmatch("|c%x%x(%x%x%x%x%x%x)") do
		out[#out + 1] = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
	end
	return out
end

local CLASS_COLOURS = {
	DEATHKNIGHT = "ffc41e3a", DEMONHUNTER = "ffa330c9", DRUID = "ffff7c0a", EVOKER = "ff33937f", HUNTER = "ffaad372",
	MAGE = "ff3fc7eb", MONK = "ff00ff98", PALADIN = "fff48cba", PRIEST = "ffffffff", ROGUE = "fffff468",
	SHAMAN = "ff0070dd", WARLOCK = "ff8788ee", WARRIOR = "ffc69b6d",
}

withTree("look-letter: the ink reads on the paper at 4.5:1, class colours too, tinted or dimmed", ANNA, function(ns, scenario)
	local savedColours = RAID_CLASS_COLORS
	local colours = {}
	for class, str in pairs(CLASS_COLOURS) do colours[class] = { colorStr = str } end
	RAID_CLASS_COLORS = colours
	local ok, err = pcall(function()
		local r, p, look = upIn(ns, scenario)
		if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		local function check(label, colour, ground, minimum)
			if type(colour) ~= "table" or not (colour[1] and colour[2] and colour[3]) then
				fail(scenario, label .. " has no colour to judge")
				return
			end
			local got = ratio(lum(colour), ground)
			if got < minimum then fail(scenario, ("%s is %.2f:1 on the paper, under %.1f"):format(label, got, minimum)) end
		end
		local bgs = { { 0.04, 0.04, 0.06, 0.88 }, { 0, 0, 0, 1 }, { 1, 1, 1, 1 }, { 0.1, 0.1, 0.5, 1 }, { 0.5, 0.1, 0.1, 1 },
			{ 0.86, 0.84, 0.78, 0.92 } }
		for _, bg in ipairs(bgs) do
			p.bgColor = bg
			for _, size in ipairs({ { 220, 44, 13 }, { 320, 58, 17 } }) do
				p.width, p.height, p.fontSize = size[1], size[2], size[3]
				for _, fight in ipairs({ false, true }) do
					Mock.inCombat = fight
					if fight then ns.addon:PLAYER_REGEN_DISABLED() else ns.addon:PLAYER_REGEN_ENABLED() end
					ns.Prompt:ApplyStyle()
					Mock.inCombat = false
					local label = ("%dx%d, panel %.2f %.2f %.2f, %s"):format(size[1], size[2], bg[1], bg[2], bg[3], fight and "fight" or "rest")
					-- The ink is held to the paper's worst case, which is a fight's.
					local ground = paperStats(look.tint, DIM_PAPER).low
					for _, class in ipairs({ "MAGE", "PRIEST", "ROGUE", "WARRIOR", "DEATHKNIGHT", "SHAMAN", "WARLOCK", "HUNTER", "MONK",
						"PALADIN", "DRUID", "EVOKER", "DEMONHUNTER" }) do
						ns.owed["Anna Aim"] = { expires = GetTime() + 300, at = GetTime(), class = class }
						ns.addon:Tick()
						for _, c in ipairs(codes(r.name:GetText())) do
							check(label .. ", the name of a " .. class, c, ground, 4.5)
							-- Every class is a shade of ink, taken towards the look's own
							-- ink before it is darkened: a priest's white is a warm brown,
							-- not the grey that darkening white alone would leave.
							if class == "PRIEST" and not (c[1] > c[3] * 1.12) then
								fail(scenario, ("%s, the name of a PRIEST is a grey (%.2f %.2f %.2f), not a shade of ink"):format(label, c[1], c[2], c[3]))
							end
						end
					end
					-- A colour code of the player's own, a brown that reads at about 3.9:1 on
					-- the parchment and so passes the shared rule's 3:1: held to 4.5 here.
					p.format = "|cff66401c{name}|r"
					ns.addon:Tick()
					local own = codes(r.name:GetText())
					if #own == 0 then fail(scenario, label .. ": the name's own colour code is not in the text") end
					for _, c in ipairs(own) do check(label .. ", a colour code the player wrote", c, ground, 4.5) end
					p.format = ns.defaults.profile.prompt.format
					ns.addon:Tick()
					check(label .. ", the name", r.name._textColor, ground, 4.5)
					check(label .. ", the reason", r.sub._textColor, ground, 4.5)
					for i, row in ipairs(r.rows) do check(label .. ", row " .. i, row._textColor, ground, 4.5) end
					for _, c in ipairs(codes(look.kit.ink.rowReason)) do check(label .. ", a row's reason", c, ground, 4.5) end
					Mock.advance(3)
				end
			end
		end
		-- The reason line leans towards the reason's colour with the stroke of ink on
		-- ("stripe", "both"), and reads on the paper however it leans.
		p.bgColor, p.width, p.height, p.fontSize = { 0.04, 0.04, 0.06, 0.88 }, 220, 44, 13
		for _, mode in ipairs({ "icon", "stripe", "both", "off" }) do
			p.accentMode = mode
			for _, palette in ipairs({ "standard", "colourblind" }) do
				p.reasonPalette = palette
				ns.Prompt:ApplyStyle()
				local worst = paperStats(look.tint, DIM_PAPER).low
				for _, reason in ipairs(REASONS) do
					ns.Prompt:PaintAccent(reason)
					check(("the reason line in %s mode for %s (%s)"):format(mode, reason, palette), r.sub._textColor, worst, 4.5)
				end
			end
		end
		Mock.inCombat = false
	end)
	RAID_CLASS_COLORS = savedColours
	if not ok then error(err, 0) end
end)

-- The ink on the slips, the colours the outcomes write in, the "Drag to move" gold
-- the unlocked prompt shows: all of it dark on the paper.
withTree("look-letter: the outcomes' and the slips' writing reads too", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 2 end)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local ground = paperStats(look.paperR[2][1]._color, 1).low
	local slip = readTGA(dir .. "/Textures/Letter/Letter_Slip.tga")
	local slipLum = 0.8
	if slip then
		local rr, gg, bb = slip:at(32, 14)
		slipLum = lum({ rr, gg, bb })
	end
	local function check(label, colour, ground2)
		if type(colour) ~= "table" then fail(scenario, label .. " has no colour") return end
		local got = ratio(lum(colour), ground2)
		if got < 4.5 then fail(scenario, ("%s is %.2f:1, under 4.5"):format(label, got)) end
	end
	check("the count", r.count._textColor, slipLum)
	check("the key", look.keyText._textColor, slipLum)
	for _, kind in ipairs({ "cast", "failed", "sent" }) do
		Mock.advance(3)
		ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
		check("the name on the " .. kind .. " outcome", r.name._textColor, ground)
		check("the verdict of the " .. kind .. " outcome", r.sub._textColor, ground)
		for _, c in ipairs(codes(r.name:GetText())) do check("a code in the " .. kind .. " headline", c, ground) end
		for _, c in ipairs(codes(r.sub:GetText())) do check("a code in the " .. kind .. " verdict", c, ground) end
	end
	-- The unlocked prompt's gold line and the held lines' greys.
	Mock.advance(3)
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	for _, c in ipairs(codes(r.name:GetText())) do check("a code on the unlocked prompt", c, ground) end
	check("the unlocked prompt's reason", r.sub._textColor, ground)
	p.locked = true
	ns.Prompt:ApplyStyle()
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	for _, c in ipairs(codes(r.name:GetText())) do check("a code on the held prompt", c, ground) end
	for _, c in ipairs(codes(r.sub:GetText())) do check("a code in the held prompt's reason", c, ground) end
	Mock.inCombat = false
end)

-- The constants the look reads the paper by are the paper's: its mean colour, its
-- mean luminance and its darkest 2%, as the file draws them.
withTree("look-letter: the look's idea of its paper is the file's", ANNA, function(_, scenario)
	local source = slurp(dir .. "/Looks/Letter.lua") or ""
	local rgb = { source:match("local PAPER_RGB = { ([%d%.]+), ([%d%.]+), ([%d%.]+) }") }
	local mean, low = source:match("local PAPER_LUM, PAPER_LUM_LOW = ([%d%.]+), ([%d%.]+)")
	if #rgb ~= 3 or not mean then fail(scenario, "PAPER_RGB or PAPER_LUM is not where the test looks for it") return end
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Paper.tga")
	if not tga then fail(scenario, "no paper file") return end
	local sum, n, values = { 0, 0, 0 }, 0, {}
	for y = 16, 47 do
		for x = math.floor(0.30 * tga.w), math.floor(0.92 * tga.w) - 1 do
			local r, g, b = tga:at(x, y)
			sum[1], sum[2], sum[3] = sum[1] + r, sum[2] + g, sum[3] + b
			n = n + 1
			values[#values + 1] = lum({ r, g, b })
		end
	end
	table.sort(values)
	local m = 0
	for _, v in ipairs(values) do m = m + v end
	m = m / n
	for i = 1, 3 do
		if not near(tonumber(rgb[i]), sum[i] / n, 0.004) then fail(scenario, ("PAPER_RGB[%d] is %s, the file's is %.3f"):format(i, rgb[i], sum[i] / n)) end
	end
	if not near(tonumber(mean), m, 0.005) then fail(scenario, ("PAPER_LUM is %s, the file's is %.3f"):format(mean, m)) end
	local p2 = values[math.max(1, math.floor(#values * 0.02))]
	if tonumber(low) > p2 + 0.005 then fail(scenario, ("PAPER_LUM_LOW is %s, over the file's darkest 2%% (%.3f)"):format(low, p2)) end
end)

-- ------------------------------------------------------------------ 15
-- The font: Morpheus on the Latin clients (the Cyrillic cut on a Russian one), the
-- client's own on Korean and Chinese, the player's choice when there is one.
local function fontOf(r) return r.name._font and r.name._font.path end

for _, case in ipairs({
	{ "enUS", "Fonts\\MORPHEUS.TTF" }, { "deDE", "Fonts\\MORPHEUS.TTF" }, { "frFR", "Fonts\\MORPHEUS.TTF" },
	{ "esES", "Fonts\\MORPHEUS.TTF" }, { "itIT", "Fonts\\MORPHEUS.TTF" }, { "ptBR", "Fonts\\MORPHEUS.TTF" },
	{ "ruRU", "Fonts\\MORPHEUS_CYR.TTF" }, { "koKR", false }, { "zhCN", false }, { "zhTW", false },
}) do
	local scenario = "look-letter: the font on a " .. case[1] .. " client"
	withTree(scenario, ANNA, function(ns)
		local LSM = LibStub("LibSharedMedia-3.0")
		LSM:Register("font", "Friz Quadrata TT", [[Fonts\FRIZQT__.TTF]])
		LSM:Register("font", "Arial Narrow", [[Fonts\ARIALN.TTF]])
		local r, p, look = upIn(ns, scenario)
		if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		local face = fontOf(r)
		if case[2] then
			if face ~= case[2] then fail(scenario, "the name is in " .. tostring(face) .. ", not " .. case[2]) end
			for _, fs in ipairs({ r.sub, look.kit.count }) do
				if not (fs._font and fs._font.path == case[2]) then fail(scenario, "a line is not in " .. case[2]) end
			end
			-- The size: a point over the font size for the name, two under for the reason.
			if r.name._font.size ~= p.fontSize + 1 then fail(scenario, "the name is " .. tostring(r.name._font.size) .. " pt, not " .. (p.fontSize + 1)) end
		else
			-- The client's own face: the library's default for a client with no
			-- Friz Quadrata (font.ttf in the mock), unchanged, at the size the player set.
			if face == "Fonts\\MORPHEUS.TTF" or face == "Fonts\\MORPHEUS_CYR.TTF" then fail(scenario, "a client with its own face is written in Morpheus") end
			if r.name._font.size ~= p.fontSize then fail(scenario, "the name is not the size the player set on a client's own face") end
		end
		-- A font the player picked wins, on every client.
		p.font = "Arial Narrow"
		ns.Prompt:ApplyStyle()
		tick(ns)
		if fontOf(r) ~= [[Fonts\ARIALN.TTF]] then fail(scenario, "the font the player chose is not the name's: " .. tostring(fontOf(r))) end
		if r.name._font.size ~= p.fontSize then fail(scenario, "a chosen font is not at the size the player set") end
		p.font = ns.defaults.profile.prompt.font
		ns.Prompt:ApplyStyle()
		tick(ns)
		if case[2] and fontOf(r) ~= case[2] then fail(scenario, "the letter's face did not come back with the default font") end
		LSM.media.font["Friz Quadrata TT"], LSM.media.font["Arial Narrow"] = nil, nil
	end, function() Mock.locale = case[1] end)
end

-- ------------------------------------------------------------------ 16
-- The art: the right size, 32-bit, and every file named in the code ships and is
-- drawn; the generator draws the bytes that ship, twice the same.
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

local DRAWN = { Paper = { 256, 64 }, Rod = { 64, 256 }, Seal = { 128, 128 }, SealRim = { 128, 128 }, SealGloss = { 128, 128 },
	SealShadow = { 128, 128 }, Mark = { 64, 64 }, Mask = { 128, 128 }, Glow = { 128, 128 }, Crack = { 128, 128 },
	Slip = { 64, 32 }, Dot = { 32, 32 }, DotGloss = { 32, 32 }, Rule = { 128, 8 }, Sweep = { 64, 64 },
	Fold = { 32, 32 }, Quill = { 128, 128 }, Flourish = { 128, 32 }, Glint = { 32, 32 }, Candle = { 128, 128 } }

withTree("look-letter: its art is 32-bit, a power of two, and every file is named, shipped and drawn", ANNA, function(_, scenario)
	local names = {}
	local source = slurp(dir .. "/Looks/Letter.lua") or ""
	for name in source:gmatch('tex%([^,]+,[^,]+,[^,]+,%s*"(%u%a+)"') do names[name] = true end
	for name in source:gmatch('ART %.%. "(%u%a+)"') do names[name] = true end
	for name in source:gmatch('ipairs%({ ("%u%a+"[^}]*) }%) do kit%.RingArt') do
		for each in name:gmatch('"(%u%a+)"') do names[each] = true end
	end
	local count = 0
	for name in pairs(names) do
		count = count + 1
		local h = header(dir .. "/Textures/Letter/Letter_" .. name .. ".tga")
		if not h then
			fail(scenario, "Letter_" .. name .. ".tga is named in the look and is not in the package")
		else
			if h.imageType ~= 2 or h.bits ~= 32 then fail(scenario, name .. " is not a 32-bit uncompressed TGA") end
			if h.width > 256 or h.height > 256 then fail(scenario, name .. " is over 256 on a side") end
			if not (powerOfTwo(h.width) and powerOfTwo(h.height)) then fail(scenario, name .. " is not a power of two") end
			if DRAWN[name] and not (h.width == DRAWN[name][1] and h.height == DRAWN[name][2]) then
				fail(scenario, ("%s is %dx%d, not the %dx%d the look is cut from"):format(name, h.width, h.height, DRAWN[name][1], DRAWN[name][2]))
			end
		end
	end
	if count < 20 then fail(scenario, "only " .. count .. " files are named in the look") end
	-- Every shipped file is drawn by the look, and every drawn one ships.
	for name in pairs(DRAWN) do
		if not slurp(dir .. "/Textures/Letter/Letter_" .. name .. ".tga") then fail(scenario, name .. " does not ship") end
		if not names[name] then fail(scenario, name .. " ships but the look never draws it") end
	end
	-- The figures the code cuts the files by are the files'.
	local gen = slurp(dir .. "/tools/make_letter_textures.py") or ""
	local function same(label, luaPattern, genPattern)
		local a = { source:match(luaPattern) }
		local b = { gen:match(genPattern) }
		if #a == 0 or #b == 0 then fail(scenario, label .. ": cannot find the figures to compare") return end
		for i = 1, #a do
			if not near(tonumber(a[i]), tonumber(b[i]), 1e-6) then fail(scenario, ("%s: the look says %s, the generator %s"):format(label, a[i], tostring(b[i]))) end
		end
	end
	same("the seal's radius, the icon's edge", "local SEAL_R, ICON_AT, SEAL_EDGE = ([%d%.]+), ([%d%.]+), [%d%.]+",
		"SEAL_R = ([%d%.]+)\nICON_AT = ([%d%.]+)")
	same("the shadow's zoom", "local SHADOW_ZOOM = ([%d%.]+)", "SHADOW_ZOOM = ([%d%.]+)")
	same("the quill's point", "local QUILL_NIB = { ([%d%.]+) / 128, ([%d%.]+) / 128 }", "QUILL_NIB = %(([%d%.]+), ([%d%.]+)%)")
	same("the room of the sheet's shadow", "local LIFT = ([%d%.]+) / 64", "DECKLE, DECKLE_MAX, LIFT = [%d%.]+, [%d%.]+, ([%d%.]+)")
	-- The edge the look declares for the seal's files is at least as far as the wax goes.
	local edge = tonumber(source:match("local SEAL_R, ICON_AT, SEAL_EDGE = [%d%.]+, [%d%.]+, ([%d%.]+)"))
	local seal = readTGA(dir .. "/Textures/Letter/Letter_Seal.tga")
	if seal and edge then
		-- The farthest point of the wax from the middle is what the look is held to.
		local far = 0
		for y = 0, seal.h - 1 do
			for x = 0, seal.w - 1 do
				local _, _, _, a = seal:at(x, y)
				if a > 0.02 then far = math.max(far, math.sqrt((x + 0.5 - seal.w / 2) ^ 2 + (y + 0.5 - seal.h / 2) ^ 2) / (seal.w / 2)) end
			end
		end
		if far > edge + 0.0005 then fail(scenario, ("the wax goes out to %.3f of the file's half-width, the look says %.3f"):format(far, edge)) end
		if far < edge - 0.07 then fail(scenario, ("the wax goes out to %.3f, the look says %.3f: the seal is held to more room than it needs"):format(far, edge)) end
	end
end)

local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-gen-" .. token .. "-" .. tostring(os.time())
end

withTree("look-letter: tools/make_letter_textures.py is deterministic and draws what ships", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-letter-a", tempDir() .. "-letter-b"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out.
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_letter_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
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
	-- What the generator measures of its paper is what the look reads the ink by.
	local source = slurp(dir .. "/Looks/Letter.lua") or ""
	local rgb = { source:match("local PAPER_RGB = { ([%d%.]+), ([%d%.]+), ([%d%.]+) }") }
	local mean, low = source:match("local PAPER_LUM, PAPER_LUM_LOW = ([%d%.]+), ([%d%.]+)")
	local gMean = tonumber(outA:match("'paper_lum_mean': ([%d%.]+)"))
	local gLow = tonumber(outA:match("'paper_lum_p2': ([%d%.]+)"))
	local gRgb = { outA:match("'paper_mean_rgb': %(([%d%.]+), ([%d%.]+), ([%d%.]+)%)") }
	if not (gMean and gLow and #gRgb == 3 and mean and #rgb == 3) then
		fail(scenario, "the generator does not say what it measured of the paper")
	else
		if not near(gMean, tonumber(mean), 0.003) then fail(scenario, ("the generator measures a mean luminance of %s, the look says %s"):format(gMean, mean)) end
		if tonumber(low) > gLow + 0.002 then fail(scenario, ("the generator measures the darkest 2%% at %s, the look reads the ink on %s"):format(gLow, low)) end
		for i = 1, 3 do
			if not near(tonumber(gRgb[i]), tonumber(rgb[i]), 0.003) then fail(scenario, "the generator's mean paper colour is not the look's") end
		end
	end
	local expect = 0
	for _ in pairs(DRAWN) do expect = expect + 1 end
	if #files ~= expect then fail(scenario, ("the generator wrote %d files, the look draws %d"):format(#files, expect)) end
	for _, file in ipairs(files) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Letter/" .. file)
		if not one or not two then
			fail(scenario, file .. " was not written")
		elseif one ~= two then
			fail(scenario, file .. " differs between two runs with the same parameters")
		elseif not ships then
			fail(scenario, file .. " is drawn but does not ship")
		elseif not H.sameArt(one, ships) then
			fail(scenario, file .. " does not match the file that ships: run the generator")
		end
		os.remove(a .. "/" .. file)
		os.remove(b .. "/" .. file)
	end
end)

-- ------------------------------------------------------------------ 17
-- The seal is wax first: the spell is pressed into it, a little over half its
-- diameter across (55% to 62%: the wax dominates, with a rim and a ring of its
-- own round the recess), at every size; and the look's figure for the share is
-- the generator's, which draws the recess to it.
withTree("look-letter: the icon is pressed into the wax at a little over half its diameter", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local source = slurp(dir .. "/Looks/Letter.lua") or ""
	local share = tonumber(source:match("local SEAL_R, ICON_AT, SEAL_EDGE = [%d%.]+, ([%d%.]+), [%d%.]+"))
	if not share then fail(scenario, "ICON_AT is not where the test looks for it") return end
	if share < 0.55 or share > 0.62 then
		fail(scenario, ("the icon is %.2f of the wax's diameter, not between 0.55 and 0.62"):format(share))
	end
	local gen = slurp(dir .. "/tools/make_letter_textures.py") or ""
	local drawn = tonumber(gen:match("\nICON_AT = ([%d%.]+)\n"))
	if not (drawn and near(drawn, share, 1e-6)) then fail(scenario, "the generator draws the recess to " .. tostring(drawn) .. ", the look sizes the icon to " .. share) end
	for _, size in ipairs({ { 220, 44, 13 }, { 160, 32, 11 }, { 400, 72, 17 }, { 320, 58, 17 }, { 140, 120, 13 }, { 100, 44, 13 } }) do
		p.width, p.height, p.fontSize = size[1], size[2], size[3]
		ns.Prompt:ApplyStyle()
		tick(ns)
		local box = rectOf(r.icon)
		local d = look.g and look.g.sealD
		if not (box and d and d > 0) then fail(scenario, "no icon or no wax at " .. size[1] .. "x" .. size[2]) return end
		-- The icon is cut to a whole unit, so a unit of rounding either way.
		local k = (box[3] - box[1]) / d
		if k < 0.55 - 1 / d or k > 0.62 + 1 / d then
			fail(scenario, ("at %dx%d the icon is %.2f of the wax's diameter (%.1f of %.1f)"):format(size[1], size[2], k, box[3] - box[1], d))
		end
	end
end)

-- The light on the wax is white: the body and the lip carry the wax's colour
-- and the gloss over them is never tinted, so every tint -- both palettes, a
-- custom marker colour, the outcomes -- reads as wax with a shine, not as a
-- colour with a lighter colour on it. The same for the drops of wax in the
-- list and the ones that pin the slips, which are the seal's wax under their
-- own white light. The files are white light and grey wax with depth in it.
withTree("look-letter: the light on the wax is white whatever the wax is", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	SetBinding("F", COMMAND)
	tick(ns)
	if not (look.countMode and look.keyUp) then fail(scenario, "SKIPPED -- the slips are not up") return end
	local function white(label)
		local lights = { ["the light on the seal"] = look.gloss, ["a drop's light"] = look.dropLights[1],
			["the count pin's light"] = look.countPinLight }
		for name, t in pairs(lights) do
			local c = t._color
			if c and not (near(c[1], 1, 0.001) and near(c[2], 1, 0.001) and near(c[3], 1, 0.001)) then
				fail(scenario, ("%s: %s is tinted (%.2f %.2f %.2f)"):format(label, name, c[1], c[2], c[3]))
			end
		end
		local w = look.body._color
		for i, pin in ipairs(look.pins) do
			if not (w and sameColour(pin._color, w[1], w[2], w[3])) then fail(scenario, label .. ": pin " .. i .. " is not the seal's wax") end
		end
	end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs(REASONS) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			white(reason .. " in the " .. palette .. " set")
		end
	end
	p.reasonPalette, p.accentMode, p.accentByReason, p.accentColor = "standard", "icon", false, { 0.2, 0.9, 0.3, 1 }
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("group")
	white("a custom marker colour")
	p.accentByReason = true
	for _, kind in ipairs({ "cast", "failed", "sent" }) do
		Mock.advance(3)
		ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
		white("the " .. kind .. " outcome")
	end
	Mock.advance(3)
	tick(ns)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	white("a fight")
	-- A fight makes the light fainter, never coloured.
	if not ((look.gloss._alpha or 1) < 0.95) then fail(scenario, "the light on the wax is not fainter in a fight") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	-- Every drop shown has its light shown over it, the same size and place.
	for i, drop in ipairs(look.drops) do
		local light = look.dropLights[i]
		if drop._shown ~= false and FT.visible(drop) then
			if not (light and light._shown ~= false) then
				fail(scenario, "drop " .. i .. " has no light on it")
			else
				local a, b = rectOf(drop), rectOf(light)
				if a and b and not (near(a[1], b[1], 0.05) and near(a[2], b[2], 0.05) and near(a[3], b[3], 0.05) and near(a[4], b[4], 0.05)) then
					fail(scenario, "drop " .. i .. "'s light is not where the drop is")
				end
			end
		elseif light and light._shown ~= false and FT.visible(light) then
			fail(scenario, "drop " .. i .. " is hidden and its light is not")
		end
	end
	-- The count's pin on its slip's corner, with its light on it; the key's slip
	-- has none.
	if look.keyPin or look.keyPinLight then fail(scenario, "the key's slip is pinned with a drop of wax") end
	for _, pair in ipairs({ { look.countPin, look.countPinLight, look.countBox, "the count's" } }) do
		local pin, light, box = rectOf(pair[1]), rectOf(pair[2]), rectOf(pair[3])
		if not (pin and light and box) then
			fail(scenario, pair[4] .. " pin has no place")
		elseif pair[1]._shown == false or not FT.visible(pair[1]) then
			fail(scenario, pair[4] .. " pin is not shown with its slip")
		elseif pair[2]._shown == false or not FT.visible(pair[2]) then
			fail(scenario, pair[4] .. " pin has no light on it")
		else
			local cx, cy = (pin[1] + pin[3]) / 2, (pin[2] + pin[4]) / 2
			if not (cx > box[1] - 1 and cx < box[1] + (box[3] - box[1]) / 2 and cy > box[4] - (box[4] - box[2]) / 2 and cy < box[4] + 1) then
				fail(scenario, pair[4] .. " pin is not on its slip's upper left corner")
			end
			if not (near(pin[1], light[1], 0.05) and near(pin[3], light[3], 0.05)) then fail(scenario, pair[4] .. " pin's light is not on the pin") end
		end
	end
	-- The files: the light is white art (its colour near white wherever it is
	-- seen), and the wax's body is grey art with the depth of wax in it: its
	-- darkest texels well under half of its brightest.
	for _, name in ipairs({ "SealGloss", "DotGloss" }) do
		local tga = readTGA(dir .. "/Textures/Letter/Letter_" .. name .. ".tga")
		if not tga then fail(scenario, name .. " cannot be read") else
			local off, seen2 = 0, 0
			for y = 0, tga.h - 1, 2 do
				for x = 0, tga.w - 1, 2 do
					local rr, gg, bb, a = tga:at(x, y)
					if a > 0.15 then
						seen2 = seen2 + 1
						if rr < 0.92 or gg < 0.88 or bb < 0.80 or math.abs(rr - gg) > 0.12 then off = off + 1 end
					end
				end
			end
			if seen2 == 0 then fail(scenario, name .. " draws nothing") end
			if off > 0 then fail(scenario, ("%d texels of %s are a colour, not a white light"):format(off, name)) end
		end
	end
	for _, name in ipairs({ "Seal", "Dot" }) do
		local tga = readTGA(dir .. "/Textures/Letter/Letter_" .. name .. ".tga")
		if tga then
			local lo, hi, tintedTexels = 1, 0, 0
			for y = 0, tga.h - 1 do
				for x = 0, tga.w - 1 do
					local rr, gg, bb, a = tga:at(x, y)
					if a > 0.9 then
						if math.abs(rr - gg) > 0.01 or math.abs(gg - bb) > 0.01 then tintedTexels = tintedTexels + 1 end
						lo, hi = math.min(lo, rr), math.max(hi, rr)
					end
				end
			end
			if tintedTexels > 0 then fail(scenario, name .. " is not grey art: " .. tintedTexels .. " texels carry a colour") end
			if not (hi >= 0.85 and lo <= hi * 0.45) then
				fail(scenario, ("%s has no depth: its values run %.2f to %.2f"):format(name, lo, hi))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 18
-- The sheet is torn, not cut, and folded. The file's long edges are deckled
-- (see-through texels in its first and last rows) and paper all the way across
-- inside them, the lines stand clear of the tear at every size, the light that
-- crosses keeps inside it, and two folds cross a sheet long enough to have been
-- folded, the second the first mirrored, tinted and dimmed as the sheet is.
-- The first and the last row of the file that is paper all the way across,
-- counted from the top of the picture (a TGA keeps its rows from the bottom up).
local function solidRows(tga)
	local first, last
	for y = 0, tga.h - 1 do
		local solid = true
		for x = 0, tga.w - 1 do
			local _, _, _, a = tga:at(x, y)
			if a < 0.995 then solid = false break end
		end
		if solid then
			first = first or y
			last = y
		end
	end
	if not first then return nil end
	return tga.h - 1 - last, tga.h - 1 - first
end

withTree("look-letter: the sheet is torn at its long edges and the lines stand clear of the tear", LONG, function(ns, scenario)
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Paper.tga")
	if not tga then fail(scenario, "Letter_Paper.tga cannot be read as a 32-bit TGA") return end
	local first, last = solidRows(tga)
	if not (first and last) then fail(scenario, "no row of the paper's file is paper all the way across") return end
	-- Torn: the first rows are not paper all the way across, and neither are the
	-- last, where the sheet's shadow lies under its edge.
	if first < 3 then fail(scenario, "the paper's top edge is cut straight: row " .. first .. " is paper all the way across") end
	if last > tga.h - 5 then fail(scenario, "the paper's bottom edge is cut straight: row " .. last .. " is paper all the way across") end
	if first > 7 or last < tga.h - 11 then
		fail(scenario, ("the tear reaches rows %d to %d of the file's %d, further in than the lines keep clear of"):format(first, last, tga.h))
	end
	local torn = 0
	for x = 0, tga.w - 1 do
		local _, _, _, a = tga:at(x, tga.h - 2)
		if a < 0.5 then torn = torn + 1 end
	end
	if torn < tga.w * 0.2 then fail(scenario, "only " .. torn .. " texels of the paper's second row are see-through: the edge is not deckled") end
	-- The edge wanders: where the top row's paper begins differs from column to column.
	local lo, hi = tga.h, 0
	for x = 8, tga.w - 9, 4 do
		for y = 0, 12 do
			local _, _, _, a = tga:at(x, tga.h - 1 - y)
			if a >= 0.5 then
				lo, hi = math.min(lo, y), math.max(hi, y)
				break
			end
		end
	end
	if hi - lo < 2 then fail(scenario, ("the paper's top edge wanders only %d texel(s)"):format(hi - lo)) end
	-- The lines: inside the rows that are paper all the way across, at every size,
	-- and at the least height the look says two lines need, where they are
	-- closest to the edges.
	local sizes = { { 220, 44, 13 }, { 320, 58, 17 }, { 160, 32, 11 }, { 400, 72, 17 }, { 300, 120, 24 } }
	for _, font in ipairs({ 11, 13, 17, 24 }) do
		sizes[#sizes + 1] = { 260, ns.Looks.list.letter.TwoLineHeight(font), font, true }
	end
	for _, size in ipairs(sizes) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize = size[1], size[2], size[3] end)
		if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		local panel = rectOf(r.art)
		local g = look.g
		local tag = ("%dx%d, %d pt"):format(size[1], size[2], size[3])
		if size[4] and not r.sub:IsShown() then fail(scenario, tag .. ": the least height two lines need shows one") end
		-- The file's rows are g.sy units each from either end (a tall sheet
		-- repeats its middle band between them).
		local top = look.paperTop + first * g.sy
		local bottom = look.paperBottom - (tga.h - 1 - last) * g.sy
		for label, fs in pairs({ name = r.name, reason = r.sub }) do
			local box = fs:IsShown() and rectOf(fs)
			if box then
				local b = rel(box, panel)
				-- The middle of the line and the letters' own height either side of it.
				local mid, half = (b[2] + b[4]) / 2, (select(2, fs:GetFont()) or size[3]) / 2
				if mid - half < top - 0.3 or mid + half > bottom + 0.3 then
					fail(scenario, ("%s: the %s stands in the tear (%.1f to %.1f, the whole paper %.1f to %.1f)"):format(
						tag, label, mid - half, mid + half, top, bottom))
				end
			end
		end
		-- At the least height the two lines are still two: apart by their own heights.
		if size[4] and r.sub:IsShown() then
			local nb, sb = rectOf(r.name), rectOf(r.sub)
			local apart = (nb[2] + nb[4]) / 2 - (sb[2] + sb[4]) / 2
			local need = ((select(2, r.name:GetFont()) or 0) + (select(2, r.sub:GetFont()) or 0)) / 2
			if apart < need - 0.6 then fail(scenario, ("%s: at the least height the two lines meet (%.1f apart, their letters need %.1f)"):format(tag, apart, need)) end
		end
		-- The light that crosses keeps inside the torn edges.
		local clip = rectOf(look.lightClip)
		if clip then
			local c = rel(clip, panel)
			if c[2] < look.paperTop + g.b - 0.01 or c[4] > look.paperBottom - g.b + 0.01 then
				fail(scenario, ("%s: the light falls beyond the torn edge (%.1f to %.1f)"):format(tag, c[2], c[4]))
			end
		end
	end
end)

withTree("look-letter: two folds cross the sheet, the second the first mirrored", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local panel = rectOf(r.art)
	local g = look.g
	if #look.folds ~= 2 or #look.foldsC ~= 2 then fail(scenario, "the sheet has " .. #look.folds .. " folds, not two") return end
	local last
	for i, fold in ipairs(look.folds) do
		if not FT.visible(fold) then
			fail(scenario, "fold " .. i .. " is not shown at the default size")
		else
			if fold._parent ~= look.paperSheet then fail(scenario, "fold " .. i .. " is not on the sheet that unrolls") end
			local b = rel(rectOf(fold), panel)
			if b[1] < g.splitX or b[3] > g.rodR then fail(scenario, "fold " .. i .. " is under the seal or the right rod") end
			if b[2] < look.paperTop or b[4] > look.paperBottom then fail(scenario, "fold " .. i .. " runs past the sheet's edge") end
			if last and b[1] < last + 10 then fail(scenario, "the two folds are on top of each other") end
			last = b[3]
			-- The cover carries the fold too, in the same place.
			local c = rectOf(look.foldsC[i])
			local own = rectOf(fold)
			if not (c and near(c[1], own[1], 0.05) and near(c[3], own[3], 0.05) and near(c[2], own[2], 0.05) and near(c[4], own[4], 0.05)) then
				fail(scenario, "the cover's fold " .. i .. " is not where the sheet's is")
			end
		end
	end
	local one, two = look.folds[1]._texCoord, look.folds[2]._texCoord
	if not (two and two[1] > two[2]) or (one and one[1] > one[2]) then fail(scenario, "the second fold is not the first mirrored") end
	-- Tinted and dimmed as the sheet is.
	p.bgColor = { 0.1, 0.1, 0.9, 1 }
	ns.Prompt:ApplyStyle()
	local paper = look.paperR[2][1]._color
	for i, fold in ipairs(look.folds) do
		if not sameColour(fold._color, paper[1], paper[2], paper[3], 0.001) then fail(scenario, "fold " .. i .. " is not the sheet's tint") end
	end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	paper = look.paperR[2][1]._color
	if not sameColour(look.folds[1]._color, paper[1], paper[2], paper[3], 0.001) then fail(scenario, "a fold is not dimmed with the sheet in a fight") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	-- A sheet too short to have been folded has none.
	p.width = 120
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i, fold in ipairs(look.folds) do
		if FT.visible(fold) or FT.visible(look.foldsC[i]) then fail(scenario, "a short sheet is folded (fold " .. i .. ")") end
	end
end)

-- ------------------------------------------------------------------ 19
-- The writing. A favour arriving is written in: everything on the sheet is held
-- back while the scroll unrolls, then the cover (the sheet's right part again,
-- over the text) is drawn off to the right behind the quill's point, and the
-- quill is lifted away and put away. The cover is the paper under it, piece for
-- piece; it is never there before the paper is, nor after the pen has passed.
local function pieceUnder(look, c, r)
	-- The piece of the sheet a piece of the cover lies on: the same row, wherever
	-- its columns were cut.
	local box = rectOf(c)
	for col = 1, 3 do
		local t = look.paperR[col][r]
		if t and FT.visible(t) then
			local b = rectOf(t)
			if b and box[1] >= b[1] - 0.3 and box[3] <= b[3] + 0.3 then return t, b end
		end
	end
end

withTree("look-letter: a favour arriving is written in by the quill, from under a cover that is the paper", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local panel = rectOf(r.art)
	local g = look.g
	local w = look.write
	wipe(ns.owed)
	tick(ns)
	Mock.advance(3)
	tick(ns)
	local function counts()
		return { cover = total(look.coverGroups), pen = plays(look.penGroup), hold = total(look.holds),
			sign = total(look.signGroups), press = total(look.pressAnims), halo = total(look.haloAnims) }
	end
	-- A passer-by on the panel is not written in.
	local c0 = counts()
	Mock.advance(0.4)
	tick(ns)
	local c1 = counts()
	if c1.cover ~= c0.cover or c1.pen ~= c0.pen or c1.hold ~= c0.hold then fail(scenario, "a passer-by on the panel was written in") end
	owe(ns, "Anna Aim")
	tick(ns)
	local c2 = counts()
	if c2.cover - c1.cover < 2 then fail(scenario, "somebody buffing you did not put the cover over the sheet (its window and the copy in it)") end
	if c2.pen <= c1.pen then fail(scenario, "somebody buffing you did not bring the quill down") end
	if c2.hold - c1.hold < 3 then fail(scenario, "the words are not held back while the scroll unrolls") end
	if c2.press <= c1.press then fail(scenario, "the stamp's light did not follow the seal's pressing") end
	if c2.sign ~= c1.sign or c2.halo ~= c1.halo then fail(scenario, "an arrival signed a flourish or glowed as a landing does") end
	-- Held back: the text's own layer, the slips and the rows, for as long as the
	-- unroll runs and no longer than a breath over it.
	local unroll = look.slideB._duration
	local owners = {}
	for _, hold in ipairs(look.holds) do
		owners[hold._owner] = true
		local a = hold._anims[1]
		if not (a and a._kind == "Alpha" and a._fromAlpha == 0 and a._toAlpha == 0) then fail(scenario, "a hold does not hold at nothing") end
		local length = FT.groupLength(hold)
		if length < unroll - 0.001 or length > unroll + 0.05 then
			fail(scenario, ("a hold lasts %.2f s, the unroll %.2f"):format(length, unroll))
		end
	end
	if not (owners[r.textLayer] and owners[look.chipFrame] and owners[look.rowFrame]) then
		fail(scenario, "the words, the slips or the rows are not held back while the scroll unrolls")
	end
	-- The cover: over the text, in a window that cuts it, never before the paper
	-- is there, its copy holding still as the window is drawn off.
	local text = r.textLayer._level or 0
	for name, f in pairs({ cover = look.inkFrame, ["cover's window"] = look.inkSlide, ["cover's copy"] = look.inkSheet, quill = look.quillFrame }) do
		if (f._level or 0) <= text then fail(scenario, "the " .. name .. " is not over the text") end
	end
	if not look.inkSlide:DoesClipChildren() then fail(scenario, "the cover's window does not cut what it holds") end
	if (w.on._startDelay or 0) < unroll - 0.05 then
		fail(scenario, ("the cover is over the sheet before the paper is: it comes at %.2f s, the unroll takes %.2f"):format(w.on._startDelay or 0, unroll))
	end
	if (w.run._startDelay or 0) < unroll - 0.001 then fail(scenario, "the pen sets off before the scroll is open") end
	if not (w.run._offset and w.back._offset and near(w.run._offset[1], -w.back._offset[1], 0.01) and w.run._offset[1] > 20) then
		fail(scenario, "the cover's copy does not hold still as its window is drawn off")
	end
	if not (near(w.run._duration, w.back._duration, 0.001) and near(w.run._startDelay or 0, w.back._startDelay or 0, 0.001)) then
		fail(scenario, "the cover's window and its copy do not keep time")
	end
	-- The pen starts just left of the name and goes as far as the longer line.
	local win = look.inkSlide.points[1]
	if not (win and win[4] <= g.textX and win[4] >= g.textX - 4) then fail(scenario, "the pen does not start at the name") end
	local name, sub = rectOf(r.name), rectOf(r.sub)
	local wide = math.max(r.name:GetUnboundedStringWidth() or 0, r.sub:GetUnboundedStringWidth() or 0)
	if w.run._offset[1] < wide - 0.5 then fail(scenario, ("the pen goes %.1f, the longer line is %.1f"):format(w.run._offset[1], wide)) end
	if win[4] + w.run._offset[1] > g.rodR + 0.01 then fail(scenario, "the pen runs on over the right rod") end
	-- The quill: its point on the pen, going the same way in the same time, the
	-- turns of the wrist summing to nothing, and lifted away at the end.
	if look.quill._shown == false then fail(scenario, "the quill is not on the sheet while it writes") end
	if not (near(w.pen._offset[1], w.run._offset[1], 0.01) and near(w.pen._duration, w.run._duration, 0.001)
		and near(w.pen._startDelay or 0, w.run._startDelay or 0, 0.001)) then
		fail(scenario, "the quill does not go with the pen")
	end
	local q = rectOf(look.quill)
	if q and name then
		local nibX = q[1] + (13 / 128) * (q[3] - q[1])
		local nibY = q[2] + (11 / 128) * (q[4] - q[2])
		if math.abs(nibX - (panel[1] + win[4])) > 0.6 then fail(scenario, "the quill's point is not on the pen") end
		if nibY < name[2] - 2 or nibY > name[4] + 2 then fail(scenario, "the quill's point is not on the name's line") end
	end
	local turns = 0
	for _, turn in ipairs(w.strokes) do
		turns = turns + (turn._degrees or 0)
		if not (turn._origin and turn._origin[1] == "BOTTOMLEFT" and turn._origin[2] > 0) then fail(scenario, "a turn of the quill is not about its point") end
	end
	if math.abs(turns) > 0.01 or #w.strokes < 4 then fail(scenario, ("the quill's turns do not sum to nothing (%s over %d)"):format(tostring(turns), #w.strokes)) end
	if FT.groupLength(look.penGroup) > unroll + 0.60 then
		fail(scenario, ("the quill is on the sheet for %.2f s"):format(FT.groupLength(look.penGroup)))
	end
	for i, group in ipairs(look.coverGroups) do
		if FT.groupLength(group) > unroll + 0.55 then fail(scenario, ("the cover's group %d lasts %.2f s"):format(i, FT.groupLength(group))) end
	end
	-- The cover is the paper under it: every piece of it lies on a piece of the
	-- sheet, cut from the same texels, in the same colour, and none reaches over
	-- the right rod.
	local pieces = 0
	local function same(label)
		for c = 1, 3 do
			for i, t in ipairs(look.paperC[c]) do
				if FT.visible(t) then
					pieces = pieces + 1
					local box = rectOf(t)
					local under, ub = pieceUnder(look, t, i)
					local tc, uc = t._texCoord, under and under._texCoord
					if not under then
						fail(scenario, label .. ": a piece of the cover lies on no piece of the sheet")
						return
					end
					-- The texel under each of its edges is the sheet's there.
					local k = (uc[2] - uc[1]) / (ub[3] - ub[1])
					local u0, u1 = uc[1] + (box[1] - ub[1]) * k, uc[1] + (box[3] - ub[1]) * k
					if not (near(tc[1], u0, 0.002) and near(tc[2], u1, 0.002) and near(tc[3], uc[3], 1e-6) and near(tc[4], uc[4], 1e-6)
						and near(box[2], ub[2], 0.05) and near(box[4], ub[4], 0.05)) then
						fail(scenario, label .. ": a piece of the cover is not the paper under it")
						return
					end
					if not sameColour(t._color, under._color[1], under._color[2], under._color[3], 0.001) then
						fail(scenario, label .. ": the cover is not the paper's colour")
						return
					end
					if rel(box, panel)[3] > g.rodR + 0.3 then
						fail(scenario, label .. ": the cover reaches over the right rod")
						return
					end
				end
			end
		end
	end
	same("at rest")
	if pieces < 3 then fail(scenario, "only " .. pieces .. " pieces of the cover are laid") end
	-- When the pen has passed: the cover at nothing, the quill put away, the
	-- words whole, the window back over the sheet's right part.
	Mock.advance(1.5)
	FT.settle()
	if (look.inkSlide._alpha or 1) > 0.001 then fail(scenario, "the cover is left over the words after the pen has passed") end
	if look.quill._shown ~= false or (look.quill._alpha or 0) > 0.001 then fail(scenario, "the quill is left on the sheet") end
	if (r.textLayer._alpha or 1) < 0.999 then fail(scenario, "the words are left held back") end
	for _, group in ipairs(look.holds) do
		if group._playing then fail(scenario, "a hold is still on after the scroll is open") end
	end
	-- Once: the next scans are the same favour.
	local c3 = counts()
	Mock.advance(0.4)
	tick(ns)
	local c4 = counts()
	if c4.cover ~= c3.cover or c4.pen ~= c3.pen or c4.hold ~= c3.hold then fail(scenario, "the letter was written again on a repaint of the same favour") end
	-- Tinted and dimmed, and with a list hanging on it, the cover is still the paper.
	p.bgColor = { 0.5, 0.1, 0.1, 1 }
	p.showQueue, p.queueRows = true, 3
	ns.Prompt:ApplyStyle()
	tick(ns)
	same("tinted, with a list")
	if (look.inkSlide._alpha or 1) > 0.001 then fail(scenario, "laying the look out again put the cover over the words") end
	-- A repaint about somebody else, mid-writing, lets the words go at once.
	wipe(ns.owed)
	tick(ns)
	Mock.advance(3)
	owe(ns, "Brannoc Vale")
	tick(ns)
	Mock.advance(0.1)
	ns.Prompt:StopFlourishes()
	if (look.inkSlide._alpha or 1) > 0.001 or look.quill._shown ~= false then fail(scenario, "a writing stopped half way leaves the cover or the quill on the sheet") end
	for _, group in ipairs(look.holds) do
		if group._playing then fail(scenario, "a writing stopped half way leaves the words held back") end
	end
	-- Not in a fight, and not on Calm.
	Mock.advance(3)
	wipe(ns.owed)
	tick(ns)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	local c5 = counts()
	owe(ns, "Anna Aim")
	tick(ns)
	local c6 = counts()
	if c6.cover ~= c5.cover or c6.pen ~= c5.pen or c6.hold ~= c5.hold then fail(scenario, "a favour arriving in a fight was written in") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	Mock.advance(3)
	wipe(ns.owed)
	tick(ns)
	local c7 = counts()
	owe(ns, "Anna Aim")
	tick(ns)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local c8 = counts()
	for key, v in pairs(c8) do
		if v ~= c7[key] then fail(scenario, "with Effects on Calm the " .. key .. " still played") end
	end
	if look.swash._shown ~= false and FT.visible(look.swash) then fail(scenario, "Calm signs a landing with a flourish") end
end)

-- ------------------------------------------------------------------ 20
-- The outcomes. A landing glows round the seal and is signed off: the flourish
-- at the reason line's end, in the verdict's ink, written in from its left by
-- the quill, gone with the outcome and never where the verdict's own words need
-- the room. A refusal's crack stays in the wax for as long as the refusal does.
withTree("look-letter: a landing is signed with a flourish and glows, a refusal's crack stays", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local panel = rectOf(r.art)
	local g = look.g
	local w = look.write
	Mock.advance(2)
	FT.settle()
	local sign0, halo0, pen0 = total(look.signGroups), total(look.haloAnims), plays(look.penGroup)
	if look.swash._shown ~= false and FT.visible(look.swash) then fail(scenario, "the flourish is on the sheet with nothing landed") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if total(look.signGroups) - sign0 < 2 then fail(scenario, "a landed buff was not signed with a flourish") end
	if total(look.haloAnims) <= halo0 then fail(scenario, "a landed buff did not glow round the seal") end
	if plays(look.penGroup) <= pen0 then fail(scenario, "the quill did not sign the landing") end
	if not sameColour(look.halo._color, 1.00, 0.86, 0.46) then fail(scenario, "the glow round the seal is not gold") end
	if not FT.visible(look.swash) then fail(scenario, "the flourish is not on the sheet during the landing") end
	-- In the verdict's ink, which reads on the paper.
	local ink = r.sub._textColor
	if not (look.swash._color and ink and sameColour(look.swash._color, ink[1], ink[2], ink[3], 0.001)) then
		fail(scenario, "the flourish is not in the verdict's ink")
	end
	-- Written from its left: the window starts its own width to the left, the copy
	-- that much to the right of it, and the two slide the same way and the other.
	if not look.swashClip:DoesClipChildren() then fail(scenario, "the flourish's window does not cut it") end
	local clip, sheet = look.swashClip.points[1], look.swashSheet.points[1]
	local sw = look.swashW
	if not (clip and sheet and near(clip[4], look.swashX - sw, 0.01) and near(sheet[4], sw, 0.01)) then
		fail(scenario, "the flourish is not written from its left end")
	end
	if not (near(w.open._offset[1], sw, 0.01) and near(w.still._offset[1], -sw, 0.01) and near(w.open._duration, w.still._duration, 0.001)) then
		fail(scenario, "the flourish's window and the stroke in it do not move together")
	end
	if not (near(w.pen._offset[1], sw, 0.01) and near(w.pen._duration, w.open._duration, 0.001)) then fail(scenario, "the quill does not go with the flourish") end
	for i, group in ipairs(look.signGroups) do
		if FT.groupLength(group) > 0.45 then fail(scenario, ("the flourish's group %d lasts %.2f s, most of the outcome"):format(i, FT.groupLength(group))) end
	end
	-- Where it lies: at the reason line's end, right of the verdict, on the paper.
	Mock.advance(0.5)
	FT.settle()
	clip, sheet = look.swashClip.points[1], look.swashSheet.points[1]
	if not (clip and near(clip[4], look.swashX, 0.01) and sheet and near(sheet[4], 0, 0.01)) then fail(scenario, "after it is written the flourish is not at rest") end
	local box, sub = rectOf(look.swash), rectOf(r.sub)
	if box and sub then
		local b = rel(box, panel)
		if b[3] > g.textRight + 0.01 or b[1] < g.textX then fail(scenario, "the flourish leaves the text's room") end
		local used = r.sub:GetUnboundedStringWidth() or 0
		if b[1] < g.textX + used then fail(scenario, "the flourish runs into the verdict") end
		if math.abs((box[2] + box[4]) / 2 - (sub[2] + sub[4]) / 2) > 3 then fail(scenario, "the flourish is not on the reason's line") end
	end
	if look.quill._shown ~= false then fail(scenario, "the quill is left on the sheet after signing") end
	-- Gone with the outcome.
	Mock.advance(3)
	tick(ns)
	if look.swash._shown ~= false then fail(scenario, "the flourish stayed after the outcome") end
	-- A refusal: no flourish, no glow; the crack splits the wax and stays.
	local sign1, halo1 = total(look.signGroups), total(look.haloAnims)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if total(look.signGroups) ~= sign1 or total(look.haloAnims) ~= halo1 then fail(scenario, "a refusal was signed or glowed as a landing does") end
	if look.swash._shown ~= false then fail(scenario, "a refusal carries the landing's flourish") end
	Mock.advance(0.4)
	FT.settle()
	if (look.crack._alpha or 0) < 0.5 then fail(scenario, "the crack does not stay in the wax while the refusal stands: " .. tostring(look.crack._alpha)) end
	Mock.advance(3)
	owe(ns, "Anna Aim")
	tick(ns)
	if (look.crack._alpha or 0) > 0.001 then fail(scenario, "the crack stayed after the refusal") end
	-- A cast nobody confirmed is not signed.
	Mock.advance(1)
	local sign2 = total(look.signGroups)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if total(look.signGroups) ~= sign2 or look.swash._shown ~= false then fail(scenario, "a cast nobody confirmed was signed") end
	-- No second line: no flourish (the headline has the line).
	Mock.advance(3)
	p.showSub = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.swashW then fail(scenario, "with no second line the look still keeps a flourish for it") end
	local sign3 = total(look.signGroups)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if total(look.signGroups) ~= sign3 or (look.swash._shown ~= false and FT.visible(look.swash)) then
		fail(scenario, "a landing with no second line was signed over the headline")
	end
	p.showSub = true
end)

-- A verdict whose own words need the room has it: the flourish steps aside.
withTree("look-letter: the flourish gives way to a verdict that needs its room", ANNA, function(ns, scenario)
	local realMeasure = FT.measure
	FT.measure = function(text, size)
		local letters = select(2, text:gsub("[^\128-\191]", ""))
		return letters * size * 1.6
	end
	local ok, err = pcall(function()
		local r, _, look = upIn(ns, scenario, function(pp) pp.width = 180 end)
		if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		Mock.advance(2)
		FT.settle()
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		if not look.swashW then fail(scenario, "SKIPPED -- this sheet has no room for a flourish at all") return end
		local used = look.kit.fit.drawn[r.sub] or r.sub:GetUnboundedStringWidth() or 0
		if look.textX + used + 6 <= look.swashX then fail(scenario, "SKIPPED -- the verdict leaves the flourish its room") return end
		if look.swash._shown ~= false then fail(scenario, "the flourish is written over the verdict's own words") end
	end)
	FT.measure = realMeasure
	if not ok then error(err, 0) end
end)

-- ------------------------------------------------------------------ 21
-- At rest the lamp catches the wax: one glint, the one loop the look runs with
-- nobody owed, named in `idle`; on the wax, brief, and stopped on Calm, in a
-- fight and when the look goes.
withTree("look-letter: at rest the lamp glints on the wax, and only there and then", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local panel = rectOf(r.art)
	local g = look.g
	if type(look.idle) ~= "table" or #look.idle ~= 1 then fail(scenario, "the look does not name its one loop at rest in `idle`") return end
	local glint = look.idle[1]
	if glint._owner ~= look.glint then fail(scenario, "the loop at rest is not the glint's") end
	if glint._looping ~= "REPEAT" then fail(scenario, "the glint does not come round again") end
	if not glint._playing then fail(scenario, "the glint does not play with the prompt up on Full") end
	-- With nobody owed it is the only loop.
	wipe(ns.owed)
	tick(ns)
	Mock.advance(3)
	tick(ns)
	if not glint._playing then fail(scenario, "the glint stops with nobody owed, where it is what moves at rest") end
	if looping(look.idle) > 0 then fail(scenario, "a loop that is not named in `idle` runs with nobody owed") end
	-- Brief: a long wait, then lit for under 0.6 s.
	local wait, lit = math.huge, 0
	for _, a in ipairs(glint._anims) do
		if a._kind == "Alpha" then
			if a._order == 1 then wait = math.min(wait, a._startDelay or 0) end
		end
	end
	lit = FT.groupLength(glint) - wait
	if wait < 3 then fail(scenario, ("the glint comes every %.1f s, which is a blink, not a glint"):format(wait)) end
	if lit > 0.6 then fail(scenario, ("the glint is lit for %.2f s, over 0.6"):format(lit)) end
	if (look.glint._alpha or 0) > 0.001 and not glint._playing then fail(scenario, "the glint is lit with its loop stopped") end
	if look.glint._blend == "ADD" then fail(scenario, "a light that comes round at rest is drawn additive") end
	-- On the wax: where it starts and where it ends.
	local box = rectOf(look.glint)
	local wax = rel(seen(look.body), panel)
	local move = look.glintMove._offset or { 0, 0 }
	if box then
		local b = rel(box, panel)
		local cx, cy = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
		for label, at in pairs({ start = { cx, cy }, ["end"] = { cx + move[1], cy - move[2] } }) do
			local d = math.sqrt((at[1] - g.cx) ^ 2 + (at[2] - g.cy) ^ 2)
			if d > g.sealD / 2 then fail(scenario, ("the glint is not on the wax at its %s (%.1f from the seal's middle, the wax %.1f)"):format(label, d, g.sealD / 2)) end
		end
		if not inside({ b[1], b[2] - math.max(0, move[2]), b[3] + math.max(0, move[1]), b[4] }, { 0, 0, panel[3] - panel[1], panel[4] - panel[2] }) then
			fail(scenario, "the glint leaves the prompt")
		end
		if wax and (b[3] - b[1]) > (wax[3] - wax[1]) * 0.4 then fail(scenario, "the glint is as big as the seal") end
	end
	if not (math.abs(move[1]) > 2 or math.abs(move[2]) > 2) then fail(scenario, "the glint does not cross the wax") end
	-- Stopped in a fight, and back after it.
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if glint._playing then fail(scenario, "the glint goes on in a fight") end
	if (look.glint._alpha or 0) > 0.001 then fail(scenario, "the glint is left lit in a fight") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if not glint._playing then fail(scenario, "the glint does not come back after the fight") end
	-- Stopped on Calm.
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if glint._playing or looping() > 0 then fail(scenario, "the glint goes on with Effects on Calm") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not glint._playing then fail(scenario, "the glint does not come back with Full effects") end
	-- Stopped when the look goes.
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if glint._playing then fail(scenario, "the glint goes on after the look changed") end
	if (look.glint._alpha or 0) > 0.001 then fail(scenario, "the glint is left lit after the look changed") end
end)

-- ------------------------------------------------------------------ 22
-- What a review of the pictures found.

-- Additive light is far brighter in the game than in a picture: it is for a
-- flash, gone within 0.6 s. The candle breathes on the seal for seconds and the
-- cursor's light stays as long as the cursor does, so neither is additive, and
-- their file is hollow where the icon is.
withTree("look-letter: what rests on the seal is not additive, and leaves the spell plain", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	for label, t in pairs({ ["the candle's glow"] = look.glow, ["the candle's hot light"] = look.core, ["the cursor's light"] = look.hilite }) do
		if t._blend == "ADD" then fail(scenario, label .. " rests on the seal and is drawn additive") end
		if tostring(t._file or "") ~= ART .. "Letter_Candle" then fail(scenario, label .. " is not the ring of light that leaves the icon plain: " .. tostring(t._file)) end
	end
	-- Every additive texture of the look is one of its flashes, and each of
	-- those is over within 0.6 s.
	local flashes = { [look.flash] = look.flashAnims, [look.press] = look.pressAnims, [look.halo] = look.haloAnims,
		[look.sweepWhite] = look.passAnims }
	for _, t in ipairs(look.own) do
		if type(t) == "table" and t._blend == "ADD" then
			local anims = flashes[t]
			if not anims then
				fail(scenario, "an additive texture is none of the look's flashes: " .. tostring(t._file))
			else
				for _, group in ipairs(anims) do
					if FT.groupLength(group) > 0.6 + 1e-6 then
						fail(scenario, ("an additive light (%s) is lit for %.2f s, over 0.6"):format(tostring(t._file), FT.groupLength(group)))
					end
				end
			end
		end
	end
	-- The candle's lights are on the wax and in the prompt, the hot one inside
	-- the wide one.
	local panel = rectOf(r.art)
	local glow, core, hover = rectOf(look.glow), rectOf(look.core), rectOf(look.hilite)
	if not (glow and core and hover) then fail(scenario, "the candle's lights are not laid") return end
	if not inside(glow, panel) or not inside(hover, panel) then fail(scenario, "the candle's or the cursor's light leaves the prompt") end
	if not (core[3] - core[1] < glow[3] - glow[1] and core[3] - core[1] > (glow[3] - glow[1]) * 0.7) then
		fail(scenario, "the hot light's ring does not lie on the lip of the recess, inside the wide one's")
	end
	-- The file: a ring, hollow in the middle, nothing at its edge.
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Candle.tga")
	if not tga then fail(scenario, "Letter_Candle.tga cannot be read as a 32-bit TGA") return end
	local mid = select(4, tga:at(tga.w / 2, tga.h / 2))
	local ring = 0
	for x = 0, tga.w / 2 do ring = math.max(ring, (select(4, tga:at(x, tga.h / 2)))) end
	if mid > 0.25 then fail(scenario, ("the candle's light is %.2f over the icon's middle: it would veil the spell"):format(mid)) end
	if ring < 0.7 then fail(scenario, ("the candle's light is only %.2f at its ring"):format(ring)) end
	local edge = 0
	for i = 0, tga.w - 1 do
		edge = math.max(edge, (select(4, tga:at(i, 0))), (select(4, tga:at(i, tga.h - 1))), (select(4, tga:at(0, i))), (select(4, tga:at(tga.w - 1, i))))
	end
	if edge > 0.02 then fail(scenario, "the candle's light is cut at its file's edge") end
end)

-- The spell is what the stamp leaves in the wax. While the wax is poured (it
-- grows from under the icon's size) the icon is not there; it comes with the
-- stamp. By an animation: the shared icon's own alpha is never written.
withTree("look-letter: the spell comes with the stamp, not before the wax is poured", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local struck = look.struck
	if not (struck and struck._owner == r.icon) then fail(scenario, "nothing holds the icon back while the wax is poured") return end
	local inStamp = false
	for _, group in ipairs(look.stamp) do inStamp = inStamp or group == struck end
	if not inStamp then fail(scenario, "the icon's coming is not part of the stamp: it would not play, nor stop, with it") end
	if plays(struck) < 1 then fail(scenario, "a favour arriving did not hold the icon back") end
	-- The wax grows from this share of its size; the icon is this share of it.
	local pour, grow
	for _, group in ipairs(look.stamp) do
		if group._owner == look.body then
			for _, a in ipairs(group._anims) do
				if a._kind == "Scale" then pour, grow = a._duration, a end
			end
		end
	end
	if not pour then fail(scenario, "the wax is not poured") return end
	local hidden, shown = 0, nil
	for _, a in ipairs(struck._anims) do
		if a._kind == "Alpha" and a._order == 1 and a._fromAlpha == 0 and a._toAlpha == 0 then hidden = a._duration end
		if a._kind == "Alpha" and a._order == 2 then shown = a end
	end
	if hidden < pour * 0.5 then fail(scenario, ("the icon stands on the paper %.2f s into a pour of %.2f s"):format(hidden, pour)) end
	if not (shown and shown._fromAlpha == 0 and shown._toAlpha == 1) then fail(scenario, "the icon does not come up to its full strength") end
	if FT.groupLength(struck) > pour + 0.001 then fail(scenario, "the icon is still coming after the wax has set") end
	-- The stamp's light starts as the icon does.
	local press = look.pressAnims[1]
	local lit = press and press._anims[1] and press._anims[1]._startDelay or 0
	if math.abs(lit - hidden) > 0.03 then fail(scenario, ("the stamp's light starts at %.2f s, the icon at %.2f s"):format(lit, hidden)) end
	Mock.advance(1)
	FT.settle()
	if not near(r.icon._alpha or 1, 1) then fail(scenario, "the icon's own alpha was written by the stamp") end
	-- Stopped with the rest of the stamp, and never on Calm.
	local before = plays(struck)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	wipe(ns.owed)
	tick(ns)
	Mock.advance(3)
	owe(ns, "Anna Aim")
	tick(ns)
	if plays(struck) ~= before then fail(scenario, "the icon is held back on Calm, where nothing moves") end
end)

-- The light that crosses the paper at a landing starts whole, beside the seal,
-- and its file is soft on all four sides: slid in through its window's edge and
-- cut at the torn edges, it was a block of light with ruled sides.
withTree("look-letter: the landing's light starts whole and is soft on every side", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local clip, band = rectOf(look.lightClip), rectOf(look.sweepFrame)
	if not (clip and band) then fail(scenario, "the light is not laid") return end
	if band[1] < clip[1] - 0.01 then
		fail(scenario, ("the light starts %.1f units outside its window, whose edge cuts it as it comes in"):format(clip[1] - band[1]))
	end
	if band[3] > clip[3] + 0.01 then fail(scenario, "the light is wider than the paper it crosses") end
	local move = look.passAnims[1].move
	if not (move._offset and band[1] + move._offset[1] >= clip[3]) then fail(scenario, "the light does not run off the paper's end") end
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Sweep.tga")
	if not tga then fail(scenario, "Letter_Sweep.tga cannot be read as a 32-bit TGA") return end
	local edge, peak = 0, 0
	for i = 0, tga.w - 1 do
		edge = math.max(edge, (select(4, tga:at(i, 0))), (select(4, tga:at(i, tga.h - 1))), (select(4, tga:at(0, i))), (select(4, tga:at(tga.w - 1, i))))
		peak = math.max(peak, (select(4, tga:at(i, tga.h / 2))))
	end
	if edge > 0.03 then fail(scenario, ("the light's file is %.2f at its edge: the band ends on a ruled line"):format(edge)) end
	if peak < 0.9 then fail(scenario, "the light's file has no band in it") end
end)

-- The file's rows are never drawn much larger than its columns: a tall prompt,
-- and a short tall one, repeat the middle band (which was drawn to repeat).
withTree("look-letter: a tall or a short sheet repeats its paper and does not pull it out", ANNA, function(ns, scenario)
	for _, size in ipairs({ { 220, 44, 13 }, { 320, 58, 17 }, { 300, 120, 24 }, { 140, 120, 13 }, { 500, 120, 13 }, { 80, 36, 24 } }) do
		local _, _, look = upIn(ns, scenario, function(pp) pp.width, pp.height, pp.fontSize = size[1], size[2], size[3] end)
		if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		local tag = ("%dx%d"):format(size[1], size[2])
		local g = look.g
		if g.sy > 1.001 then fail(scenario, ("%s: a row of the paper's file is drawn %.2f units tall"):format(tag, g.sy)) end
		-- Each piece: its units for each of the file's 64 rows, and, for the
		-- right cap, for each of its 256 columns.
		local tallest, wide = 0, nil
		for c = 1, 3 do
			for _, t in ipairs(look.paperR[c]) do
				local tc, b = t._texCoord, FT.visible(t) and rectOf(t)
				if tc and b and tc[4] > tc[3] then
					tallest = math.max(tallest, (b[4] - b[2]) / ((tc[4] - tc[3]) * 64))
					if tc[2] > 0.99 and tc[2] > tc[1] then wide = (b[3] - b[1]) / ((tc[2] - tc[1]) * 256) end
				end
			end
		end
		if tallest > 1.3 then fail(scenario, ("%s: a piece of the paper is stretched to %.2f units a row"):format(tag, tallest)) end
		if wide and tallest > wide * 1.4 then
			fail(scenario, ("%s: the paper's rows are %.2f units and its columns %.2f: its grain runs in streaks"):format(tag, tallest, wide))
		end
		-- The sheet still reaches from its top to its bottom.
		local top, bottom = math.huge, -math.huge
		for c = 1, 3 do
			for _, t in ipairs(look.paperR[c]) do
				local b = FT.visible(t) and rectOf(t)
				if b then top, bottom = math.min(top, b[2]), math.max(bottom, b[4]) end
			end
		end
		if bottom - top < g.paperH - 0.6 then fail(scenario, ("%s: the pieces cover %.1f of a sheet %.1f tall"):format(tag, bottom - top, g.paperH)) end
	end
end)

-- The Lua stretches the file's middle between its caps, so the generator draws
-- the middle's cockles and fibre closer together: on the screen the sheet is
-- one paper from rod to rod. Drawn evenly, each cap stood out as finer paper.
withTree("look-letter: the sheet is one paper from rod to rod, not finer at its ends", ANNA, function(_, scenario)
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Paper.tga")
	if not tga then fail(scenario, "Letter_Paper.tga cannot be read as a 32-bit TGA") return end
	-- How much the paper changes from one column to the next, in the middle
	-- band: along the stretched middle and along the caps.
	local function busy(x0, x1)
		local sum, n = 0, 0
		for y = 16, 47 do
			for x = x0, x1 - 1 do
				local _, a = tga:at(x, y)
				local _, b = tga:at(x + 1, y)
				sum, n = sum + math.abs(a - b), n + 1
			end
		end
		return sum / n
	end
	local mid, caps = busy(80, 176), (busy(24, 56) + busy(200, 232)) / 2
	if mid < caps * 1.15 then
		fail(scenario, ("the file's middle is no busier (%.4f) than its caps (%.4f): stretched, it is smeared beside them"):format(mid, caps))
	end
end)

-- The wax stands taller than the sheet, and the count's slip is pinned to it:
-- the list's rows begin beyond both, above the prompt as below it.
withTree("look-letter: the list's drops of wax keep clear of the seal and of the count pinned to it", CROWD, function(ns, scenario)
	for _, above in ipairs({ false, true }) do
		for _, size in ipairs({ { 220, 44, 13 }, { 320, 58, 17 } }) do
			-- A prompt low on the screen hangs its list above itself.
			Mock.promptCentreY = above and 40 or nil
			local r, _, look = upIn(ns, scenario, function(pp)
				pp.width, pp.height, pp.fontSize = size[1], size[2], size[3]
				pp.showQueue, pp.queueRows = true, 3
			end)
			if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
			ns.Prompt:ApplyStyle()
			tick(ns)
			local tag = ("%dx%d, the list %s"):format(size[1], size[2], above and "above" or "below")
			if (look.listAt and true or false) ~= above then fail(scenario, tag .. ": the list is not on that side of the prompt") end
			local wax = seen(look.body)
			local slip = FT.visible(look.countSlip[1]) and rectOf(look.countBox)
			local shown = 0
			for i, drop in ipairs(look.drops) do
				local b = FT.visible(drop) and rectOf(drop)
				if b then
					shown = shown + 1
					if wax and across(b, wax) then fail(scenario, ("%s: row %d's drop of wax lies on the seal"):format(tag, i)) end
					if slip and across(b, slip) then fail(scenario, ("%s: row %d's drop of wax lies under the count's slip"):format(tag, i)) end
				end
			end
			if shown < 2 then fail(scenario, tag .. ": the list is not up (" .. shown .. " rows)") end
			if look.countMode == "seal" and not slip then fail(scenario, tag .. ": the count is on the seal and its slip is not") end
		end
	end
end)

-- The glint is the one thing that moves at rest, and the flourish the one mark
-- a landing leaves: both large enough to be seen.
withTree("look-letter: the glint and the flourish are large enough to be seen", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isLetter(look) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	local star, wax = rectOf(look.glint), seen(look.body)
	if not (star and wax) then fail(scenario, "the glint or the wax is not laid") return end
	if (star[3] - star[1]) < (wax[3] - wax[1]) * 0.33 then
		fail(scenario, ("the glint is %.1f units across on a seal of %.1f: a speck"):format(star[3] - star[1], wax[3] - wax[1]))
	end
	-- The flourish is looped: somewhere the pen crosses its own line, so a
	-- column of the file is inked in two places.
	local tga = readTGA(dir .. "/Textures/Letter/Letter_Flourish.tga")
	if not tga then fail(scenario, "Letter_Flourish.tga cannot be read as a 32-bit TGA") return end
	local twice, inked = 0, 0
	for x = 0, tga.w - 1 do
		local runs, on = 0, false
		for y = 0, tga.h - 1 do
			local a = select(4, tga:at(x, y))
			if a > 0.5 and not on then runs, on = runs + 1, true elseif a < 0.2 then on = false end
		end
		if runs >= 2 then twice = twice + 1 end
		if runs >= 1 then inked = inked + 1 end
	end
	if twice < 5 then fail(scenario, "the flourish is a plain wave: the pen never loops back over its line") end
	if inked < tga.w * 0.75 then fail(scenario, "the flourish does not run the length of its file") end
end)
