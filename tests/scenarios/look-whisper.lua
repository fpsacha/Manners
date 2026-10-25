-- The Whisper look (Looks/Whisper.lua): what it promises beyond what every look
-- does, which tests/scenarios/looks.lua, hunt37-effects.lua, hunt25-rows.lua and
-- the others ask of it as well (its key is in their lists).
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows the
-- wrong thing. Every name starts "look-whisper:" so the mutations in
-- tests/mutations/look-whisper.py can name the one that has to catch them.
--
-- What it holds:
--   * it is registered, offered, saved, loaded from the toc after the other
--     looks, and its name has all eight translations;
--   * every state paints without error on all five clients;
--   * the layout: the two lines, the hairline between them, the icon and its
--     frame, the count and the dash never overlap and never leave the panel;
--     the list's names are secure buttons anchored to frames;
--   * the hairline's line draws from its left end and lies clear of the text;
--     every frame of motion is under the text's level; hunt37's loop names it;
--   * the reason is carried by the dash (and the frame, and the hairline) in
--     every reason's colour in both palettes, and by the outcomes' colours;
--   * the motion is quiet: one slow breath while somebody owed waits, nothing
--     that loops on Calm, a fade where the line would draw, the shared shake
--     taken down to two units and put back when the look is left;
--   * the lines stand on the veil at 4.5:1 over snow and over a dusky world.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local REASONS = { "target", "owed", "asked", "group", "nearby", "self" }
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local NAME_KEY = "Whisper -- no box, one hairline in the reason colour"

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

local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.005) end
local function sameColour(c, r, g, b) return c ~= nil and near(c[1], r) and near(c[2], g) and near(c[3], b) end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in Whisper with Anna owed on top: regions, settings, look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "whisper"
	p.effects = "full"
	p.flashStyle = "pulse"
	p.hideInCombat = false
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isWhisper(look)
	return look ~= nil and look.dash ~= nil and look.veil ~= nil and look.lineFrame ~= nil
end

local function box(r)
	local L, R = FT.span(r, "x")
	local B, T = FT.span(r, "y")
	if L and B then return { L, B, R, T } end
	return nil
end

local function plays(g) return g and g._plays or 0 end

local function looping()
	local _, loops = FT.playing()
	return #loops
end

