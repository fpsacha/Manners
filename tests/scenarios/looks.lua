-- The looks: the three Prompt.lua draws and the ones in Looks/, Luxe first.
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

local STYLES = { "glass", "framed", "minimal", "luxe", "toast", "arcane" }
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

-- Every state tools/render_prompt.py draws, driven in turn on one prompt.
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
		for _, e in ipairs(errorsSince(ns, from)) do fail(scenario, "guarded: " .. e) end
	end)
end

-- ------------------------------------------------------------------ 2
-- Luxe says why in three places -- the spine, the ring round the icon and the
-- tag -- in the palette's colour for each reason, both palettes; with the
-- marker off they go neutral, and "stripe" leaves the ring out.
withTree("Luxe carries the reason on the spine, the ring and the tag", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.spine) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
			ns.Prompt:ApplyStyle()
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			if not sameColour(look.spine._color, cr, cg, cb) then
				fail(scenario, ("the spine is not in %s's colour in the %s set"):format(reason, palette))
			end
			if not sameColour(look.ring._color, cr, cg, cb) or look.ring._shown == false then
				fail(scenario, ("the ring round the icon is not in %s's colour in the %s set")
					:format(reason, palette))
			end
			if not sameColour(look.pillEdge[2]._color, cr, cg, cb) then
				fail(scenario, ("the tag's edge is not in %s's colour in the %s set"):format(reason, palette))
			end
		end
	end
	p.reasonPalette = "standard"
	p.accentMode = "off"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	if not sameColour(look.spine._color, 0.55, 0.56, 0.62) then
		fail(scenario, "with the marker off the spine still carries the reason's colour")
	end
	p.accentMode = "stripe"
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	if look.ring._shown ~= false then
		fail(scenario, "with the marker on the stripe only, the ring round the icon is still coloured")
	end
end)

-- ------------------------------------------------------------------ 3
-- Calm: nothing loops. The pulse only while somebody owed is on top.
withTree("Luxe on Calm leaves nothing looping", CROWD, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.pulseAnim) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	if not look.pulseAnim._playing then
		fail(scenario, "somebody owed on top on Full, and the spine does not breathe")
	end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FT.settle()
	if looping() > 0 then
		fail(scenario, ("%d animation(s) loop on Calm with somebody owed on top"):format(looping()))
	end
	if not near(look.pulseFrame._alpha, 0.25) then
		fail(scenario, "on Calm the owed glow is not held still at 0.25: " .. tostring(look.pulseFrame._alpha))
	end
	-- Nobody owed: the glow goes, loop or not.
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	wipe(ns.owed)
	ns.addon:Tick()
	FT.settle()
	if look.pulseAnim._playing or (look.pulseFrame._alpha or 0) > 0 then
		fail(scenario, "the owed pulse kept going with nobody owed on top")
	end
end)

-- ------------------------------------------------------------------ 4
-- A fight: the card holds, the ink recedes, the reason stays.
withTree("Luxe in a fight keeps the reason readable", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.spine) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	local before = look.spine._color and { look.spine._color[1], look.spine._color[2], look.spine._color[3] }
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	FT.settle()
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	if (r.art._alpha or 1) < 0.99 then
		fail(scenario, "art dimmed whole in a fight (" .. tostring(r.art._alpha) .. "), card and all")
	end
	if not near(look.card[5]._alpha, 0.92) then
		fail(scenario, "the card does not hold at 0.92 in a fight: " .. tostring(look.card[5]._alpha))
	end
	if not near(r.icon._alpha, 0.62) then fail(scenario, "the ink does not recede in a fight") end
	if not (before and sameColour(look.spine._color, before[1], before[2], before[3]))
		or (look.spine._alpha or 1) < 1 then
		fail(scenario, "the spine lost the reason's colour in a fight")
	end
	if look.ring._shown == false then fail(scenario, "the ring round the icon went in a fight") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	ns.addon:Tick()
	FT.settle()
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the fight") end
	if not near(r.icon._alpha or 1, 1) or not near(look.card[5]._alpha or 1, 1) then
		fail(scenario, "the fight's dim stayed on after it ended")
	end
end)

