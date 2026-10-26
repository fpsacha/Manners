-- The Whisper look (Looks/Whisper.lua): what it promises beyond what every look
-- does, which tests/scenarios/looks.lua, hunt37-effects.lua, hunt25-rows.lua and
-- the others ask of it as well (its key is in their lists).
--
-- Whisper is floating type: no box, no square icon. The name stands large on the
-- world, the reason above it in small capitals, a round dot -- the spell icon
-- cut round -- as the bullet. What the look draws is type, a dot, a ring, a
-- line and four corner marks, so what these scenarios hold is where the type
-- stands, that nothing is drawn behind it, that it keeps itself legible with
-- its own outline, and how it moves.
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
--   * the layout: the reason line sits above the name, the dot is round and to
--     the left of both, the count and the key follow the name, the line under
--     the name lies clear of the letters, and nothing overlaps or leaves the
--     panel; the list's names are secure buttons anchored to frames;
--   * there is no rectangle behind the text: no region of the look lies under a
--     line, and the panel's own regions are hidden;
--   * the type is its own legibility: every line is outlined in black, shadowed,
--     and light enough against that edge, over snow and over a dusky world; the
--     fonts are the player's, never a file the look names;
--   * the reason is carried by the reason line and the dot's ring in every
--     reason's colour in both palettes, and by the outcomes' colours; the
--     reason is set in letter-spaced capitals where plain ASCII fits, and left
--     alone where it is not;
--   * the motion is quiet: one slow breath of the dot and the reason while
--     somebody owed waits, nothing that loops on Calm, a fade where the line
--     would draw and the name would rise, the shared shake taken down to two
--     units and put back when the look is left;
--   * unlocked, four corner marks show the move handle, and only then.

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
local COMMAND = "CLICK MannersPrompt:LeftButton"

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

-- A line as a message can carry it: a byte of a letter that is not ASCII, cut loose
-- from the rest, is not valid UTF-8 and would spoil the report.
local function printable(text)
	return (tostring(text):gsub("[\128-\255]", function(c) return ("\\%d"):format(c:byte()) end))
end

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
	return look ~= nil and look.ring ~= nil and look.echoFrame ~= nil and look.lineFrame ~= nil
end

local function box(r)
	local L, R = FT.span(r, "x")
	local B, T = FT.span(r, "y")
	if L and B then return { L, B, R, T } end
	return nil
end

local function plays(g) return g and g._plays or 0 end
local function allPlays(list)
	local n = 0
	for _, g in ipairs(list) do n = n + plays(g) end
	return n
end

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