local function errorsSince(ns, from)
	local out = {}
	for i = from + 1, #(ns.errors or {}) do
		local e = ns.errors[i]
		out[#out + 1] = tostring(e.where) .. " -> " .. tostring(e.err)
	end
	return out
end

-- ------------------------------------------------------------------ 1
-- Registered, offered, kept when saved, after the others in the toc, and
-- named in every language.
withTree("look-whisper: it is registered, offered and kept when saved", {}, function(ns, scenario)
	local look = ns.Looks.list.whisper
	if not look then fail(scenario, "no look registered as whisper") return end
	if ns.Looks.Get("whisper") ~= look then fail(scenario, "Looks.Get does not hand Whisper back") end
	local values, sorting = ns.Looks.Choices()
	if type(values.whisper) ~= "string" or values.whisper == "" then fail(scenario, "the Look tab does not offer Whisper") end
	local seen = false
	for _, key in ipairs(sorting) do if key == "whisper" then seen = true end end
	if not seen then fail(scenario, "Whisper is not in the dropdown's order") end
	if values.whisper ~= NAME_KEY and not ns.LOCALE then fail(scenario, "the dropdown's label is " .. tostring(values.whisper)) end
	if values.whisper == values.minimal then fail(scenario, "Whisper is named as Minimal is") end
	if look.fallback then fail(scenario, "Whisper draws as another look") end
	-- The ink and the ground are dimmed apart in a fight, so art stays whole; a
	-- class colour is taken nearly to white so the dash is the only colour.
	if look.combatArtAlpha ~= 1 then fail(scenario, "Whisper lets the fight dim its art as a whole") end
	if not (look.classSoften and look.classSoften >= 0.8) then fail(scenario, "Whisper leaves class-coloured names as they are") end
	-- Never more height than the built-in looks ask for a second line.
	for fontSize = 8, 32 do
		local glass = ns.TwoLineHeight(fontSize, "glass")
		if look.TwoLineHeight(fontSize) ~= glass and look.TwoLineHeight(fontSize) < glass then
			fail(scenario, "Whisper asks for less than glass at font " .. fontSize)
		end
	end
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "whisper"
	ns.ClampSettings()
	if ns.db.profile.prompt.style ~= "whisper" then
		fail(scenario, "a saved Whisper look was reset to " .. tostring(ns.db.profile.prompt.style))
	end
	-- Its file loads after Looks.lua and the three before it, and before Prompt/.
	local files = dofile(dir .. "/tests/addonfiles.lua")(dir)
	local at = {}
	for i, f in ipairs(files) do at[f:gsub("\\", "/")] = i end
	local w = at["Looks/Whisper.lua"]
	if not w then fail(scenario, "Looks/Whisper.lua is not in the toc") return end
	for _, other in ipairs({ "Looks/Looks.lua", "Looks/Luxe.lua", "Looks/Toast.lua", "Looks/Arcane.lua" }) do
		if not (at[other] and at[other] < w) then fail(scenario, "Whisper loads before " .. other) end
	end
	if not (at["Prompt/Prompt.lua"] and w < at["Prompt/Prompt.lua"]) then fail(scenario, "Whisper loads after Prompt/") end
end)

for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
	withTree("look-whisper: its name is translated, in " .. code, {}, function(ns, scenario)
		local text = rawget(ns.L, NAME_KEY)
		if type(text) ~= "string" or text == "" or text == NAME_KEY then
			fail(scenario, "the look's name has no translation in " .. code)
		end
		if ns.Looks.Choices() and select(1, ns.Looks.Choices()).whisper ~= text then
			fail(scenario, "the dropdown does not show the translated name in " .. code)
		end
	end, function() Mock.locale = code end)
end

-- ------------------------------------------------------------------ 2
-- Every state, on every client, with every setting it has to honour.
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
			ns.addon:Tick()
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

for _, flavour in ipairs(FLAVOURS) do
	local scenario = "look-whisper: it paints every state on " .. flavour
	withTree(scenario, CROWD, function(ns)
		local _, p = upIn(ns, scenario)
		local from = #(ns.errors or {})
		local threw = everyState(ns, p)
		if threw then fail(scenario, threw) end
		for _, edit in ipairs({
			{ "second line off", function() p.showSub = false end },
			{ "count off", function() p.showCount = false end },
			{ "icon hidden", function() p.showIcon = false end },
			{ "round icon", function() p.showIcon, p.roundIcon = true, true end },
			{ "colour-blind set", function() p.reasonPalette = "colourblind" end },
			{ "one marker colour", function() p.accentByReason = false end },
			{ "marker off", function() p.accentMode = "off" end },
			{ "stripe only", function() p.accentMode = "stripe" end },
			{ "both", function() p.accentMode = "both" end },
			{ "light panel", function() p.bgColor = { 0.86, 0.84, 0.78, 0.92 } end },
			{ "nearly clear panel", function() p.bgColor = { 0.04, 0.04, 0.06, 0.1 } end },
			{ "big", function() p.width, p.height, p.fontSize, p.iconSize = 320, 58, 17, 40 end },
			{ "small", function() p.width, p.height, p.fontSize, p.iconSize = 180, 40, 11, 26 end },
			{ "scale 0.7", function() p.scale = 0.7 end },
			{ "scale 1.6", function() p.scale = 1.6 end },
			{ "calm", function() p.effects = "calm" end },
		}) do
			local ok, err = pcall(function()
				edit[2]()
				ns.Prompt:ApplyStyle()
				ns.addon:Tick()
				for _, reason in ipairs(REASONS) do ns.Prompt:PaintAccent(reason) end
			end)
			if not ok then fail(scenario, edit[1] .. " threw: " .. tostring(err)) end
			threw = everyState(ns, p)
			if threw then fail(scenario, edit[1] .. ": " .. threw) end
		end
		ns.addon:Tick()
		FT.settle()
		if looping() > 0 then fail(scenario, ("%d animation(s) loop on Calm after every state"):format(looping())) end
		for _, e in ipairs(errorsSince(ns, from)) do fail(scenario, "guarded: " .. e) end
	end, function() Mock.setFlavour(flavour) end)
end

-- ------------------------------------------------------------------ 3
-- The layout: from 160 to 400 wide, 32 to 72 tall, any font and icon, with and
-- without the icon, the second line and the count, a very long name and a
-- long German reason. Nothing overlaps; nothing leaves the panel.
local LONG = { nameplate1 = { "Bartholomewzwanzigsteiner", "Vandermeerenstein" },
	nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" } }
local SIZES = {
	{ 160, 32, 13, 16 }, { 160, 44, 13, 30 }, { 220, 44, 13, 30 }, { 220, 36, 11, 26 }, { 220, 48, 17, 40 },
	{ 320, 58, 17, 40 }, { 400, 72, 17, 64 }, { 400, 32, 13, 22 }, { 160, 72, 24, 44 },
}

local function inside(a, b, margin)
	return a[1] >= b[1] + margin - 1e-6 and a[3] <= b[3] - margin + 1e-6 and a[2] >= b[2] + margin - 1e-6
		and a[4] <= b[4] - margin + 1e-6
end

local function overlap(a, b)
	return a[1] < b[3] - 1e-6 and b[1] < a[3] - 1e-6 and a[2] < b[4] - 1e-6 and b[2] < a[4] - 1e-6
end

local function layoutCheck(ns, scenario, tag, r, p, look)
	local art = box(r.art)
	local name, sub = box(r.name), box(r.sub)
	local function say(text) fail(scenario, tag .. ": " .. text) end
	if not (art and name) then say("the panel or the name could not be placed") return end
	if not inside(name, art, 0) then say("the name leaves the panel") end
	local two = FT.visible(r.sub) and (r.sub:GetText() or "") ~= ""
	if two then
		if not sub then say("the reason line could not be placed") return end
		if not inside(sub, art, 0) then say("the reason line leaves the panel") end
		if overlap(name, sub) then say("the name and the reason line overlap") end
		-- The hairline runs in the gap between them.
		local track = box(look.track)
		if FT.visible(look.track) and track then
			if track[4] > name[2] + 0.01 or track[2] < sub[4] - 0.01 then
				say(("the hairline (%.1f to %.1f) is not between the lines (%.1f and %.1f)"):format(
					track[2], track[4], sub[4], name[2]))
			end
		end
	end
	local icon = box(r.icon)
	if FT.visible(r.icon) and icon then
		if not inside(icon, art, 1) then say("the icon leaves the panel") end
		local ring = box(look.ring)
		if ring then
			if not inside(ring, art, 0) then say("the icon's frame leaves the panel") end
			if ring[3] > name[1] + 0.01 then say("the icon's frame runs into the name") end
			if two and ring[3] > sub[1] + 0.01 then say("the icon's frame runs into the reason line") end
		end
		if icon[3] > name[1] then say("the icon runs into the name") end
	end
	if FT.visible(look.dash) then
		local dash, track = box(look.dash), box(look.track)
		if dash and not inside(dash, art, 0) then say("the dash leaves the panel") end
		if dash and track and (dash[3] > track[3] + 0.01 or math.abs(dash[1] - track[1]) > 0.01) then
			say("the dash is not on the hairline's left end")
		end
		if dash and two and overlap(dash, name) then say("the dash overlaps the name") end
		if dash and two and overlap(dash, sub) then say("the dash overlaps the reason line") end
	end
	if FT.visible(r.count) and (r.count:GetText() or "") ~= "" then
		local count = box(r.count)
		if count then
			if not inside(count, art, 0) then say("the count leaves the panel") end
			if count[1] < name[3] - 0.01 then say("the count overlaps the name") end
			local dot = box(look.countDot)
			if dot and (dot[3] > count[1] + 0.01 or dot[1] < name[3] - 0.01) then say("the count's dot overlaps a neighbour") end
		end
	end
	-- The line that draws, and the cursor's light, lie on the hairline's row.
	for _, f in ipairs({ look.lineFrame, look.hoverFrame }) do
		local fb = box(f)
		if fb and two and (overlap(fb, name) or overlap(fb, sub)) then say("a frame of the hairline's light covers the text") end
		if fb and not inside(fb, art, 0) then say("a frame of the hairline's light leaves the panel") end
	end
end

for _, long in ipairs({ false, true }) do
	local scenario = "look-whisper: nothing overlaps and nothing leaves the panel" .. (long and ", long names and German reasons" or "")
	withTree(scenario, long and LONG or CROWD, function(ns)
		for _, size in ipairs(SIZES) do
			for _, variant in ipairs({
				{ "icon, two lines, list", function(p) end },
				{ "no icon", function(p) p.showIcon = false end },
				{ "one line", function(p) p.showSub = false end },
				{ "round icon, no count", function(p) p.roundIcon, p.showCount = true, false end },
			}) do
				local tag = ("%dx%d font %d icon %d, %s"):format(size[1], size[2], size[3], size[4], variant[1])
				local r, p, look = upIn(ns, scenario, function(pp)
					pp.width, pp.height, pp.fontSize, pp.iconSize = size[1], size[2], size[3], size[4]
					pp.showIcon, pp.roundIcon, pp.showSub, pp.showCount = true, false, true, true
					pp.showQueue, pp.queueRows = true, 3
					variant[2](pp)
				end)
				if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
				if long then
					-- The long name on top, not Anna.
					wipe(ns.owed)
					owe(ns, "Bartholomewzwanzigsteiner Vandermeerenstein")
					Mock.advance(5)
					tick(ns)
					if not tostring(r.name:GetText()):find("Bartholomew", 1, true) then
						fail(scenario, "SKIPPED -- the long name is not on top: " .. tostring(r.name:GetText()))
					end
				end
				layoutCheck(ns, scenario, tag, r, p, look)
				-- Through the outcomes, which rewrite both lines.
				ns.Prompt:ShowOutcome("cast", long and "Bartholomewzwanzigsteiner Vandermeerenstein" or "Anna Aim")
				FT.settle()
				layoutCheck(ns, scenario, tag .. ", landed", r, p, look)
				Mock.advance(2)
				tick(ns)
			end
		end
	end, long and function() Mock.locale = "deDE" end or nil)
end

-- Two lines wherever glass had them, the hairline between: never a profile that
-- showed a second line on glass loses it here.
withTree("look-whisper: it keeps two lines wherever glass had them", ANNA, function(ns, scenario)
	for fontSize = 9, 24, 3 do
		local height = ns.TwoLineHeight(fontSize, "glass")
		local r, p, look = upIn(ns, scenario, function(pp)
			pp.width, pp.height, pp.fontSize, pp.iconSize = 260, height, fontSize, 24
			pp.showSub, pp.showQueue = true, false
		end)
		if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
		if not (r.sub:IsShown() and (r.sub:GetText() or "") ~= "") then
			fail(scenario, ("at font %d and %d tall, where glass has two lines, Whisper has one"):format(fontSize, height))
		end
		layoutCheck(ns, scenario, ("font %d, %d tall"):format(fontSize, height), r, p, look)
		Mock.advance(2)
	end
end)

-- ------------------------------------------------------------------ 4
-- The list: names are buttons anchored to frames (the client refuses a
-- region), each with its dot in the reason's colour; the veil holds the list
-- above or below; the rows keep to the panel's width.
for _, above in ipairs({ false, true }) do
	local scenario = "look-whisper: the list's names are secure buttons on frames, list " .. (above and "above" or "below")
	withTree(scenario, CROWD, function(ns)
		local r, p, look = upIn(ns, scenario, function(pp)
			pp.showQueue, pp.queueRows, pp.clickRows = true, 3, true
			Mock.promptCentreY = above and 40 or 700
		end)
		if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
		local shown = 0
		for i, button in ipairs(r.rowButtons) do
			local text = tostring(r.rows[i]:GetText() or "")
			if text ~= "" then
				shown = shown + 1
				if not button:IsShown() then fail(scenario, "row " .. i .. " reads " .. text .. " and cannot be clicked") end
				for _, pt in ipairs(button.points or {}) do
					local rel = pt[2]
					if type(rel) == "table" and (rel._kind == "FontString" or rel._kind == "Texture" or rel._kind == "MaskTexture") then
						fail(scenario, "row " .. i .. "'s button is anchored to a " .. rel._kind)
					end
				end
				local line, dot = box(r.rows[i]), box(look.dots[i])
				local art = box(r.art)
				if not (line and dot and FT.visible(look.dots[i])) then
					fail(scenario, "row " .. i .. " has no dot")
				else
					if dot[3] > line[1] then fail(scenario, "row " .. i .. "'s dot overlaps its name") end
					local area = box(button)
					if area and (area[1] > dot[1] + 0.01 or area[3] < line[3] - 0.01) then
						fail(scenario, "row " .. i .. "'s click area does not hold its dot and its text")
					end
					if line[3] > art[3] - 8 + 0.01 then fail(scenario, "row " .. i .. " runs to the panel's edge") end
					local colour = look.dots[i]._color
					if not (colour and (colour[1] ~= colour[2] or colour[2] ~= colour[3])) then
						fail(scenario, "row " .. i .. "'s dot is grey, not a reason's colour")
					end
				end
			end
		end
		if shown < 2 then fail(scenario, "SKIPPED -- fewer than two names to test") end
		-- The veil follows the list: its far row hangs from the list's box.
		local veil, tray, art = box(look.veil[7]), box(look.trayBox), box(r.art)
		if not (veil and tray and art) then fail(scenario, "the veil or the list's box could not be placed") return end
		if above then
			if tray[2] < art[4] - 0.01 then fail(scenario, "the list's box is not over the panel") end
			if box(look.veil[1])[4] < tray[4] then fail(scenario, "the veil does not reach over the list") end
		else
			if tray[4] > art[2] + 0.01 then fail(scenario, "the list's box is not under the panel") end
			if veil[2] > tray[2] then fail(scenario, "the veil does not reach under the list") end
		end
		-- No list: the veil is the panel's again.
		p.showQueue = false
		ns.Prompt:ApplyStyle()
		tick(ns)
		local after = box(look.veil[7])
		if after and after[2] < box(r.art)[2] - 30 then fail(scenario, "the veil still holds a list that is gone") end
	end)
end

-- ------------------------------------------------------------------ 5
-- The reason's colour, on the dash, the frame and the hairline, by marker.
withTree("look-whisper: the dash and the frame carry the reason in each palette", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local seen = {}
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs(REASONS) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			if not sameColour(look.dash._color, cr, cg, cb) then
				fail(scenario, ("the dash is not in %s's colour in the %s set"):format(reason, palette))
			end
			if not sameColour(look.ring._color, cr, cg, cb) then
				fail(scenario, ("the icon's frame is not in %s's colour in the %s set"):format(reason, palette))
			end
			if palette == "standard" then seen[reason] = look.dash._color[1] .. ":" .. look.dash._color[2] .. ":" .. look.dash._color[3] end
		end
	end
	-- As many colours on the dash as the palette has: your own buff wears the
	-- group's, so five of six.
	local distinct, count = {}, 0
	for _, key in pairs(seen) do if not distinct[key] then distinct[key] = true count = count + 1 end end
	if count < 5 then fail(scenario, "two reasons share a colour on the dash: " .. count .. " of 5") end
	p.reasonPalette = "standard"
	-- Icon: the frame and the dash. Stripe: the dash alone. Both: the hairline
	-- as well. Off: neither.
	local function paint(mode)
		p.accentMode = mode
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent("asked")
		return ns.Prompt:AccentColor("asked")
	end
	local cr, cg, cb = paint("stripe")
	if not sameColour(look.dash._color, cr, cg, cb) then fail(scenario, "with the marker on the stripe the dash lost the reason") end
	if sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "with the marker on the stripe the icon's frame is in the reason's colour") end
	if sameColour(look.track._color, cr, cg, cb) then fail(scenario, "with the marker on the stripe the hairline is in the reason's colour") end
	cr, cg, cb = paint("both")
	if not (look.track._color and near(look.track._color[1], cr) and near(look.track._color[2], cg)) then
		fail(scenario, "with \"both\" the hairline does not carry the reason")
	end
	cr, cg, cb = paint("off")
	if look.dash._shown ~= false then fail(scenario, "with the marker off the dash is still drawn") end
	if sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "with the marker off the icon's frame still carries a reason") end
	cr, cg, cb = paint("icon")
	if not sameColour(look.dash._color, cr, cg, cb) or not sameColour(look.ring._color, cr, cg, cb) then
		fail(scenario, "back on \"icon\" the marks did not come back")
	end
	-- The carriers the options page reads.
	local icon, stripe = look.AccentCarriers({ accentMode = "stripe", showIcon = true })
	if icon or not stripe then fail(scenario, "AccentCarriers says the wrong thing for the stripe") end
	icon, stripe = look.AccentCarriers({ accentMode = "off", showIcon = true })
	if icon or stripe then fail(scenario, "AccentCarriers says the marker is on when it is off") end
end)

