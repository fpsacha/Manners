-- The looks: the two Prompt/Panel.lua draws and the ones in Looks/, and what
-- Prompt hands over to any look of its own (Leather stands for them here;
-- each look's own promises are in its look-<key>.lua).
--
-- A look is art on frames the addon owns, and a broken one throws nothing: a
-- ring left on the icon after switching back to glass, a tag that keeps last
-- click's tick, a pulse that loops on Calm. So these run on the recording
-- CreateFrame in tests/frametree.lua, which remembers what every region was
-- told, and ask it.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local STYLES = { "glass", "minimal", "ribbon", "letter", "leather", "forge", "archmage", "lightbringer", "fel", "wild" }
local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

-- On the recording CreateFrame, put back afterwards whatever happens. `before`
-- runs after the mock is reset and before the addon loads (a client language).
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

local function looping()
	local _, loops = FT.playing()
	return #loops
end

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.005 end

local function sameColour(c, r, g, b)
	return c ~= nil and near(c[1], r) and near(c[2], g) and near(c[3], b)
end

-- The prompt up with Anna owed on top, in `style`.
local function upIn(ns, scenario, style, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = style
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	FT.settle()
	return ns.Prompt:Regions(), p
end

local function errorsSince(ns, from)
	local out = {}
	for i = from + 1, #(ns.errors or {}) do
		local e = ns.errors[i]
		out[#out + 1] = tostring(e.where) .. " -> " .. tostring(e.err)
	end
	return out
end

-- What an outcome's lines must say, whatever the look and the settings: the
-- name line and the reason line read together.
local VERDICT = {
	success = { "buffed" },
	refused = { "could not buff", "Out of range." },
	sent = { "sent" },
}

-- Every state tools/render_prompt.py draws, driven in turn on one prompt.
local function everyState(ns, p)
	local P = ns.Prompt
	local regions = P:Regions()
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
		local words = VERDICT[step[1]]
		if words then
			local said = tostring(regions.name:GetText()) .. " / "
				.. (regions.sub:IsShown() and tostring(regions.sub:GetText()) or "")
			-- Read as the eye does: a look that sets a line in capitals or spaces its
			-- letters still says the word.
			local read = said:lower():gsub("%s+", "")
			local found = false
			for _, word in ipairs(words) do
				if read:find((word:lower():gsub("%s+", "")), 1, true) then found = true end
			end
			if not found then return step[1] .. ": the lines do not say the verdict: " .. said end
		end
	end
end

-- ------------------------------------------------------------------ 1
-- Every look, every state, every setting it has to honour, without an error.
for _, style in ipairs(STYLES) do
	local scenario = "the " .. style .. " look paints every state"
	withTree(scenario, CROWD, function(ns)
		local _, p = upIn(ns, scenario, style)
		local from = #(ns.errors or {})
		local threw = everyState(ns, p)
		if threw then fail(scenario, threw) end
		-- The settings each look must honour, one at a time and together.
		for _, edit in ipairs({
			{ "second line off", function() p.showSub = false end },
			{ "count off", function() p.showCount = false end },
			{ "icon hidden", function() p.showIcon = false end },
			{ "round icon", function() p.showIcon, p.roundIcon = true, true end },
			{ "colour-blind set", function() p.reasonPalette = "colourblind" end },
			{ "one marker colour", function() p.accentByReason = false end },
			{ "marker off", function() p.accentMode = "off" end },
			{ "stripe only", function() p.accentMode = "stripe" end },
			{ "light panel", function() p.bgColor = { 0.86, 0.84, 0.78, 0.92 } end },
			{ "big", function() p.width, p.height, p.fontSize, p.iconSize = 320, 58, 17, 40 end },
			{ "small", function() p.width, p.height, p.fontSize, p.iconSize = 180, 40, 11, 26 end },
			{ "calm", function() p.effects = "calm" end },
		}) do
			local ok, err = pcall(function()
				edit[2]()
				ns.Prompt:ApplyStyle()
				ns.addon:Tick()
				for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
					ns.Prompt:PaintAccent(reason)
				end
			end)
			if not ok then fail(scenario, edit[1] .. " threw: " .. tostring(err)) end
			threw = everyState(ns, p)
			if threw then fail(scenario, edit[1] .. ": " .. threw) end
		end
		-- Calm was the last setting: whatever every state left, nothing loops.
		-- (A look from Looks/: the built-in looks' favour glow is theirs to
		-- keep on Calm.)
		ns.addon:Tick()
		FT.settle()
		if ns.Looks.Get(style) and looping() > 0 then
			fail(scenario, ("%d animation(s) loop on Calm after every state"):format(looping()))
		end
		for _, e in ipairs(errorsSince(ns, from)) do fail(scenario, "guarded: " .. e) end
	end)
end

-- ------------------------------------------------------------------ 2
-- A fight under a look of its own: the look is told (Leather greys its icon),
-- and art is not dimmed whole, as the built-in looks dim it -- a look that
-- dims its own parts asks for art at full (combatArtAlpha).
withTree("a look of its own is told of the fight and keeps art whole", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "leather")
	local look = r.look
	if not (look and look.thread) then
		fail(scenario, "SKIPPED -- Leather is not the look in use")
		return
	end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	FT.settle()
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	if (r.art._alpha or 1) < 0.99 then
		fail(scenario, "art dimmed whole in a fight (" .. tostring(r.art._alpha) .. "), tag and all")
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	ns.addon:Tick()
	FT.settle()
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the fight") end
end)

-- ------------------------------------------------------------------ 3
-- The list under a look of its own is the look's: the built-in looks' bars
-- stay down.
withTree("the built-in list's bars stay down under a look of its own", CROWD, function(ns, scenario)
	local r = upIn(ns, scenario, "leather", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not (r.look and r.rows[1]:IsShown()) then
		fail(scenario, "SKIPPED -- Leather is not the look in use, or the list is not up")
		return
	end
	for _, bar in ipairs(r.bars) do
		if FT.visible(bar) then fail(scenario, "the glass look's list bars show under Leather") break end
	end
end)

-- ------------------------------------------------------------------ 6
-- Switching looks leaves nothing of the old one on screen, and gives back
-- what it borrowed, whichever way and however often.
withTree("switching looks leaves no region of the old one showing", ANNA, function(ns, scenario)
	-- What the glass look's button highlight is before Leather has been up.
	upIn(ns, scenario, "glass")
	local glassHl = ns.Prompt:GetButton():GetHighlightTexture()
	local glassLift = glassHl and glassHl._color and glassHl._color[4]
	if not (glassLift and glassLift > 0) then fail(scenario, "the glass look's highlight has no lift to compare with") end
	local r, p = upIn(ns, scenario, "leather", function(pp) pp.roundIcon = true end)
	local leather = r.look
	if not (leather and leather.own) then
		fail(scenario, "SKIPPED -- Leather is not the look in use")
		return
	end
	local function check(style, round)
		-- An outcome first, which leaves the look more to take back.
		if p.style == "leather" then
			Mock.advance(3)
			ns.Prompt:ShowOutcome("cast", "Anna Aim")
		end
		p.style = style
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local now = ns.Prompt:Regions()
		if style == "glass" or style == "minimal" then
			for i, x in ipairs(leather.own) do
				if FT.visible(x) then
					fail(scenario, ("Leather's region %d still shows after switching to %s"):format(i, style))
					break
				end
			end
			if now.icon._mask == leather.mask then fail(scenario, "Leather's mask still shapes the icon on glass") end
			-- And every other look from Looks/ that has been drawn.
			for key, other in pairs(ns.Looks.list) do
				if other ~= leather and other.own then
					for i, x in ipairs(other.own) do
						if FT.visible(x) then
							fail(scenario, ("%s's region %d still shows after switching to %s"):format(key, i, style))
							break
						end
					end
					if other.mask and now.icon._mask == other.mask then
						fail(scenario, key .. "'s mask still shapes the icon on " .. style)
					end
				end
			end
			if now.icon._desaturated or not near(now.icon._alpha or 1, 1) then
				fail(scenario, "the icon kept a look's dim after switching to " .. style)
			end
			if now.sub._parent ~= now.textLayer then
				fail(scenario, "the reason line is still inside a look's frame after switching to " .. style)
			end
			if (now.textLayer._level or 0) ~= (now.art._level or 0) + ns.Prompt.lib.TEXT_LEVEL then
				fail(scenario, "textLayer kept a look's frame level on " .. style)
			end
			if ns.Prompt:LookKit().fit.room[now.sub] ~= nil then
				fail(scenario, "the reason line kept a look's room after switching to " .. style)
			end
			for _, f in ipairs({ now.glow, now.burst, now.shine }) do
				if f._shown == false then fail(scenario, "a glass frame of light stayed hidden after a look of its own") break end
			end
			if style == "glass" and (now.pane[5]._shown == false or now.glassLight[5]._shown == false) then
				fail(scenario, "the glass pane did not come back after a look of its own")
			end
			local hl = ns.Prompt:GetButton():GetHighlightTexture()
			if glassLift and hl and hl._color and not near(hl._color[4], glassLift) then
				fail(scenario, "the button's highlight stayed off after a look of its own")
			end
		else
			for i, x in ipairs(now.builtin or {}) do
				if FT.visible(x) then
					fail(scenario, ("a glass region (%d) still shows under %s"):format(i, style))
					break
				end
			end
			if round and not (now.look and now.icon._mask == now.look.mask) then
				fail(scenario, "switching back to " .. style .. " did not shape the icon again")
			end
			-- Nothing of any other look from Looks/ left under this one.
			for key, other in pairs(ns.Looks.list) do
				if other ~= now.look and other.own then
					for i, x in ipairs(other.own) do
						if FT.visible(x) then
							fail(scenario, ("%s's region %d still shows under %s"):format(key, i, style))
							break
						end
					end
				end
			end
		end
	end
	for _, style in ipairs({ "glass", "leather", "minimal", "ribbon", "glass", "letter", "minimal", "forge",
		"archmage", "glass", "lightbringer", "glass", "leather" }) do
		check(style, true)
	end
end)

-- ------------------------------------------------------------------ 9
-- The cursor is the look's to answer: it is told when the cursor comes and
-- when it goes, and the button's square highlight stays off under it.
withTree("a look of its own is told of the cursor", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "leather")
	local look = r.look
	if not (look and look.hoverAnim) then
		fail(scenario, "SKIPPED -- Leather is not the look in use")
		return
	end
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	if not (look.hoverAnim._playing and (look.hoverAnim.to or 0) > 0) then
		fail(scenario, "the cursor on the panel did not light it")
	end
	b.scripts.OnLeave(b)
	if look.hoverAnim.to ~= 0 then fail(scenario, "the cursor left and the light stayed") end
	local hl = b:GetHighlightTexture()
	if hl and hl._color and hl._color[4] ~= 0 then
		fail(scenario, "the square highlight shows over a look that lights itself")
	end
end)

-- ------------------------------------------------------------------ 10
-- A class colour is taken towards white where the look asks (classSoften), so
-- it never reads as a reason.
withTree("a look softens class-coloured names", { nameplate1 = { "Mira", "Vale" } }, function(ns, scenario)
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "leather"
	ns.Prompt:ApplyStyle()
	local entry = { name = "Mira Vale", short = "Mira", class = "MAGE", reason = "nearby" }
	local text = ns.Prompt:RenderPrimary(entry, 0)
	if text:find("ff40c7eb", 1, true) then
		fail(scenario, "a mage's name is drawn in the full class colour on Leather: " .. text)
	end
	-- A tint on white: every channel well over half, so a mage's cyan never
	-- lands on the target reason's.
	local code = text:match("|cff(%x%x%x%x%x%x)")
	for i = 1, 5, 2 do
		if not code or tonumber(code:sub(i, i + 1), 16) < 0xb0 then
			fail(scenario, "a mage's name on Leather is more than a tint on white: " .. text)
			break
		end
	end
	-- The same answer again, from the cache.
	if ns.Prompt:RenderPrimary(entry, 0) ~= text then
		fail(scenario, "a class colour softened twice came out different")
	end
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	text = ns.Prompt:RenderPrimary(entry, 0)
	if not text:find("ff40c7eb", 1, true) then
		fail(scenario, "the glass look no longer draws the class colour as it is: " .. text)
	end
end)

-- ------------------------------------------------------------------ 12
-- The registry: every look offered, a look not written yet drawn as the one it
-- names, a saved look kept, and Glass the default for a profile that never
-- chose (another look was, in 1.5.0, until the game showed its tag white on
-- white).
withTree("every look is offered, and Glass is the default", {}, function(ns, scenario)
	local values = ns.Looks.Choices()
	for _, style in ipairs(STYLES) do
		if type(values[style]) ~= "string" or values[style] == "" then
			fail(scenario, "the Look tab does not offer " .. style)
		end
	end
	-- Every look offered is written now, so a stub is registered here to
	-- keep the way a look not written yet draws as another one honest.
	ns.Looks.Register("stub", { name = "stub", order = 99, fallback = "leather" })
	for key, look in pairs(ns.Looks.list) do
		if look.fallback and ns.Looks.Get(key) ~= ns.Looks.Get(look.fallback) then
			fail(scenario, "a look not written yet does not draw as the look it names")
		end
	end
	ns.Looks.list.stub = nil
	if ns.Looks.Get("glass") ~= nil then fail(scenario, "glass is handed to Looks/ instead of Prompt.lua") end
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "ribbon"
	ns.ClampSettings()
	if ns.db.profile.prompt.style ~= "ribbon" then
		fail(scenario, "a saved Ribbon look was reset to " .. tostring(ns.db.profile.prompt.style))
	end
	local option = H.findOption and H.optionsByKey
	if option and ns.optionsTable then
		local style = H.optionsByKey(ns.optionsTable).style
		if style and type(style.values) == "table" and not style.values.leather then
			fail(scenario, "the options page's style dropdown has no Leather")
		end
	end
	-- The addon as shipped, loaded by hand: load() pins the older scenarios
	-- to glass.
	local shipped = {}
	for _, file in ipairs(ADDON_FILES) do
		local chunk = assert(loadfile(dir .. "/" .. file))
		chunk("Manners", shipped)
	end
	if shipped.defaults.profile.prompt.style ~= "glass" then
		fail(scenario, "the default look is " .. tostring(shipped.defaults.profile.prompt.style) .. ", not Glass")
	end
end)

-- ------------------------------------------------------------------ 16
-- Glass's owed pulse stops when a look of its own takes over: hidden is not
-- stopped, and Calm stops every loop.
withTree("switching from glass mid-pulse leaves nothing looping on Calm", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "glass")
	if not (r.glow and r.glow.pulse and r.glow.pulse._playing) then
		fail(scenario, "SKIPPED -- glass's owed pulse is not playing")
		return
	end
	p.style = "leather"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FT.settle()
	if r.glow.pulse._playing then fail(scenario, "glass's pulse still loops under Leather") end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FT.settle()
	if looping() > 0 then
		fail(scenario, ("%d animation(s) loop on Calm after switching from glass"):format(looping()))
	end
end)

-- ------------------------------------------------------------------ 23
-- The scan repaints several times a second; a look adds no measuring and no
-- gradient to a repaint that changes nothing (FitLine hands it the width it
-- measured, kit.fit.drawn).
withTree("a look adds no measuring or gradient to a repaint", CROWD, function(ns, scenario)
	local r = upIn(ns, scenario, "leather", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local kit = r.look and r.look.kit
	if not kit then
		fail(scenario, "SKIPPED -- Leather is not the look in use")
		return
	end
	ns.addon:Tick()
	local measured, graded = 0, 0
	local width, gradient = kit.TextWidth, kit.Gradient
	kit.TextWidth = function(...) measured = measured + 1 return width(...) end
	kit.Gradient = function(...) graded = graded + 1 return gradient(...) end
	for _ = 1, 5 do
		Mock.advance(0.4)
		ns.addon:Tick()
	end
	kit.TextWidth, kit.Gradient = width, gradient
	if not (r.count:IsShown() and r.rows[1]:IsShown()) then
		fail(scenario, "SKIPPED -- the count and the list are not both up")
	elseif measured > 0 or graded > 0 then
		fail(scenario, ("five repaints of the same panel measured %d time(s) and graded %d time(s)")
			:format(measured, graded))
	end
end)

-- ------------------------------------------------------------------ 24
-- Every translation has the verdict words now: on a German client each of
-- the new looks says the verdict in German, and the name stays where it was.
for _, style in ipairs({ "ribbon", "letter", "leather", "forge", "archmage", "lightbringer", "fel", "wild" }) do
	withTree(style .. " says the verdict in German", ANNA, function(ns, scenario)
		local r = upIn(ns, scenario, style)
		if not (r.look and ns.Looks.Get(style) == r.look) then
			fail(scenario, "SKIPPED -- " .. style .. " is not the look in use")
			return
		end
		local L = ns.L
		for _, k in ipairs({ "buffed", "sent, unconfirmed", "could not buff" }) do
			if rawget(L, k) == nil then fail(scenario, "the German translation has no word for \"" .. k .. "\"") end
		end
		local function said(text) return text end
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		if r.sub:GetText() ~= said(L["buffed"]) then
			fail(scenario, "a landed buff on a German client does not say " .. L["buffed"] .. ": "
				.. tostring(r.sub:GetText()))
		end
		if tostring(r.name:GetText()):find(said("Anna"), 1, true) ~= 1 then
			fail(scenario, "a landed buff on a German client moved the name: " .. tostring(r.name:GetText()))
		end
		Mock.advance(3)
		ns.addon:Tick()
		ns.Prompt:ShowOutcome("sent", "Anna Aim")
		if r.sub:GetText() ~= said(L["sent, unconfirmed"]) then
			fail(scenario, "an unconfirmed cast on a German client does not say " .. L["sent, unconfirmed"]
				.. ": " .. tostring(r.sub:GetText()))
		end
	end, function() Mock.locale = "deDE" end)
end