local function hasKind(group, kind)
	for _, a in ipairs(group._anims) do if a._kind == kind then return true end end
	return false
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
	-- class colour is taken nearly to white so the reason is the only colour.
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
		{ "waiting", function() P:SayWaiting(1.2) end },
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
		Mock.bindings = { F = COMMAND }
		local _, p = upIn(ns, scenario)
		local from = #(ns.errors or {})
		local threw = everyState(ns, p)
		if threw then fail(scenario, threw) end
		for _, edit in ipairs({
			{ "second line off", function() p.showSub = false end },
			{ "count off", function() p.showCount = false end },
			{ "icon hidden", function() p.showIcon = false end },
			{ "round icon", function() p.showIcon, p.roundIcon = true, true end },
			{ "cooldown off", function() p.showCooldown = false end },
			{ "colour-blind set", function() p.reasonPalette = "colourblind" end },
			{ "one marker colour", function() p.accentByReason = false end },
			{ "marker off", function() p.accentMode = "off" end },
			{ "stripe only", function() p.accentMode = "stripe" end },
			{ "both", function() p.accentMode = "both" end },
			{ "light panel", function() p.bgColor = { 0.86, 0.84, 0.78, 0.92 } end },
			{ "nearly clear panel", function() p.bgColor = { 0.04, 0.04, 0.06, 0.1 } end },
			{ "dark font colour", function() p.fontColor = { 0.10, 0.10, 0.12, 1 } end },
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

-- Where the name's letters end: the string's own width from its left edge (its
-- box runs on to the room kept at the right).
local function textEnd(name, fs) return name[1] + fs:GetStringWidth() end

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
		-- The reason is above the name, and both begin at one edge.
		if sub[2] < name[4] - 0.01 then
			say(("the reason line (%.1f to %.1f) is not above the name (%.1f to %.1f)"):format(sub[2], sub[4], name[2], name[4]))
		end
		if math.abs(sub[1] - name[1]) > 0.01 then say("the reason line and the name do not begin at one edge") end
	end
	-- The dot: the icon, round, with its ring; or the plain disc. To the left of
	-- the type, centred on the reason (or the name when there is one line).
	local row = two and sub or name
	local dot
	if FT.visible(r.icon) and box(r.icon) then
		local icon = box(r.icon)
		dot = icon
		if not inside(icon, art, 1) then say("the icon leaves the panel") end
		if math.abs((icon[3] - icon[1]) - (icon[4] - icon[2])) > 0.01 then say("the icon is not square, so the dot is not round") end
		if r.icon._mask ~= look.mask then say("the icon is not cut by the look's mask") end
		if not tostring(look.mask._file):find("Whisper_MaskRound", 1, true) then say("the icon's mask is not the round one") end
		local ring = box(look.ring)
		if FT.visible(look.ring) and ring then
			if not inside(ring, art, 0) then say("the dot's ring leaves the panel") end
			if ring[3] > row[1] + 0.01 then say("the dot's ring runs into the type") end
			local dx = ((ring[1] + ring[3]) - (icon[1] + icon[3])) / 2
			local dy = ((ring[2] + ring[4]) - (icon[2] + icon[4])) / 2
			if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 then say("the ring is not round the icon") end
		end
		if icon[3] > row[1] then say("the icon runs into the type") end
	elseif FT.visible(look.plain) and box(look.plain) then
		dot = box(look.plain)
		if not inside(dot, art, 0) then say("the plain dot leaves the panel") end
		if math.abs((dot[3] - dot[1]) - (dot[4] - dot[2])) > 0.01 then say("the plain dot is not round") end
		if dot[3] > row[1] then say("the plain dot runs into the type") end
	else
		say("there is no dot")
	end
	if dot then
		local middle = (dot[2] + dot[4]) / 2
		if math.abs(middle - (row[2] + row[4]) / 2) > 0.51 then say("the dot is not on the line it leads") end
	end
	-- The count and the key follow the name, small.
	local end_ = textEnd(name, r.name)
	if FT.visible(r.count) and (r.count:GetText() or "") ~= "" then
		local count = box(r.count)
		if count then
			if not inside(count, art, 0) then say("the count leaves the panel") end
			if count[1] < end_ - 0.01 then say("the count overlaps the name") end
			if (r.count._font and r.count._font.size or 99) >= (r.name._font and r.name._font.size or 0) then
				say("the count is not smaller than the name")
			end
		end
	end
	if FT.visible(look.keyText) and (look.keyText:GetText() or "") ~= "" then
		local key = box(look.keyText)
		if key then
			if not inside(key, art, 0) then say(("the key leaves the panel: %.1f to %.1f in %.1f to %.1f, the name ends at %.1f"):format(key[1], key[3], art[1], art[3], end_)) end
			if key[1] < end_ - 0.01 then say("the key overlaps the name") end
			if FT.visible(r.count) and (r.count:GetText() or "") ~= "" then
				local count = box(r.count)
				if count and overlap(key, count) then say("the key and the count overlap") end
			end
		end
	end
	-- The line under the name and the cursor's: below the letters, from their
	-- left edge, inside the panel.
	for _, f in ipairs({ look.lineFrame, look.hoverFrame }) do
		local fb = box(f)
		if fb and (overlap(fb, name) or (two and overlap(fb, sub))) then say("the line under the name covers the type") end
		if fb and not inside(fb, art, 0) then say("the line under the name leaves the panel") end
		if fb and look.lineOn and math.abs(fb[1] - name[1]) > 0.01 then say("the line does not start at the name") end
	end
end

for _, long in ipairs({ false, true }) do
	local scenario = "look-whisper: nothing overlaps and nothing leaves the panel" .. (long and ", long names and German reasons" or "")
	withTree(scenario, long and LONG or CROWD, function(ns)
		Mock.bindings = { F = COMMAND }
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

-- Two lines wherever glass had them: never a profile that showed a second line
-- on glass loses it here.
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

-- The name is the player's size or larger, the reason and the small text
-- smaller than the name: the type has a scale.
withTree("look-whisper: the name is large, the reason small, the list smaller still", CROWD, function(ns, scenario)
	for _, fontSize in ipairs({ 9, 13, 17, 24 }) do
		local r, p, look = upIn(ns, scenario, function(pp)
			pp.fontSize, pp.height, pp.width = fontSize, ns.TwoLineHeight(fontSize, "whisper") + 6, 300
			pp.showQueue, pp.queueRows = true, 3
		end)
		if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
		local nameSize, subSize = r.name._font.size, r.sub._font.size
		if nameSize < fontSize then fail(scenario, ("the name is %d at a font size of %d"):format(nameSize, fontSize)) end
		if nameSize < subSize * 1.3 then
			fail(scenario, ("the name (%d) is not clearly larger than the reason line (%d) at %d"):format(nameSize, subSize, fontSize))
		end
		-- The list's lines at the size they are set (a long row may be shrunk to fit).
		local rowSize = ns.Prompt:LookKit().fit.base[r.rows[1]]
		if rowSize >= nameSize or rowSize < 7 then
			fail(scenario, ("a list line is %d: smaller than the name (%d) was meant"):format(rowSize, nameSize))
		end
		Mock.advance(2)
	end
end)

-- ------------------------------------------------------------------ 4
-- The list: names are buttons anchored to frames (the client refuses a
-- region), each with its dot in the reason's colour under the first dot, and
-- the lines in the reason's column.
for _, above in ipairs({ false, true }) do
	local scenario = "look-whisper: the list's names are secure buttons on frames, list " .. (above and "above" or "below")
	withTree(scenario, CROWD, function(ns)
		local r, p, look = upIn(ns, scenario, function(pp)
			pp.showQueue, pp.queueRows, pp.clickRows = true, 3, true
			Mock.promptCentreY = above and 40 or 700
		end)
		if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
		local shown = 0
		local art = box(r.art)
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
				if not (line and dot and FT.visible(look.dots[i])) then
					fail(scenario, "row " .. i .. " has no dot")
				else
					if dot[3] > line[1] then fail(scenario, "row " .. i .. "'s dot overlaps its name") end
					local area = box(button)
					if area and (area[1] > dot[1] + 0.01 or area[3] < line[3] - 0.01) then
						fail(scenario, "row " .. i .. "'s click area does not hold its dot and its text")
					end
					if line[3] > art[3] - 8 + 0.01 then fail(scenario, "row " .. i .. " runs to the panel's edge") end
					if math.abs(line[1] - box(r.name)[1]) > 0.01 then
						fail(scenario, "row " .. i .. " does not start in the reason's column")
					end
					local colour = look.dots[i]._color
					if not (colour and (colour[1] ~= colour[2] or colour[2] ~= colour[3])) then
						fail(scenario, "row " .. i .. "'s dot is grey, not a reason's colour")
					end
					if math.abs((dot[2] + dot[4]) / 2 - (line[2] + line[4]) / 2) > 0.51 then
						fail(scenario, "row " .. i .. "'s dot is not on its line")
					end
				end
			end
		end
		if shown < 2 then fail(scenario, "SKIPPED -- fewer than two names to test") end
		-- The list hangs from the panel's edge: under it, or over it.
		local first, last = box(r.rows[1]), box(r.rows[shown])
		if above then
			if first[2] < art[4] - 0.01 or last[2] < art[4] - 0.01 then fail(scenario, "the list is not over the panel") end
			if first[2] < last[2] then fail(scenario, "the list does not read from the top") end
		else
			if first[4] > art[2] + 0.01 or last[4] > art[2] + 0.01 then fail(scenario, "the list is not under the panel") end
			if first[4] < last[4] then fail(scenario, "the list does not read downwards") end
		end
		-- No list: the dots go.
		p.showQueue = false
		ns.Prompt:ApplyStyle()
		tick(ns)
		for i, dot in ipairs(look.dots) do
			if FT.visible(dot) then fail(scenario, "dot " .. i .. " is left with no list") end
		end
	end)
end

-- ------------------------------------------------------------------ 5
-- Nothing is drawn behind the type.
withTree("look-whisper: no rectangle, panel or veil lies behind the text", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.showQueue, pp.queueRows = true, 3
		pp.bgColor = { 0.04, 0.04, 0.06, 0.88 }
	end)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	Mock.bindings = { F = COMMAND }
	tick(ns)
	-- The panel's own regions, and everything only the three looks drawn there
	-- use, are hidden.
	for i, part in ipairs(r.builtin) do
		if FT.visible(part) then fail(scenario, ("the built-in part %d is showing under Whisper"):format(i)) break end
	end
	for _, tex in ipairs({ r.panel, r.fill, r.queueBack, r.sheen }) do
		if FT.visible(tex) then fail(scenario, "a panel region is showing under Whisper") end
	end
	-- Every region of the look that draws is out of the text's way, and none is a
	-- sheet: nothing taller than a line's height wide and nothing near the panel's size.
	local texts = {}
	for _, fs in ipairs({ r.name, r.sub, r.count, look.keyText, r.rows[1], r.rows[2], r.rows[3] }) do
		if FT.visible(fs) and (fs:GetText() or "") ~= "" then texts[#texts + 1] = { fs = fs, box = box(fs) } end
	end
	local art = box(r.art)
	for _, x in ipairs(look.own) do
		if x._kind == "Texture" and FT.visible(x) then
			local b = box(x)
			if b then
				for _, text in ipairs(texts) do
					if text.box and overlap(b, text.box) then
						fail(scenario, ("a region of the look (%s) lies under a line of text"):format(tostring(x._file)))
					end
				end
				if (b[3] - b[1]) * (b[4] - b[2]) > 0.2 * (art[3] - art[1]) * (art[4] - art[2]) then
					fail(scenario, ("a region of the look (%s) is the size of a panel"):format(tostring(x._file)))
				end
			end
		end
	end
	-- The art it draws with: a dot, a ring, a mask, a line, a bar -- no veil, no box.
	local allowed = { Dot = true, Ring = true, MaskRound = true, Line = true, Bar = true }
	for _, x in ipairs(look.own) do
		if x._kind == "Texture" then
			local file = tostring(x._file or "")
			local short = file:match("Whisper_(%w+)$")
			if not (short and allowed[short]) then fail(scenario, "a region draws " .. file .. ", which is not Whisper's art") end
		end
	end
	-- The button's own highlight, a square over the panel, is off.
	local hl = ns.Prompt:GetButton():GetHighlightTexture()
	if hl and hl._color and (hl._color[4] or 0) > 0.001 then fail(scenario, "the button still lights a square under the cursor") end
end)

-- ------------------------------------------------------------------ 6
-- The reason's colour: on the reason line and the dot's ring, by marker.
local function strongest(c)
	local best, at = -1, 1
	for i = 1, 3 do if c[i] > best then best, at = c[i], i end end
	return at, best - math.min(c[1], c[2], c[3])
end

withTree("look-whisper: the reason line and the dot carry the reason in each palette", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local lines = {}
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs(REASONS) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			if not sameColour(look.ring._color, cr, cg, cb) then
				fail(scenario, ("the dot's ring is not in %s's colour in the %s set"):format(reason, palette))
			end
			if not sameColour(look.plain._color, cr, cg, cb) then
				fail(scenario, ("the plain dot is not in %s's colour in the %s set"):format(reason, palette))
			end
			local line = r.sub._textColor
			local want, spread = strongest({ cr, cg, cb })
			if spread > 0.2 then
				local got = strongest(line)
				if got ~= want then
					fail(scenario, ("the reason line is not in %s's colour in the %s set (its strongest channel is %d, not %d)")
						:format(reason, palette, got, want))
				end
			end
			if palette == "standard" then lines[reason] = ("%.2f:%.2f:%.2f"):format(line[1], line[2], line[3]) end
		end
	end
	-- As many colours on the reason line as the palette has: your own buff wears
	-- the group's, so five of six.
	local distinct, count = {}, 0
	for _, key in pairs(lines) do if not distinct[key] then distinct[key] = true count = count + 1 end end
	if count < 5 then fail(scenario, "two reasons share a colour on the reason line: " .. count .. " of 5") end
	p.reasonPalette = "standard"
	-- Icon: the ring and the line. Stripe: the line alone. Both: the two. Off:
	-- neither, and the line a neutral grey.
	local function paint(mode)
		p.accentMode = mode
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent("asked")
		return ns.Prompt:AccentColor("asked")
	end
	local cr, cg, cb = paint("stripe")
	if not near(look.ring._color[4], 0.30) then fail(scenario, "with the marker on the stripe the ring still carries a reason") end
	if sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "with the marker on the stripe the ring is in the reason's colour") end
	if strongest(r.sub._textColor) ~= strongest({ cr, cg, cb }) then fail(scenario, "with the marker on the stripe the reason line lost the reason") end
	cr, cg, cb = paint("both")
	if not (sameColour(look.ring._color, cr, cg, cb)) then fail(scenario, "with \"both\" the ring does not carry the reason") end
	cr, cg, cb = paint("off")
	local line = r.sub._textColor
	if not (math.abs(line[1] - line[2]) < 0.1 and math.abs(line[2] - line[3]) < 0.1) then
		fail(scenario, "with the marker off the reason line is still a colour")
	end
	if sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "with the marker off the ring still carries a reason") end
	cr, cg, cb = paint("icon")
	if not sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "back on \"icon\" the ring did not come back") end
	-- No icon: the dot is a plain disc, and carries it.
	p.showIcon = false
	cr, cg, cb = paint("icon")
	if not look.plain._shown or look.ring._shown then fail(scenario, "with no icon the dot is not the plain disc") end
	if not sameColour(look.plain._color, cr, cg, cb) then fail(scenario, "with no icon the plain dot is not in the reason's colour") end
	-- The carriers the options page reads.
	local icon, stripe = look.AccentCarriers({ accentMode = "stripe", showIcon = true })
	if icon or not stripe then fail(scenario, "AccentCarriers says the wrong thing for the stripe") end
	icon, stripe = look.AccentCarriers({ accentMode = "off", showIcon = true })
	if icon or stripe then fail(scenario, "AccentCarriers says the marker is on when it is off") end
end)