withTree("look-whisper: the outcomes have their own colours on the dash", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	local c = look.dash._color
	if not (c and c[2] > c[1] and c[2] > c[3]) then fail(scenario, "a landed buff's dash is not green") end
	if r.sub:GetText() ~= ns.L["buffed"] then fail(scenario, "the reason line does not say buffed: " .. tostring(r.sub:GetText())) end
	if tostring(r.name:GetText()):find("Anna", 1, true) ~= 1 then fail(scenario, "the name moved for a landed buff") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	FT.settle()
	c = look.dash._color
	if not (c and c[1] >= 0.9 and c[1] > c[2] and c[2] > c[3]) then
		fail(scenario, "a refusal's dash is not red-amber: " .. (c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "none"))
	end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	FT.settle()
	c = look.dash._color
	if not (c and c[1] > c[3] and c[2] > c[3] and near(c[1], 0.91, 0.02)) then fail(scenario, "an unconfirmed cast's dash is not pale gold") end
	-- The next paint of the person takes the reason's colour back.
	Mock.advance(2)
	owe(ns, "Anna Aim")
	tick(ns)
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.dash._color, cr, cg, cb) then fail(scenario, "the dash kept the outcome's colour after it") end
end)

-- ------------------------------------------------------------------ 6
-- Motion. One slow breath while somebody owed waits; nothing loops on Calm; the
-- landing's line draws from the left on Full and fades on Calm; the refusal
-- dips the dash and nudges the text two units, and the shared shake is put
-- back when the look is left.
withTree("look-whisper: the owed breath is one slow loop of the marks' opacity", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	if not look.breathAnim._playing then fail(scenario, "somebody owed on top on Full, and the marks do not breathe") end
	local _, loops = FT.playing()
	if #loops ~= 1 then fail(scenario, ("%d animations loop while somebody owed waits, not one"):format(#loops)) end
	local anim = look.breathAnim._anims[1]
	if not (anim and anim._kind == "Alpha") then fail(scenario, "the breath is not a change of opacity") end
	for _, a in ipairs(look.breathAnim._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "the breath also does a " .. tostring(a._kind)) end
	end
	if anim and anim._duration < 1.2 then fail(scenario, "the breath is faster than a slow one: " .. tostring(anim._duration)) end
	if anim and not (anim._fromAlpha >= 0.3 and anim._toAlpha <= 1 and anim._toAlpha - anim._fromAlpha <= 0.6) then
		fail(scenario, "the breath is not a gentle shift")
	end
	-- Nobody owed: the breath goes, and the marks rest.
	wipe(ns.owed)
	tick(ns)
	if look.breathAnim._playing or looping() > 0 then fail(scenario, "the breath still loops with nobody owed") end
	-- The scan does not start it again for a passer-by.
	tick(ns)
	if look.breathAnim._playing then fail(scenario, "the scan started the breath with nobody owed") end
	-- Calm: held, never a loop.
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	if looping() > 0 then fail(scenario, ("%d animation(s) loop on Calm"):format(looping())) end
	if not near(look.breathFrame._alpha, 1) then fail(scenario, "on Calm the marks are not held at full") end
	-- Flash style none: nothing breathes.
	p.effects, p.flashStyle = "full", "off"
	ns.Prompt:ApplyStyle()
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	tick(ns)
	if look.breathAnim._playing then fail(scenario, "with the flash off the marks breathe") end
end)