-- ------------------------------------------------------------------ 5
-- The settings every look honours, read off where Luxe put things.
withTree("Luxe honours the second line, the count, the list and the icon", CROWD, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local look = r.look
	if not (look and look.pillFrame) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	-- Two lines at the default size, the tag hugging its words.
	if not (r.sub:IsShown() and look.pillFrame._shown ~= false) then
		fail(scenario, "the tag is not up at the default size")
	end
	if not (look.chipFill[2]._shown ~= false and r.count._shown ~= false) then
		fail(scenario, "three more people waiting and no count chip")
	end
	-- The list below: the tray under the card, rows hanging from its bottom.
	local row = r.rows[1]
	local at = row.points[#row.points]
	if not (look.tray[5]._shown ~= false and at and at[3] == "BOTTOMLEFT" and at[5] < 0) then
		fail(scenario, "the list below the panel is not hung under it")
	end
	for _, bar in ipairs(r.bars) do
		if FT.visible(bar) then fail(scenario, "the glass look's list bars show under Luxe") break end
	end
	-- Above.
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	at = row.points[#row.points]
	if not (at and at[3] == "TOPLEFT" and at[5] > 0) then
		fail(scenario, "the list above the panel is not hung over it")
	end
	-- No second line, no count.
	p.showSub, p.showCount = false, false
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if r.sub:IsShown() or look.pillFrame._shown ~= false then
		fail(scenario, "the second line switched off and the tag is still up")
	end
	if look.chipFill[2]._shown ~= false then fail(scenario, "the count switched off and its chip is up") end
	-- A round icon: the round mask, the round ring.
	p.roundIcon = true
	ns.Prompt:ApplyStyle()
	if not (tostring(look.mask._file):find("IconMaskRound", 1, true)
		and tostring(look.ring._file):find("IconRingRound", 1, true)) then
		fail(scenario, "the round icon kept the square mask or ring")
	end
	if r.icon._mask ~= look.mask then fail(scenario, "the icon is not shaped by Luxe's mask") end
	-- The height two lines need is the look's own, and the others keep theirs.
	if ns.TwoLineHeight(13, "luxe") ~= 42 or ns.TwoLineHeight(13, "glass") ~= 39 then
		fail(scenario, ("two lines need %s on Luxe and %s on glass, not 42 and 39")
			:format(tostring(ns.TwoLineHeight(13, "luxe")), tostring(ns.TwoLineHeight(13, "glass"))))
	end
end)

-- ------------------------------------------------------------------ 6
-- Switching looks leaves nothing of the old one on screen, and gives back
-- what it borrowed, whichever way and however often.
withTree("switching looks leaves no region of the old one showing", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe", function(pp) pp.roundIcon = true end)
	local luxe = r.look
	if not (luxe and luxe.own) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	local function check(style, round)
		p.style = style
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local now = ns.Prompt:Regions()
		if style == "glass" or style == "framed" or style == "minimal" then
			for i, x in ipairs(luxe.own) do
				if FT.visible(x) then
					fail(scenario, ("Luxe's region %d still shows after switching to %s"):format(i, style))
					break
				end
			end
			if now.icon._mask == luxe.mask then fail(scenario, "Luxe's mask still shapes the icon on glass") end
			if now.icon._desaturated or not near(now.icon._alpha or 1, 1) then
				fail(scenario, "the icon kept Luxe's dim after switching to glass")
			end
			if now.sub._parent ~= now.textLayer then
				fail(scenario, "the reason line is still inside Luxe's tag after switching to glass")
			end
			if (now.textLayer._level or 0) ~= (now.art._level or 0) + 1 then
				fail(scenario, "textLayer kept Luxe's frame level on glass")
			end
			for _, f in ipairs({ now.glow, now.burst, now.shine }) do
				if f._shown == false then fail(scenario, "a glass frame of light stayed hidden after Luxe") break end
			end
			if style == "glass" and now.panel._shown == false then
				fail(scenario, "the glass panel did not come back after Luxe")
			end
			local hl = ns.Prompt:GetButton():GetHighlightTexture()
			if hl and hl._color and not near(hl._color[4], 0.045) then
				fail(scenario, "the button's highlight stayed off after Luxe")
			end
		else
			for i, x in ipairs(now.builtin or {}) do
				if FT.visible(x) then
					fail(scenario, ("a glass region (%d) still shows under %s"):format(i, style))
					break
				end
			end
			if round and now.icon._mask ~= luxe.mask then
				fail(scenario, "switching back to " .. style .. " did not shape the icon again")
			end
		end
	end
	for _, style in ipairs({ "glass", "luxe", "framed", "toast", "minimal", "arcane", "glass", "luxe" }) do
		check(style, true)
	end
end)

-- ------------------------------------------------------------------ 7
-- The outcome: the name stays, the tag becomes the verdict, and the next paint
-- takes it back.
withTree("Luxe turns the tag into the verdict", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.glyph) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local named = tostring(r.name:GetText())
	if not named:find("Anna", 1, true) or named:find("buffed", 1, true) then
		fail(scenario, "a landed buff moved the name: " .. named)
	end
	if r.sub:GetText() ~= "buffed" or look.glyph._shown == false
		or not tostring(look.glyph._file):find("Check", 1, true) then
		fail(scenario, "a landed buff's tag is not a ticked \"buffed\": " .. tostring(r.sub:GetText()))
	end
	if not sameColour(look.spine._color, 0.52, 0.90, 0.52) then
		fail(scenario, "a landed buff did not turn the spine green")
	end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if r.sub:GetText() ~= "Out of range." or not tostring(look.glyph._file):find("Cross", 1, true) then
		fail(scenario, "a refusal's tag is not the game's words with a cross: " .. tostring(r.sub:GetText()))
	end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	Mock.advance(2)
	ns.addon:Tick()
	if look.glyph._shown ~= false or r.sub:GetText() == "Out of range." then
		fail(scenario, "the verdict stayed on the tag after the outcome ran out")
	end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.spine._color, cr, cg, cb) then
		fail(scenario, "the spine kept the outcome's colour after it ran out")
	end
	-- A cast nobody confirmed claims nothing: no ring, no light.
	local burst, sheen = look.burstAnim._plays, look.sheenAnim._plays
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if look.burstAnim._plays > burst or look.sheenAnim._plays > sheen then
		fail(scenario, "a cast nobody confirmed got Luxe's flourish")
	end
end)