withTree("look-whisper: the outcomes have their own colours on the reason line and the ring", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	local c = r.sub._textColor
	if not (c and c[2] > c[1] and c[2] > c[3]) then fail(scenario, "a landed buff's reason line is not green") end
	local ring = look.ring._color
	if not (ring and ring[2] > ring[1] and ring[2] > ring[3]) then fail(scenario, "a landed buff's ring is not green") end
	local said = tostring(r.sub:GetText()):lower():gsub("%s+", "")
	if said ~= ns.L["buffed"]:lower() then fail(scenario, "the reason line does not say buffed: " .. tostring(r.sub:GetText())) end
	if tostring(r.name:GetText()):find("Anna", 1, true) ~= 1 then fail(scenario, "the name moved for a landed buff") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	FT.settle()
	c = r.sub._textColor
	if not (c and c[1] >= 0.9 and c[1] > c[2] and c[2] > c[3]) then
		fail(scenario, "a refusal's reason line is not red-amber: " .. (c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "none"))
	end
	ring = look.ring._color
	if not (ring and ring[1] >= 0.9 and ring[1] > ring[2] and ring[2] > ring[3]) then fail(scenario, "a refusal's ring is not red-amber") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	FT.settle()
	c = r.sub._textColor
	if not (c and c[1] > c[3] and c[2] > c[3]) then fail(scenario, "an unconfirmed cast's reason line is not pale gold") end
	-- The next paint of the person takes the reason's colour back.
	Mock.advance(2)
	owe(ns, "Anna Aim")
	tick(ns)
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "the ring kept the outcome's colour after it") end
	if strongest(r.sub._textColor) ~= strongest({ cr, cg, cb }) then fail(scenario, "the reason line kept the outcome's colour after it") end