withTree("look-whisper: a new face comes up once, never on a repaint", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local before = plays(look.flareAnim)
	if before < 1 then fail(scenario, "somebody owed arrived and the marks did not come up") end
	for _ = 1, 4 do
		Mock.advance(0.4)
		tick(ns)
	end
	if plays(look.flareAnim) > before then fail(scenario, "the marks came up again for the same favour on a repaint") end
	-- A stranger is not a favour.
	wipe(ns.owed)
	tick(ns)
	local after = plays(look.flareAnim)
	for _ = 1, 3 do
		Mock.advance(0.4)
		tick(ns)
	end
	if plays(look.flareAnim) > after then fail(scenario, "the marks came up for a stranger") end
end)

withTree("look-whisper: a landed buff draws a line from the left, a fade on Calm", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local scale
	for _, a in ipairs(look.drawAnim._anims) do if a._kind == "Scale" then scale = a end end
	if not scale then fail(scenario, "the line has no growth to draw it with") return end
	if not (scale._origin and scale._origin[1] == "LEFT") then fail(scenario, "the line does not grow from its left end") end
	if not (scale._scaleFrom and scale._scaleFrom[1] < 0.1 and scale._scaleFrom[2] == 1 and scale._scaleTo[1] == 1) then
		fail(scenario, "the line does not grow along its length alone")
	end
	local total = FT.groupLength(look.drawAnim)
	if total > 0.7 then fail(scenario, "the line takes " .. total .. " s: a landing is under 0.7") end
	local drawn = plays(look.drawAnim)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	if plays(look.drawAnim) ~= drawn + 1 then fail(scenario, "a landed buff did not draw the line once") end
	if plays(look.calmAnim) > 0 then fail(scenario, "a landed buff faded the line as well as drawing it") end
	-- A refusal draws nothing.
	Mock.advance(1)
	local d = plays(look.drawAnim)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.drawAnim) > d then fail(scenario, "a refusal drew the line") end
	-- An unconfirmed cast claims nothing.
	Mock.advance(1)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if plays(look.drawAnim) > d then fail(scenario, "an unconfirmed cast drew the line") end
	-- Calm: a fade where it lies, and no growth anywhere.
	Mock.advance(1)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local grown, faded = plays(look.drawAnim), plays(look.calmAnim)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	if plays(look.drawAnim) > grown then fail(scenario, "on Calm the line was drawn from its end") end
	if plays(look.calmAnim) ~= faded + 1 then fail(scenario, "on Calm the line did not fade in and out") end
	for _, a in ipairs(look.calmAnim._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "Calm's line also does a " .. tostring(a._kind)) end
	end
	-- Quiet in a fight: nothing on the panel moves, Calm's fade included.
	Mock.advance(1)
	p.effects, p.hideInCombat = "calm", true
	ns.Prompt:ApplyStyle()
	tick(ns)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	grown, faded = plays(look.drawAnim), plays(look.calmAnim)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	if plays(look.drawAnim) > grown or plays(look.calmAnim) > faded then fail(scenario, "the line moved in a fight that is to be quiet") end
	Mock.inCombat = false