-- ------------------------------------------------------------------ 8
-- A client whose language has no word for the verdict yet keeps the lines
-- that are translated rather than putting English in a German panel.
withTree("Luxe keeps translated outcome lines on a German client", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	if not (r.look and r.look.glyph) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if r.sub:GetText() == "buffed" then
		fail(scenario, "a German client's tag reads the English \"buffed\"")
	end
	if not tostring(r.name:GetText()):find("Anna", 1, true) then
		fail(scenario, "the German outcome line lost the name: " .. tostring(r.name:GetText()))
	end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 9
-- The cursor lights the card and lets it go.
withTree("Luxe lights up under the cursor", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.hoverAnim) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	if not (look.hoverAnim._playing and look.hoverAnim.to == 1) then
		fail(scenario, "the cursor on the panel did not light it")
	end
	b.scripts.OnLeave(b)
	if look.hoverAnim.to ~= 0 then fail(scenario, "the cursor left and the light stayed") end
	local hl = b:GetHighlightTexture()
	if hl and hl._color and hl._color[4] ~= 0 then
		fail(scenario, "the square highlight shows past Luxe's rounded corners")
	end
end)

-- ------------------------------------------------------------------ 10
-- A class colour is taken towards white, so it never reads as a reason.
withTree("Luxe softens class-coloured names", { nameplate1 = { "Mira", "Vale" } }, function(ns, scenario)
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "luxe"
	ns.Prompt:ApplyStyle()
	local entry = { name = "Mira Vale", short = "Mira", class = "MAGE", reason = "nearby" }
	local text = ns.Prompt:RenderPrimary(entry, 0)
	if text:find("ff40c7eb", 1, true) then
		fail(scenario, "a mage's name is drawn in the full class colour on Luxe: " .. text)
	end
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	text = ns.Prompt:RenderPrimary(entry, 0)
	if not text:find("ff40c7eb", 1, true) then
		fail(scenario, "the glass look no longer draws the class colour as it is: " .. text)
	end
end)

-- ------------------------------------------------------------------ 11
-- The name wins: a count chip that would leave the name cut is left out.
withTree("Luxe's count chip steps aside for a long name", CROWD, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe", function(pp) pp.width = 150 end)
	local look = r.look
	if not (look and look.chipFill) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "owed",
		buff = ns.ResolveBuff(true) }, 3)
	if look.chipFill[2]._shown ~= false then
		fail(scenario, "the count chip stayed up and cut a name that could not shrink to fit")
	end
	p.width = 230
	ns.Prompt:ApplyStyle()
	ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true) }, 3)
	if look.chipFill[2]._shown == false then
		fail(scenario, "a short name and the count chip stepped aside anyway")
	end
end)

-- ------------------------------------------------------------------ 12
-- The registry: every look offered, the stubs drawn as Luxe until written, a
-- saved stub kept, and Luxe the default for a profile that never chose.
withTree("every look is offered, and Luxe is the default", {}, function(ns, scenario)
	local values, sorting = ns.Looks.Choices()
	for _, style in ipairs(STYLES) do
		if type(values[style]) ~= "string" or values[style] == "" then
			fail(scenario, "the Look tab does not offer " .. style)
		end
	end
	if sorting[1] ~= "luxe" then fail(scenario, "Luxe is not first in the dropdown: " .. tostring(sorting[1])) end
	if ns.Looks.Get("toast") ~= ns.Looks.Get("luxe") or ns.Looks.Get("arcane") ~= ns.Looks.Get("luxe") then
		fail(scenario, "a look not written yet does not draw as Luxe")
	end
	if ns.Looks.Get("glass") ~= nil then fail(scenario, "glass is handed to Looks/ instead of Prompt.lua") end
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "toast"
	ns.ClampSettings()
	if ns.db.profile.prompt.style ~= "toast" then
		fail(scenario, "a saved Toast look was reset to " .. tostring(ns.db.profile.prompt.style))
	end
	local option = H.findOption and H.optionsByKey
	if option and ns.optionsTable then
		local style = H.optionsByKey(ns.optionsTable).style
		if style and type(style.values) == "table" and not style.values.luxe then
			fail(scenario, "the options page's style dropdown has no Luxe")
		end
	end
	-- The addon as shipped, loaded by hand: load() pins the older scenarios
	-- to glass.
	local shipped = {}
	for _, file in ipairs(ADDON_FILES) do
		local chunk = assert(loadfile(dir .. "/" .. file))
		chunk("Manners", shipped)
	end
	if shipped.defaults.profile.prompt.style ~= "luxe" then
		fail(scenario, "the default look is " .. tostring(shipped.defaults.profile.prompt.style) .. ", not Luxe")
	end
end)