end)

-- ------------------------------------------------------------------ 7
-- The reason in letter-spaced capitals, where plain ASCII fits; the name never.
withTree("look-whisper: the reason is letter-spaced capitals where plain ASCII fits, and left alone elsewhere", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.width = 260 end)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local function spaced(text)
		local letters = text:gsub("%s", "")
		return letters
	end
	local function setReason(text)
		p.reasonOwed = text
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		Mock.advance(5)
		tick(ns)
		return r.sub:GetText()
	end
	local shown = setReason("buffed you")
	if shown ~= "B U F F E D   Y O U" then fail(scenario, "plain ASCII is not letter-spaced capitals: " .. printable(shown)) end
	-- Spaced, the letters are the same ones.
	if spaced(shown) ~= "BUFFEDYOU" then fail(scenario, "the spaced line has other letters: " .. printable(shown)) end
	-- A line that would not fit spaced is plain capitals, not cut.
	shown = setReason("needs a very long reason that cannot possibly fit")
	if shown ~= "NEEDS A VERY LONG REASON THAT CANNOT POSSIBLY FIT" then fail(scenario, "a line too long to space is not plain capitals: " .. printable(shown)) end
	-- An accent: left as it is, whole.
	shown = setReason("f\195\188r dich")
	if shown ~= "f\195\188r dich" then fail(scenario, "a line with an accent was changed: " .. printable(shown)) end
	shown = setReason("F\195\188r dich")
	if shown ~= "F\195\188r dich" then fail(scenario, "a capitalised line with an accent was changed: " .. printable(shown)) end
	-- Chinese: left as it is.
	shown = setReason("\228\189\160\229\165\189")
	if shown ~= "\228\189\160\229\165\189" then fail(scenario, "a line of Chinese was changed: " .. printable(shown)) end
	-- A colour code in it: capitals, the code kept whole, not spaced.
	shown = setReason("|cffff8000so it goes|r")
	if shown ~= "|cffff8000SO IT GOES|r" then fail(scenario, "a coloured line is not plain capitals with its code whole: " .. printable(shown)) end
	-- The name is never capitalised.
	if tostring(r.name:GetText()):find("%u%u") then fail(scenario, "the name is in capitals: " .. tostring(r.name:GetText())) end
	-- Leaving the look gives the reason back as it was.
	p.style, p.reasonOwed = "glass", "buffed you"
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	Mock.advance(5)
	tick(ns)
	if r.sub:GetText() ~= "buffed you" then fail(scenario, "on glass the reason is still in capitals: " .. tostring(r.sub:GetText())) end
end)

-- ------------------------------------------------------------------ 8
-- Motion. One slow breath of the dot and the reason while somebody owed waits;
-- nothing loops on Calm; the landing draws a line from the left and blooms the
-- name on Full and fades on Calm; the refusal dips and nudges the text two
-- units, and the shared shake is put back when the look is left.
withTree("look-whisper: the owed breath is one slow loop of the opacity of the dot and the reason", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	for _, group in ipairs(look.breaths) do
		if not group._playing then fail(scenario, "somebody owed on top on Full, and the dot and the reason do not breathe") end
	end
	local _, loops = FT.playing()
	if #loops ~= 2 then fail(scenario, ("%d animations loop while somebody owed waits: the dot's and the reason's, two"):format(#loops)) end
	for _, group in ipairs(look.breaths) do
		local anim = group._anims[1]
		if not (anim and anim._kind == "Alpha") then fail(scenario, "the breath is not a change of opacity") end
		for _, a in ipairs(group._anims) do
			if a._kind ~= "Alpha" then fail(scenario, "the breath also does a " .. tostring(a._kind)) end
		end
		if anim and anim._duration < 1.2 then fail(scenario, "the breath is faster than a slow one: " .. tostring(anim._duration)) end
		if anim and not (anim._fromAlpha >= 0.3 and anim._toAlpha <= 1 and anim._toAlpha - anim._fromAlpha <= 0.6) then
			fail(scenario, "the breath is not a gentle shift")
		end
	end
	-- Nobody owed: the breath goes, and the marks rest.
	wipe(ns.owed)
	tick(ns)
	if look.breaths[1]._playing or looping() > 0 then fail(scenario, "the breath still loops with nobody owed") end
	-- The scan does not start it again for a passer-by.
	tick(ns)
	if look.breaths[1]._playing then fail(scenario, "the scan started the breath with nobody owed") end
	-- Calm: held, never a loop.
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	if looping() > 0 then fail(scenario, ("%d animation(s) loop on Calm"):format(looping())) end
	if not near(look.reasonBreath._alpha, 1) or not near(look.ringBreath._alpha, 1) then fail(scenario, "on Calm the marks are not held at full") end
	-- Flash style none: nothing breathes.
	p.effects, p.flashStyle = "full", "off"
	ns.Prompt:ApplyStyle()
	wipe(ns.owed)
	tick(ns)
	owe(ns, "Anna Aim")
	tick(ns)
	if look.breaths[1]._playing then fail(scenario, "with the flash off the marks breathe") end
end)