end)

withTree("look-whisper: a refusal dips the dash and nudges the text two units", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local shake = r.shake
	if not (shake and shake.GetAnimations) then fail(scenario, "SKIPPED -- the shared shake is not there to read") return end
	local biggest, sum = 0, 0
	for _, a in ipairs({ shake:GetAnimations() }) do
		local dx = a:GetOffset()
		biggest = math.max(biggest, math.abs(dx))
		sum = sum + dx
	end
	if biggest > 2.01 then fail(scenario, ("the shake swings %.1f units: Whisper's nudge is two"):format(biggest)) end
	if biggest < 0.5 then fail(scenario, "the shake is gone: a refusal has no nudge") end
	if math.abs(sum) > 0.01 then fail(scenario, "the nudge does not sum to nothing, so the text would not end home") end
	local dips, shakes = plays(look.warnAnim), plays(shake)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	FT.settle()
	if plays(look.warnAnim) ~= dips + 1 then fail(scenario, "a refusal did not dip the dash") end
	if plays(shake) ~= shakes + 1 then fail(scenario, "a refusal did not nudge the text") end
	-- Re-applying the style does not take the nudge down twice.
	ns.Prompt:ApplyStyle()
	ns.Prompt:ApplyStyle()
	biggest = 0
	for _, a in ipairs({ shake:GetAnimations() }) do biggest = math.max(biggest, math.abs((a:GetOffset()))) end
	if biggest < 0.5 or biggest > 2.01 then fail(scenario, "restyling changed the nudge to " .. biggest) end
	-- On Calm nothing nudges and nothing dips.
	Mock.advance(1)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	dips, shakes = plays(look.warnAnim), plays(shake)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.warnAnim) > dips or plays(shake) > shakes then fail(scenario, "a refusal moved on Calm") end
	-- Leaving the look gives the shared shake back as it was.
	p.effects, p.style = "full", "glass"
	ns.Prompt:ApplyStyle()
	local was = { -3, 5, -5, 4, -2, 1 }
	local i = 0
	for _, a in ipairs({ shake:GetAnimations() }) do
		i = i + 1
		if not near((a:GetOffset()), was[i]) then
			fail(scenario, ("the shake's step %d is %.2f on glass, not %d"):format(i, (a:GetOffset()), was[i]))
		end
	end
end)

-- ------------------------------------------------------------------ 7
-- Under the text: every frame of motion is beneath textLayer; hunt37's per-look
-- loops name Whisper, so the rings-and-room rules are held to it.
withTree("look-whisper: every frame of its motion is under the text", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local textLevel = r.textLayer._level or 0
	for name, f in pairs({ flare = look.flareFrame, breath = look.breathFrame, line = look.lineFrame, hover = look.hoverFrame }) do
		if (f._level or 0) >= textLevel then
			fail(scenario, ("the %s frame is at level %d, not under the text's %d"):format(name, f._level or 0, textLevel))
		end
		if (f._level or 0) <= (r.art._level or 0) then fail(scenario, "the " .. name .. " frame is not over the art") end
	end
	local f = io.open(dir .. "/tests/scenarios/hunt37-effects.lua", "rb")
	local text = f and f:read("*a") or ""
	if f then f:close() end
	local list = text:match("local ALL = (%b{})") or ""
	if not list:find('"whisper"', 1, true) then fail(scenario, "hunt37-effects' per-look loops do not name Whisper") end
end)

-- ------------------------------------------------------------------ 8
-- Reads on snow and on a dusky world: the name's colour, the reason line's in
-- every reason and both palettes, and the list's, over the veil as it is laid.
local function lin(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(r, g, b) return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) end
local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end
local function greyOf(l)
	local lo, hi = 0, 1
	for _ = 1, 30 do
		local m = (lo + hi) / 2
		if lin(m) < l then lo = m else hi = m end
	end
	return (lo + hi) / 2
end
local WORLDS = { { "a dusky world", greyOf(0.30) }, { "snow", greyOf(0.85) } }

-- The ground under the text, over a world: the veil's colour and alpha, whole
-- where the text stands.
local function ground(look, world)
	local c = look.veil[5]._color
	local a = c[4]
	return c[1] * a + world * (1 - a), c[2] * a + world * (1 - a), c[3] * a + world * (1 - a)
end