withTree("look-whisper: a new face comes up once, never on a repaint", CROWD, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local before, rises = allPlays(look.arrivals), plays(look.nameArrival)
	if before < 2 then fail(scenario, "somebody owed arrived and the dot and the reason did not come up") end
	if rises < 1 then fail(scenario, "somebody owed arrived and the name did not rise") end
	for _ = 1, 4 do
		Mock.advance(0.4)
		tick(ns)
	end
	if allPlays(look.arrivals) > before or plays(look.nameArrival) > rises then
		fail(scenario, "the type came up again for the same favour on a repaint")
	end
	-- A stranger is not a favour.
	wipe(ns.owed)
	tick(ns)
	local after, risen = allPlays(look.arrivals), plays(look.nameArrival)
	for _ = 1, 3 do
		Mock.advance(0.4)
		tick(ns)
	end
	if allPlays(look.arrivals) > after or plays(look.nameArrival) > risen then fail(scenario, "the type came up for a stranger") end
end)

withTree("look-whisper: the name rises on Full and only fades on Calm", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	-- A drop that is instant, a rise that ends where the name belongs: the
	-- translations sum to nothing, so the group's end puts the name home.
	local sum, rise = 0, 0
	for _, a in ipairs(look.nameArrival._anims) do
		if a._kind == "Translation" then
			sum = sum + a._offset[2]
			rise = math.max(rise, a._offset[2])
		end
	end
	if math.abs(sum) > 0.01 then fail(scenario, "the name's rise does not end where it began, so it would land off its place") end
	if rise < 2 or rise > 8 then fail(scenario, ("the name rises %.1f units: a slight rise is 2 to 8"):format(rise)) end
	if FT.groupLength(look.nameArrival) > 0.7 then fail(scenario, "the name takes more than 0.7 s to come up") end
	for _, a in ipairs(look.nameArrivalCalm._anims) do
		if a._kind ~= "Alpha" then fail(scenario, "Calm's arrival also does a " .. tostring(a._kind)) end
	end
	-- On Calm the fade plays and the rise does not.
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	wipe(ns.owed)
	tick(ns)
	local rises, fades = plays(look.nameArrival), plays(look.nameArrivalCalm)
	owe(ns, "Anna Aim")
	tick(ns)
	if plays(look.nameArrival) > rises then fail(scenario, "on Calm the name rose") end
	if plays(look.nameArrivalCalm) ~= fades + 1 then fail(scenario, "on Calm the name did not fade up") end
end)

withTree("look-whisper: a landed buff sweeps a line under the name and blooms it, a fade on Calm", ANNA, function(ns, scenario)
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
	if FT.groupLength(look.bloomAnim) > 0.7 then fail(scenario, "the bloom takes more than 0.7 s") end
	-- The bloom spreads a little and fades: a copy of the letters, not a shape.
	local swell
	for _, a in ipairs(look.bloomAnim._anims) do if a._kind == "Scale" then swell = a end end
	if not (swell and swell._scaleTo[1] > 1 and swell._scaleTo[1] <= 1.15) then fail(scenario, "the bloom is not a small swell") end
	if #look.echoes < 4 then fail(scenario, "the bloom has too few copies of the letters to hug them") end
	local drawn, bloomed = plays(look.drawAnim), plays(look.bloomAnim)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	if plays(look.drawAnim) ~= drawn + 1 then fail(scenario, "a landed buff did not draw the line once") end
	if plays(look.bloomAnim) ~= bloomed + 1 then fail(scenario, "a landed buff did not bloom the name once") end
	if plays(look.calmAnim) > 0 or plays(look.bloomCalm) > 0 then fail(scenario, "a landed buff faded the line as well as drawing it") end
	-- The bloom is the name's own letters, in the outcome's colour, where the
	-- name stands.
	local name = box(r.name)
	for i, echo in ipairs(look.echoes) do
		if (echo:GetText() or "") ~= (r.name:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) then
			fail(scenario, "bloom copy " .. i .. " is not the name's letters: " .. tostring(echo:GetText()))
			break
		end
		local c = echo._textColor
		if not (c and c[2] > c[1] and c[2] > c[3]) then fail(scenario, "bloom copy " .. i .. " is not in the outcome's green") break end
	end
	local echoBox = box(look.echoFrame)
	if not (echoBox and math.abs(echoBox[1] - name[1]) < 0.01 and math.abs((echoBox[2] + echoBox[4]) - (name[2] + name[4])) < 1.5) then
		fail(scenario, "the bloom does not lie where the name stands")
	end
	-- The line lies under the letters.
	local line = box(look.lineFrame)
	if line and line[4] > name[2] + 0.01 then fail(scenario, "the line is not under the name") end
	-- A refusal draws nothing.
	Mock.advance(1)
	local d, b = plays(look.drawAnim), plays(look.bloomAnim)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.drawAnim) > d or plays(look.bloomAnim) > b then fail(scenario, "a refusal drew the line or bloomed the name") end
	-- An unconfirmed cast claims nothing.
	Mock.advance(1)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if plays(look.drawAnim) > d or plays(look.bloomAnim) > b then fail(scenario, "an unconfirmed cast drew the line or bloomed the name") end
	-- Calm: a fade where it lies, and no growth anywhere.
	Mock.advance(1)
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local grown, swollen, faded, glowed = plays(look.drawAnim), plays(look.bloomAnim), plays(look.calmAnim), plays(look.bloomCalm)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	if plays(look.drawAnim) > grown or plays(look.bloomAnim) > swollen then fail(scenario, "on Calm the line was drawn or the name bloomed") end
	if plays(look.calmAnim) ~= faded + 1 then fail(scenario, "on Calm the line did not fade in and out") end
	if plays(look.bloomCalm) ~= glowed + 1 then fail(scenario, "on Calm the bloom did not fade in and out") end
	for _, group in ipairs({ look.calmAnim, look.bloomCalm, look.nameArrivalCalm }) do
		for _, a in ipairs(group._anims) do
			if a._kind ~= "Alpha" then fail(scenario, "Calm's motion also does a " .. tostring(a._kind)) end
		end
	end
	-- Quiet in a fight: nothing on the panel moves, Calm's fade included.
	Mock.advance(1)
	p.effects, p.hideInCombat = "calm", true
	ns.Prompt:ApplyStyle()
	tick(ns)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	grown, faded, glowed = plays(look.drawAnim), plays(look.calmAnim), plays(look.bloomCalm)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	FT.settle()
	if plays(look.drawAnim) > grown or plays(look.calmAnim) > faded or plays(look.bloomCalm) > glowed then
		fail(scenario, "the line moved in a fight that is to be quiet")
	end
	Mock.inCombat = false