withTree("look-whisper: the lines read on the veil over snow and over a dusky world", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local function check(what, colour, world)
		local gr, gg, gb = ground(look, world[2])
		local got = ratio(luminance(colour[1], colour[2], colour[3]), luminance(gr, gg, gb))
		if got < 4.5 then fail(scenario, ("%s is %.2f:1 over %s"):format(what, got, world[1])) end
	end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		ns.Prompt:ApplyStyle()
		for _, reason in ipairs(REASONS) do
			ns.Prompt:PaintAccent(reason)
			for _, world in ipairs(WORLDS) do
				check(("the reason line for %s (%s set)"):format(reason, palette), r.sub._textColor, world)
			end
		end
	end
	for _, world in ipairs(WORLDS) do
		check("the name", r.name._textColor, world)
		check("a list row", r.rows[1]._textColor, world)
		-- The words after a list row's name, in the look's dimmer grey.
		local code = ns.Prompt.lib.ink.rowReason or ""
		local hex = code:match("|cff(%x%x%x%x%x%x)")
		if hex then
			check("the words after a list row's name", { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
				tonumber(hex:sub(5, 6), 16) / 255 }, world)
		else
			fail(scenario, "the list's reason grey is not a colour code")
		end
	end
	-- Where the text stands is where the veil is whole: inside the panel by the
	-- margin the art keeps (five units, less what the Gaussian leaves).
	local art = box(r.art)
	for _, fs in ipairs({ r.name, r.sub }) do
		local b = box(fs)
		if FT.visible(fs) and b and not inside(b, art, 3) then fail(scenario, "a line of text stands on the veil's edge, not its middle") end
	end
	-- And it is laid over the whole panel, dark enough.
	local v = look.veil[5]._color
	if v[4] < 0.55 then fail(scenario, "the veil is only " .. v[4] .. " opaque") end
end)

-- ------------------------------------------------------------------ 9
-- The cursor, the move handle, the fight, and leaving.
withTree("look-whisper: the hairline lights under the cursor", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local b = ns.Prompt:GetButton()
	local plays0 = plays(look.hoverAnim)
	b.scripts.OnEnter(b)
	if plays(look.hoverAnim) ~= plays0 + 1 then fail(scenario, "the cursor on the panel did not light the hairline") end
	b.scripts.OnLeave(b)
	FT.settle()
	Mock.advance(1)
	FT.settle()
	if not near(look.hoverFrame._alpha, 0) then fail(scenario, "the hairline's light stayed on after the cursor left") end
end)

withTree("look-whisper: unlocked, the move handle is on the panel and visible", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if r.name:GetText() ~= "|cffffd100" .. ns.L["Drag to move"] .. "|r" then
		fail(scenario, "unlocked, the name line does not say how to move it: " .. tostring(r.name:GetText()))
	end
	if not (FT.visible(r.name) and FT.visible(look.veil[5])) then fail(scenario, "the handle's line or its veil is hidden") end
	local button = box(ns.Prompt:GetButton())
	local art = box(r.art)
	if not (button and art and button[1] <= art[1] + 0.01 and button[3] >= art[3] - 0.01) then
		fail(scenario, "the draggable button does not cover the panel")
	end
	if not (r.sub:IsShown() and r.sub:GetText() == ns.L["Let go and it locks itself"]) then fail(scenario, "the second line does not say it locks itself") end
	p.locked = true
	ns.Prompt:ApplyStyle()
end)

withTree("look-whisper: in a fight the reason stays and nothing loops", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if looping() > 0 then fail(scenario, "something loops in a fight") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.dash._color, cr, cg, cb) then fail(scenario, "the dash lost the reason in a fight") end
	if not near(look.breathFrame._alpha, 1) then fail(scenario, "the dash is dimmed in a fight") end
	if not (r.icon._alpha and r.icon._alpha < 1) then fail(scenario, "the icon is not dimmed in a fight") end
	if not (r.name._alpha and r.name._alpha < 1 and r.name._alpha >= 0.7) then fail(scenario, "the name is not a little dimmer in a fight") end
	if (r.sub:GetText() or "") == "" then fail(scenario, "the fight left no reason line") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	Mock.advance(2)
	tick(ns)
	if not near(r.icon._alpha or 1, 1) or not near(r.name._alpha or 1, 1) then fail(scenario, "the ink did not come back after the fight") end
end)

withTree("look-whisper: leaving it gives back everything it borrowed", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.roundIcon, pp.showQueue = true, true end)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(2)
	for _, style in ipairs({ "glass", "minimal", "luxe", "whisper", "framed" }) do
		p.style = style
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		tick(ns)
		if style ~= "whisper" then
			for i, x in ipairs(look.own) do
				if FT.visible(x) then fail(scenario, ("Whisper's region %d still shows under %s"):format(i, style)) break end
			end
			if r.icon._mask == look.mask then fail(scenario, "Whisper's mask still shapes the icon under " .. style) end
			if r.icon._desaturated or not near(r.icon._alpha or 1, 1) then fail(scenario, "the icon kept Whisper's dim under " .. style) end
			if r.count._justifyH and r.count._justifyH ~= "CENTER" then fail(scenario, "the count kept Whisper's alignment under " .. style) end
			if ns.Prompt:LookKit().fit.room[r.sub] ~= nil and style ~= "luxe" then fail(scenario, "the reason line kept Whisper's room under " .. style) end
			if r.shake then
				local biggest = 0
				for _, a in ipairs({ r.shake:GetAnimations() }) do biggest = math.max(biggest, math.abs((a:GetOffset()))) end
				if biggest < 4.9 then fail(scenario, "the shared shake is still Whisper's two units under " .. style) end
			end
		end
	end
end)