end)

withTree("look-whisper: a refusal turns the reason amber and nudges the text two units", ANNA, function(ns, scenario)
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
	local dips, shakes = allPlays(look.warns), plays(shake)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	FT.settle()
	if allPlays(look.warns) ~= dips + 2 then fail(scenario, "a refusal did not dip the dot and the reason") end
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
	dips, shakes = allPlays(look.warns), plays(shake)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if allPlays(look.warns) > dips or plays(shake) > shakes then fail(scenario, "a refusal moved on Calm") end
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

-- ------------------------------------------------------------------ 9
-- Under the text: every frame of light or line is beneath textLayer and over the
-- art; the frames that hold letters are over textLayer's own level, the bloom
-- under the reason and the name; hunt37's per-look loops name Whisper, so the
-- rings-and-room rules are held to it.
withTree("look-whisper: every frame of its motion is under the text and the bloom under the letters", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local textLevel = r.textLayer._level or 0
	for name, f in pairs({ ring = look.ringFlare, breath = look.ringBreath, line = look.lineFrame, hover = look.hoverFrame,
		marks = look.marksFrame }) do
		if (f._level or 0) >= textLevel then
			fail(scenario, ("the %s frame is at level %d, not under the text's %d"):format(name, f._level or 0, textLevel))
		end
		if (f._level or 0) <= (r.art._level or 0) then fail(scenario, "the " .. name .. " frame is not over the art") end
	end
	local bloom, reason, name = look.echoFrame._level or 0, look.reasonFlare._level or 0, look.nameFrame._level or 0
	if not (bloom > textLevel and bloom < reason and bloom < name) then
		fail(scenario, "the bloom is not under the reason and the name, in the text layer")
	end
	-- The letters are in those frames, which are in the text layer: the shake,
	-- the cross-fade and the combat dim reach them.
	local function under(node, ancestor)
		while node do
			if node == ancestor then return true end
			node = node._parent
		end
		return false
	end
	if not (under(r.name, look.nameFrame) and under(r.name, r.textLayer)) then fail(scenario, "the name is not in its frame in the text layer") end
	if not (under(r.sub, look.reasonBreath) and under(r.sub, r.textLayer)) then fail(scenario, "the reason is not in its frame in the text layer") end
	local f = io.open(dir .. "/tests/scenarios/hunt37-effects.lua", "rb")
	local text = f and f:read("*a") or ""
	if f then f:close() end
	local list = text:match("local ALL = (%b{})") or ""
	if not list:find('"whisper"', 1, true) then fail(scenario, "hunt37-effects' per-look loops do not name Whisper") end
end)

-- ------------------------------------------------------------------ 10
-- Legible on snow and on a dusky world, by the letters' own edge: every line is
-- outlined in black and shadowed, and light enough against that edge. The
-- ground at the glyph's edge is the outline's black where the line has one and
-- the world where it has not.
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
local WORLDS = { { "a dusky world", luminance(greyOf(0.30), greyOf(0.30), greyOf(0.30)) },
	{ "snow", luminance(greyOf(0.85), greyOf(0.85), greyOf(0.85)) } }

-- The luminance a glyph's edge stands against: the outline's black, or the world.
local function edge(fs, world)
	local flags = tostring(fs._font and fs._font.flags or "")
	if flags:find("OUTLINE", 1, true) then return 0 end
	return world
end

withTree("look-whisper: every line holds its contrast at the letters' edge over snow and a dusky world", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	Mock.bindings = { F = COMMAND }
	tick(ns)
	local function check(what, fs, minimum)
		local c = fs._textColor
		if not c then fail(scenario, what .. " has no colour") return end
		local flags = tostring(fs._font and fs._font.flags or "")
		if not flags:find("OUTLINE", 1, true) then fail(scenario, what .. " is not outlined: its flags are \"" .. flags .. "\"") end
		local shadow, offset = fs._shadowColor, fs._shadowOffset
		if not (shadow and (shadow[4] or 0) >= 0.5 and offset and (offset[1] ~= 0 or offset[2] ~= 0)) then
			fail(scenario, what .. " has no soft shadow under its letters")
		end
		for _, world in ipairs(WORLDS) do
			local got = ratio(luminance(c[1], c[2], c[3]), edge(fs, world[2]))
			if got < minimum then fail(scenario, ("%s is %.2f:1 at its edge over %s"):format(what, got, world[1])) end
		end
	end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		ns.Prompt:ApplyStyle()
		for _, reason in ipairs(REASONS) do
			ns.Prompt:PaintAccent(reason)
			check(("the reason line for %s (%s set)"):format(reason, palette), r.sub, 7)
		end
	end
	-- Every outcome's colour too.
	for _, outcome in ipairs({ { "cast", "buff" }, { "failed", "refusal" }, { "sent", "unconfirmed cast" } }) do
		Mock.advance(1)
		ns.Prompt:ShowOutcome(outcome[1], "Anna Aim", "Out of range.")
		FT.settle()
		check("the reason line of a " .. outcome[2], r.sub, 7)
	end
	Mock.advance(2)
	tick(ns)
	check("the name", r.name, 7)
	check("the count", r.count, 7)
	check("the key", look.keyText, 7)
	check("a list row", r.rows[1], 7)
	-- The words after a list row's name, in the look's dimmer grey.
	local code = ns.Prompt.lib.ink.rowReason or ""
	local hex = code:match("|cff(%x%x%x%x%x%x)")
	if hex then
		local c = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
		for _, world in ipairs(WORLDS) do
			local got = ratio(luminance(c[1], c[2], c[3]), edge(r.rows[1], world[2]))
			if got < 7 then fail(scenario, ("the words after a list row's name are %.2f:1 at their edge over %s"):format(got, world[1])) end
		end
	else
		fail(scenario, "the list's reason grey is not a colour code")
	end
	-- A dark font colour and a light panel colour change nothing: there is no
	-- panel, so the name is taken to light for its black edge.
	p.fontColor = { 0.10, 0.10, 0.12, 1 }
	p.bgColor = { 0.86, 0.84, 0.78, 0.92 }
	ns.Prompt:ApplyStyle()
	tick(ns)
	check("the name with a dark font colour on a light panel colour", r.name, 7)
	check("the reason line on a light panel colour", r.sub, 7)
end)

withTree("look-whisper: the fonts are the player's, and no file is named by the look", CROWD, function(ns, scenario)
	local f = io.open(dir .. "/Looks/Whisper.lua", "rb")
	local source = f and f:read("*a") or ""
	if f then f:close() end
	-- Comments say which faces are not named; code names none.
	local code = source:gsub("%-%-[^\n]*", "")
	if code:find("%.[Tt][Tt][Ff]") or code:find("Fonts\\\\") or code:find("FRIZQT") or code:find("ARIALN") then
		fail(scenario, "the look names a font file of its own")
	end
	-- A face of the profile's own choosing, so a refusal of it is not a refusal of the game's.
	LibStub("LibSharedMedia-3.0"):Register("font", "Whisper Test", [[Fonts\WHISPER_TEST.TTF]])
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.font = "Whisper Test"
		pp.showQueue, pp.queueRows = true, 3
	end)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local fit = ns.Prompt:LookKit().fit
	local want = r.name._font and r.name._font.path
	if want ~= fit.path then fail(scenario, "the name is not in the font Prompt chose: " .. tostring(want) .. " for " .. tostring(fit.path)) end
	for what, fs in pairs({ reason = r.sub, count = r.count, key = look.keyText, row = r.rows[1] }) do
		if fs._font and fs._font.path ~= want then fail(scenario, ("the %s is in %s, not the name's %s"):format(what, tostring(fs._font.path), tostring(want))) end
	end
	-- A font the client will not load: the game's own, and nothing throws.
	local bad = r.name._font.path
	Mock.badFonts = { [bad] = true }
	local ok, err = xpcall(function()
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		tick(ns)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		FT.settle()
	end, debug.traceback)
	Mock.badFonts = nil
	if not ok then fail(scenario, "an unloadable font threw: " .. tostring(err)) return end
	if not (r.name._font and r.name._font.path == STANDARD_TEXT_FONT) then
		fail(scenario, "with the font refused the name is not in the game's own: " .. tostring(r.name._font and r.name._font.path))
	end
	for _, echo in ipairs(look.echoes) do
		if echo._font and echo._font.path ~= STANDARD_TEXT_FONT and echo._font.path ~= bad then
			fail(scenario, "the bloom is in a font the name is not in")
		end
	end
end)

for _, code in ipairs({ "koKR", "zhCN", "zhTW" }) do
	withTree("look-whisper: " .. code .. " takes the locale's own font for every line", CROWD, function(ns, scenario)
		local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
		if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		FT.settle()
		local want = ns.Prompt:LookKit().fit.path
		for what, fs in pairs({ name = r.name, reason = r.sub, count = r.count, key = look.keyText, row = r.rows[1] }) do
			if not (fs._font and fs._font.path == want) then
				fail(scenario, ("the %s is in %s, not the font the profile names, %s"):format(what, tostring(fs._font and fs._font.path), tostring(want)))
			end
		end
		for _, echo in ipairs(look.echoes) do
			if not (echo._font and echo._font.path == want) then fail(scenario, "the bloom is not in the locale's font") break end
		end
		-- A line with no Latin in it is not capitalised or spaced.
		p.reasonOwed = "\228\189\160\229\165\189"
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		Mock.advance(5)
		tick(ns)
		if r.sub:GetText() ~= "\228\189\160\229\165\189" then fail(scenario, "a line with no Latin in it was changed: " .. printable(r.sub:GetText())) end
	end, function() Mock.locale = code end)
end

-- ------------------------------------------------------------------ 11
-- The cursor, the move handle, the fight, and leaving.
withTree("look-whisper: a line lights under the name when the cursor is on the panel", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	local b = ns.Prompt:GetButton()
	local plays0 = plays(look.hoverAnim)
	b.scripts.OnEnter(b)
	if plays(look.hoverAnim) ~= plays0 + 1 then fail(scenario, "the cursor on the panel did not light the line") end
	b.scripts.OnLeave(b)
	FT.settle()
	Mock.advance(1)
	FT.settle()
	if not near(look.hoverFrame._alpha, 0) then fail(scenario, "the line's light stayed on after the cursor left") end
end)