-- ------------------------------------------------------------------ 10
-- The scan repaints several times a second: Whisper adds no measuring, no
-- gradient and no re-anchoring to a repaint that changes nothing.
withTree("look-whisper: a repaint that changes nothing measures and anchors nothing", CROWD, function(ns, scenario)
	local r, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local kit = look and look.kit
	if not (isWhisper(look) and kit) then fail(scenario, "Whisper is not the look in use") return end
	ns.addon:Tick()
	local measured, graded, anchored = 0, 0, 0
	local width, gradient = kit.TextWidth, kit.Gradient
	kit.TextWidth = function(...) measured = measured + 1 return width(...) end
	kit.Gradient = function(...) graded = graded + 1 return gradient(...) end
	local watched = { look.dash, look.track, look.ring, look.veil[1], look.veil[5], look.trayBox, look.listRule, look.dots[1],
		look.lineFrame, look.flareFrame, look.breathFrame }
	local clears = {}
	for _, x in ipairs(watched) do
		local clear = x.ClearAllPoints
		clears[x] = clear
		x.ClearAllPoints = function(self, ...) anchored = anchored + 1 return clear(self, ...) end
	end
	for _ = 1, 5 do
		Mock.advance(0.4)
		ns.addon:Tick()
	end
	kit.TextWidth, kit.Gradient = width, gradient
	for x, clear in pairs(clears) do x.ClearAllPoints = clear end
	if measured > 0 or graded > 0 or anchored > 0 then
		fail(scenario, ("five repaints of the same panel measured %d, graded %d and re-anchored %d time(s)")
			:format(measured, graded, anchored))
	end
end)

-- ------------------------------------------------------------------ 11
-- The count: a dot and a number, left out when it would cut the name.
withTree("look-whisper: the count steps aside for a name it would cut", LONG, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.width, pp.height, pp.fontSize, pp.iconSize = 220, 44, 17, 30
		pp.showCount = true
	end)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	wipe(ns.owed)
	owe(ns, "Bartholomewzwanzigsteiner Vandermeerenstein")
	Mock.advance(5)
	tick(ns)
	if not tostring(r.name:GetText()):find("Bartholomew", 1, true) then
		fail(scenario, "SKIPPED -- the long name is not on top: " .. tostring(r.name:GetText()))
	end
	-- Room enough for Prompt to offer the count, too little for the name beside it.
	if FT.visible(r.count) or FT.visible(look.countDot) then fail(scenario, "the count is up over the long name") end
	p.width, p.fontSize = 400, 13
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (FT.visible(look.countDot) and r.count:IsShown()) then fail(scenario, "with room for it the count is not up") end
end)

-- ------------------------------------------------------------------ 12
-- The art: every file the look names ships, 32-bit uncompressed, a power of two
-- up to 256 on each side, and none ships unused.
local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

local function powerOfTwo(n)
	if n < 1 then return false end
	while n % 2 == 0 do n = n / 2 end
	return n == 1
end

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

withTree("look-whisper: its art ships at the right size and none of it is unused", ANNA, function(ns, scenario)
	local source = slurp(dir .. "/Looks/Whisper.lua") or ""
	local named = {}
	for file in source:gmatch('"([A-Z][%w]+)"') do named[file] = (named[file] or 0) + 1 end
	local files = {}
	-- Every .tga in the folder, found through the generator's own list.
	local generator = slurp(dir .. "/tools/make_whisper_textures.py") or ""
	for file in generator:gmatch('save%("Whisper_([%w]+)"') do files[#files + 1] = file end
	if #files < 7 then fail(scenario, "the generator names only " .. #files .. " files") end
	for _, file in ipairs(files) do
		local path = dir .. "/Textures/Whisper/Whisper_" .. file .. ".tga"
		local h = header(path)
		if not h then
			fail(scenario, "Whisper_" .. file .. ".tga is not in the package")
		else
			if h.imageType ~= 2 or h.bits ~= 32 then fail(scenario, file .. " is not a 32-bit uncompressed TGA") end
			if not (powerOfTwo(h.width) and powerOfTwo(h.height)) or h.width > 256 or h.height > 256 then
				fail(scenario, ("%s is %dx%d, not a power of two up to 256"):format(file, h.width, h.height))
			end
		end
		-- Named in the look, directly or as the round and square pair.
		local base = file:gsub("Round$", "")
		if not (named[file] or named[base]) then
			fail(scenario, file .. " ships and the look never draws it")
		end
	end
end)

-- ------------------------------------------------------------------ 13
-- The generator draws the same bytes twice, and the bytes that ship.
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-whisper-" .. token .. "-" .. tostring(os.time())
end

withTree("look-whisper: tools/make_whisper_textures.py is deterministic and draws what ships", ANNA, function(_, scenario)
	local python = os.getenv("MANNERS_PYTHON") or "python"
	local a, b = tempDir() .. "-a", tempDir() .. "-b"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out ("'popen' not supported").
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_whisper_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	-- CI's test job installs lupa only; the generator needs numpy and Pillow,
	-- which every machine that draws the art has, and the full selftest that
	-- judges this check runs there.
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("([%w_]+%.tga)") do names[#names + 1] = file end
	if #names == 0 then fail(scenario, "the generator wrote nothing: " .. outA:sub(1, 200)) return end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Whisper/" .. file)
		-- Never past 256 on a side, always a power of two, 32-bit.
		local h = header(a .. "/" .. file)
		if h and (h.width > 256 or h.height > 256 or not powerOfTwo(h.width) or not powerOfTwo(h.height)
			or h.bits ~= 32 or h.imageType ~= 2) then
			fail(scenario, ("%s is %dx%d at %d bits, type %d: not a power of two up to 256"):format(file, h.width, h.height,
				h.bits, h.imageType))
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