withTree("look-whisper: unlocked, four corner marks show the move handle, and only then", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	-- Locked: no marks.
	if FT.visible(look.marksFrame) then fail(scenario, "the move marks show on a locked prompt") end
	for i, t in ipairs(look.markLight) do
		if FT.visible(t) then fail(scenario, "mark " .. i .. " shows on a locked prompt") break end
	end
	p.locked = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if r.name:GetText() ~= "|cffffd100" .. ns.L["Drag to move"] .. "|r" then
		fail(scenario, "unlocked, the name line does not say how to move it: " .. tostring(r.name:GetText()))
	end
	local art = box(r.art)
	local seen = {}
	for i, t in ipairs(look.markLight) do
		if not FT.visible(t) then fail(scenario, "mark " .. i .. " is hidden while unlocked") end
		local b = box(t)
		if b then
			if not inside(b, art, 0) then fail(scenario, "mark " .. i .. " leaves the panel") end
			-- The four corners: each mark touches the edge it hangs from.
			local corner = (b[1] - art[1] < 3 and "L" or "") .. (art[3] - b[3] < 3 and "R" or "")
				.. (b[2] - art[2] < 3 and "B" or "") .. (art[4] - b[4] < 3 and "T" or "")
			seen[corner] = true
			if math.max(b[3] - b[1], b[4] - b[2]) < 6 then fail(scenario, "mark " .. i .. " is too short to see") end
		end
		local c = t._color
		if not (c and c[1] > c[3] and c[4] >= 0.8) then fail(scenario, "mark " .. i .. " is not the gold handle's colour") end
		local d = look.markDark[i]
		if not (FT.visible(d) and d._color and d._color[4] >= 0.4) then fail(scenario, "mark " .. i .. " has no dark stroke to read it over snow") end
	end
	local corners = 0
	for _ in pairs(seen) do corners = corners + 1 end
	if corners < 4 then fail(scenario, "the marks do not stand at four different corners") end
	-- The handle lies on the type's side of nothing: the type stays clear of the marks.
	for _, fs in ipairs({ r.name, r.sub }) do
		if FT.visible(fs) then
			local b = box(fs)
			for i, t in ipairs(look.markLight) do
				local m = box(t)
				if b and m and overlap(b, m) then fail(scenario, "mark " .. i .. " lies on the type") end
			end
		end
	end
	local button = box(ns.Prompt:GetButton())
	if not (button and art and button[1] <= art[1] + 0.01 and button[3] >= art[3] - 0.01) then
		fail(scenario, "the draggable button does not cover the panel")
	end
	if not (r.sub:IsShown() and r.sub:GetText():lower():gsub("%s+", "") == ns.L["Let go and it locks itself"]:lower():gsub("%s+", "")) then
		fail(scenario, "the second line does not say it locks itself: " .. tostring(r.sub:GetText()))
	end
	-- A light panel colour, which this look has no panel for, does not darken the
	-- handle's words: they are as they were written, gold.
	p.bgColor = { 0.86, 0.84, 0.78, 0.92 }
	ns.Prompt:ApplyStyle()
	tick(ns)
	if r.name:GetText() ~= "|cffffd100" .. ns.L["Drag to move"] .. "|r" then
		fail(scenario, "with a light panel colour the handle's words were taken dark: " .. tostring(r.name:GetText()))
	end
	p.locked = true
	ns.Prompt:ApplyStyle()
	tick(ns)
	if FT.visible(look.marksFrame) then fail(scenario, "the marks stay after the prompt is locked") end
end)

withTree("look-whisper: in a fight the reason stays and nothing loops", ANNA, function(ns, scenario)
	local r, _, look = upIn(ns, scenario)
	if not isWhisper(look) then fail(scenario, "Whisper is not the look in use") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if looping() > 0 then fail(scenario, "something loops in a fight") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "the ring lost the reason in a fight") end
	if strongest(r.sub._textColor) ~= strongest({ cr, cg, cb }) then fail(scenario, "the reason line lost its colour in a fight") end
	if not (near(look.reasonBreath._alpha, 1) and near(look.ringBreath._alpha, 1)) then fail(scenario, "the dot or the reason is dimmed in a fight") end
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
			-- (Luxe puts the reason line in its own tag.)
			if r.name._parent ~= r.textLayer or (style ~= "luxe" and r.sub._parent ~= r.textLayer) then
				fail(scenario, "the lines are still in Whisper's frames under " .. style)
			end
			if ns.Prompt:LookKit().fit.flags ~= (style == "minimal" and "OUTLINE" or "") then
				fail(scenario, "the font flags are still Whisper's under " .. style)
			end
			if tostring(r.sub:GetText()):find("^%u %u") then fail(scenario, "the reason is still letter-spaced under " .. style) end
			if r.shake then
				local biggest = 0
				for _, a in ipairs({ r.shake:GetAnimations() }) do biggest = math.max(biggest, math.abs((a:GetOffset()))) end
				if biggest < 4.9 then fail(scenario, "the shared shake is still Whisper's two units under " .. style) end
			end
		end
	end
end)

-- ------------------------------------------------------------------ 12
-- The scan repaints several times a second: Whisper adds no measuring, no
-- gradient and no re-anchoring to a repaint that changes nothing.
withTree("look-whisper: a repaint that changes nothing measures and anchors nothing", CROWD, function(ns, scenario)
	Mock.bindings = { F = COMMAND }
	local r, _, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local kit = look and look.kit
	if not (isWhisper(look) and kit) then fail(scenario, "Whisper is not the look in use") return end
	ns.addon:Tick()
	local measured, graded, anchored, bindings = 0, 0, 0, 0
	local width, gradient = kit.TextWidth, kit.Gradient
	kit.TextWidth = function(...) measured = measured + 1 return width(...) end
	kit.Gradient = function(...) graded = graded + 1 return gradient(...) end
	local watched = { look.ring, look.plain, look.lineFrame, look.ringFlare, look.ringBreath, look.reasonFlare, look.reasonBreath,
		look.nameFrame, look.echoFrame, look.dots[1], look.keyText, r.count, r.rows[1], r.name, r.sub, r.icon }
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

-- ------------------------------------------------------------------ 13
-- The count and the key: small inline text after the name, each left out when it
-- would cut the name.
withTree("look-whisper: the count and the key are small text after the name and step aside for a long one", LONG, function(ns, scenario)
	Mock.bindings = { F = COMMAND }
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
	if FT.visible(r.count) or FT.visible(look.keyText) then fail(scenario, "the count or the key is up over the long name") end
	p.width, p.fontSize = 400, 13
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (FT.visible(r.count) and r.count:GetText():match("^%+%d+$")) then
		fail(scenario, "with room for it the count is not up as +n: " .. tostring(r.count:GetText()))
	end
	if not (FT.visible(look.keyText) and look.keyText:GetText() == "[F]") then
		fail(scenario, "with room for it the key is not up as [F]: " .. tostring(look.keyText:GetText()))
	end
	-- Small text, not boxes: nothing is drawn behind either.
	if FT.visible(r.chip) then fail(scenario, "the count's chip is showing") end
	-- No key bound: no key.
	Mock.bindings = {}
	tick(ns)
	if FT.visible(look.keyText) then fail(scenario, "a key that is not bound is shown") end
end)

-- ------------------------------------------------------------------ 14
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
	if #files < 5 then fail(scenario, "the generator names only " .. #files .. " files") end
	local drawn = {}
	for _, file in ipairs(files) do
		drawn[file] = true
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
		-- Named in the look.
		if not named[file] then fail(scenario, file .. " ships and the look never draws it") end
	end
	-- The art of the box this look no longer has: none of it ships.
	for _, gone in ipairs({ "Dash", "Mask", "RingRound", "Veil" }) do
		if header(dir .. "/Textures/Whisper/Whisper_" .. gone .. ".tga") then
			fail(scenario, "Whisper_" .. gone .. ".tga ships and nothing draws it")
		end
	end
end)

-- ------------------------------------------------------------------ 15
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
