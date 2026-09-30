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
			local found = false
			for _, word in ipairs(words) do
				if said:find(word, 1, true) then found = true end
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
	-- The height two lines need is the look's own, never more than glass's
	-- (Luxe draws the tag tight below its full height), and glass keeps its.
	if ns.TwoLineHeight(13, "luxe") ~= 39 or ns.TwoLineHeight(13, "glass") ~= 39 then
		fail(scenario, ("two lines need %s on Luxe and %s on glass, not 39 and 39")
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
		-- An outcome with a tick first, which narrows the tag's room further.
		if p.style == "luxe" then
			Mock.advance(3)
			ns.Prompt:ShowOutcome("cast", "Anna Aim")
		end
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
			-- And every other look from Looks/ that has been drawn.
			for key, other in pairs(ns.Looks.list) do
				if other ~= luxe and other.own then
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
				fail(scenario, "the icon kept Luxe's dim after switching to glass")
			end
			if now.sub._parent ~= now.textLayer then
				fail(scenario, "the reason line is still inside Luxe's tag after switching to glass")
			end
			if (now.textLayer._level or 0) ~= (now.art._level or 0) + 1 then
				fail(scenario, "textLayer kept Luxe's frame level on glass")
			end
			if ns.Prompt:LookKit().fit.room[now.sub] ~= nil then
				fail(scenario, "the reason line kept Luxe's room after switching to " .. style)
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
	-- A translation made before the verdict words: they are taken out again,
	-- so this is the path a client without them takes (all eight have them).
	for _, k in ipairs({ "buffed", "sent, unconfirmed", "could not buff" }) do rawset(ns.L, k, nil) end
	if not (r.look and r.look.glyph) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if r.sub:GetText() == "buffed" then
		fail(scenario, "a German client's tag reads the English \"buffed\"")
	end
	-- The name stays put, as in English; the translated sub is the verdict.
	local named = tostring(r.name:GetText())
	if not named:find("Anna", 1, true) or named:find("|c", 1, true) then
		fail(scenario, "the German outcome moved the name: " .. named)
	end
	if r.sub:GetText() ~= ns.L["the game confirmed it"] then
		fail(scenario, "the German tag is not the translated verdict: " .. tostring(r.sub:GetText()))
	end
	-- A sent cast: the translated line on the name, no sentence in a tag.
	Mock.advance(3)
	ns.addon:Tick()
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if r.look.pillFrame._shown ~= false or (r.sub:GetText() or "") ~= "" then
		fail(scenario, "a German sent cast put a sentence in the tag: " .. tostring(r.sub:GetText()))
	end
	named = tostring(r.name:GetText())
	if not named:find("Anna", 1, true) or named == "Anna Aim" then
		fail(scenario, "a German sent cast does not say it on the name line: " .. named)
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
	-- Only a tint on white: every channel at 0.8 or more, so a mage's cyan
	-- never lands on the target reason's.
	local code = text:match("|cff(%x%x%x%x%x%x)")
	for i = 1, 5, 2 do
		if not code or tonumber(code:sub(i, i + 1), 16) < 0xcc then
			fail(scenario, "a mage's name on Luxe is more than a tint on white: " .. text)
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
-- saved stub kept, and Glass the default for a profile that never chose (Luxe was,
-- in 1.5.0, until the game showed its tag white on white).
withTree("every look is offered, and Glass is the default", {}, function(ns, scenario)
	local values, sorting = ns.Looks.Choices()
	for _, style in ipairs(STYLES) do
		if type(values[style]) ~= "string" or values[style] == "" then
			fail(scenario, "the Look tab does not offer " .. style)
		end
	end
	if sorting[1] ~= "luxe" then fail(scenario, "Luxe is not first in the dropdown: " .. tostring(sorting[1])) end
	-- Every look offered is written now, so a stub is registered here to
	-- keep the way a look not written yet draws as another one honest.
	ns.Looks.Register("stub", { name = "stub", order = 99, fallback = "luxe" })
	for key, look in pairs(ns.Looks.list) do
		if look.fallback and ns.Looks.Get(key) ~= ns.Looks.Get(look.fallback) then
			fail(scenario, "a look not written yet does not draw as Luxe")
		end
	end
	ns.Looks.list.stub = nil
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
	if shipped.defaults.profile.prompt.style ~= "glass" then
		fail(scenario, "the default look is " .. tostring(shipped.defaults.profile.prompt.style) .. ", not Glass")
	end
end)

-- ------------------------------------------------------------------ 13
-- With one line there is no tag to turn into the verdict: the name line says
-- it, the built-in looks' way, or a landed buff and a refusal look alike
-- without colour vision.
withTree("Luxe says the verdict on the name line when there is one line", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe")
	if not (r.look and r.look.glyph) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	local function oneLine(label)
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		for _, case in ipairs({ { "cast", "buffed" }, { "failed", "could not buff" }, { "sent", "sent to" } }) do
			Mock.advance(3)
			ns.addon:Tick()
			ns.Prompt:ShowOutcome(case[1], "Anna Aim", case[1] == "failed" and "Out of range." or nil)
			local named = tostring(r.name:GetText())
			if not named:find(case[2], 1, true) then
				fail(scenario, ("%s: a \"%s\" outcome's one line does not say so: %s"):format(label, case[1], named))
			end
		end
	end
	p.showSub = false
	oneLine("second line off")
	p.showSub, p.height = true, 32
	oneLine("32 tall")
	-- A verdict too long for the tag even at its smallest: no pill ending
	-- in an ellipsis, and the name line says it instead.
	p.height = 44
	ns.Prompt:ApplyStyle()
	Mock.advance(3)
	ns.addon:Tick()
	ns.Prompt:ShowOutcome("failed", "Anna Aim", ("Something went wrong with that spell. "):rep(6))
	if r.sub:GetText() ~= "" or r.look.pillFrame._shown ~= false then
		fail(scenario, "a verdict too long for the tag is drawn cut in it: " .. tostring(r.sub:GetText()))
	end
	if not tostring(r.name:GetText()):find("could not buff", 1, true) then
		fail(scenario, "a verdict too long for the tag left the name line without it: "
			.. tostring(r.name:GetText()))
	end
end)

-- ------------------------------------------------------------------ 14
-- The count chip rides the name line: centred on one line, up with the name
-- on two.
withTree("Luxe's count chip sits on the name line", CROWD, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local look = r.look
	if not (look and look.chipBox) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	local function chipY()
		local at = look.chipBox.points[#look.chipBox.points]
		return at and at[5]
	end
	if not near(chipY(), look.nameY) or near(look.nameY, 0) then
		fail(scenario, ("on two lines the chip is at %s, not on the name at %s"):format(tostring(chipY()),
			tostring(look.nameY)))
	end
	p.showSub, p.height = false, 32
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if not near(chipY(), 0) then
		fail(scenario, "on one line the count chip is not on the centred name: y " .. tostring(chipY()))
	end
end)

-- ------------------------------------------------------------------ 15
-- A glass profile moved to Luxe keeps the second line it had: at 13 pt, 39
-- tall is enough for both, the tag drawn tight.
withTree("Luxe keeps two lines wherever glass had them", ANNA, function(ns, scenario)
	for _, case in ipairs({ { 13, 39 }, { 13, 41 }, { 17, 47 }, { 20, 53 } }) do
		local fs, h = case[1], case[2]
		if ns.TwoLineHeight(fs, "luxe") > ns.TwoLineHeight(fs, "glass") then
			fail(scenario, ("at %d pt Luxe needs %d for two lines, glass %d"):format(fs,
				ns.TwoLineHeight(fs, "luxe"), ns.TwoLineHeight(fs, "glass")))
		end
		local r = upIn(ns, scenario, "luxe", function(pp) pp.fontSize, pp.height = fs, h end)
		if not (r.look and r.look.pillFrame) then
			fail(scenario, "SKIPPED -- Luxe is not the look in use")
			return
		end
		if not r.sub:IsShown() or r.look.pillFrame._shown == false then
			fail(scenario, ("%d tall at %d pt lost the reason line on Luxe"):format(h, fs))
		end
		-- The tag inside the card.
		if r.look.pillTop + r.look.pillH > h - 1 then
			fail(scenario, ("%d tall at %d pt: the tag runs off the card"):format(h, fs))
		end
	end
end)

-- ------------------------------------------------------------------ 16
-- Glass's owed pulse stops when Luxe takes over: hidden is not stopped, and
-- Calm stops every loop.
withTree("switching from glass mid-pulse leaves nothing looping on Calm", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "glass")
	if not (r.glow and r.glow.pulse and r.glow.pulse._playing) then
		fail(scenario, "SKIPPED -- glass's owed pulse is not playing")
		return
	end
	p.style = "luxe"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FT.settle()
	if r.glow.pulse._playing then fail(scenario, "glass's pulse still loops under Luxe") end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FT.settle()
	if looping() > 0 then
		fail(scenario, ("%d animation(s) loop on Calm after switching from glass"):format(looping()))
	end
end)

-- ------------------------------------------------------------------ 17
-- The spine keeps its own colour: the light blooms round it, never over it.
withTree("Luxe draws its light under the spine", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.spineFrame) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	local spine = look.spine._parent
	for _, f in ipairs({ look.flareFrame, look.pulseFrame, look.hoverFrame, look.resultFrame }) do
		if (f._level or 0) >= (spine._level or 0) then
			fail(scenario, "a frame of light is drawn over the spine")
			break
		end
	end
	if (spine._level or 0) >= (r.textLayer._level or 0) then fail(scenario, "the spine is drawn over the text") end
	if (spine._alpha or 1) < 1 then fail(scenario, "the spine's frame is not drawn") end
end)

-- ------------------------------------------------------------------ 18
-- "Reason colour: both" does something on Luxe: the card's top edge lit in
-- the reason colour, and the list's too.
withTree("Luxe lights its top edge for \"both\"", CROWD, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local look = r.look
	if not (look and look.edge) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	if FT.visible(look.edge[2]) then fail(scenario, "the reason-lit edge shows on \"icon\"") end
	p.accentMode = "both"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not FT.visible(look.edge[2]) or not sameColour(look.edge[2]._color, cr, cg, cb) then
		fail(scenario, "\"both\" does not light the card's top edge in the reason colour")
	end
	if not FT.visible(look.trayEdge[2]) then fail(scenario, "\"both\" does not light the list's edge") end
end)

-- ------------------------------------------------------------------ 19
-- A line with its own colour gets a tag of that colour, not the reason's;
-- in a fight the tag keeps the reason round the grey words.
withTree("Luxe tints the tag to a line's own colour", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.pillEdge) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	p.locked = false
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if not sameColour(look.pillEdge[2]._color, 1, 0x80 / 255, 0x80 / 255) then
		fail(scenario, "the red \"not buffing while unlocked\" sits in a tag of another colour")
	end
	p.locked = true
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.pillEdge[2]._color, cr, cg, cb) then
		fail(scenario, "the tag kept the unlocked line's red after locking")
	end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	if tostring(r.sub:GetText()):find("|c", 1, true) and not sameColour(look.pillEdge[2]._color, cr, cg, cb) then
		fail(scenario, "in a fight the tag lost the reason's colour round the grey words")
	end
end)

-- ------------------------------------------------------------------ 20
-- In a fight the lines dim themselves, not textLayer, whose cross-fade would
-- replace the dim while it plays; the dim goes with the fight.
withTree("Luxe dims the lines themselves in a fight", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	if not (r.look and r.look.spine) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	if not near(r.name._alpha, 0.80) or not near(r.sub._alpha, 0.80) then
		fail(scenario, ("the lines are not dimmed in a fight: name %s, reason %s"):format(tostring(r.name._alpha),
			tostring(r.sub._alpha)))
	end
	if not near(r.textLayer._alpha or 1, 1) then
		fail(scenario, "the fight's dim is on textLayer, where the cross-fade overrides it")
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	ns.addon:Tick()
	if not near(r.name._alpha or 1, 1) then fail(scenario, "the name stayed dim after the fight") end
	-- Dim, then another look: the lines come back whole.
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	Mock.inCombat = false
	ns.db.profile.prompt.style = "glass"
	ns.Prompt:ApplyStyle()
	if not near(r.name._alpha or 1, 1) or not near(r.sub._alpha or 1, 1) then
		fail(scenario, "the fight's dim stayed on the lines after switching to glass")
	end
end)

-- ------------------------------------------------------------------ 21
-- An unconfirmed cast claims nothing: no wash over the card.
withTree("Luxe washes the card for a verdict, not for a sent cast", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe")
	local look = r.look
	if not (look and look.resultFrame) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not near(look.resultFrame._alpha, 1) then fail(scenario, "a landed buff did not wash the card") end
	Mock.advance(3)
	ns.addon:Tick()
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if (look.resultFrame._alpha or 0) > 0 then
		fail(scenario, "a cast nobody confirmed washed the card")
	end
end)

-- ------------------------------------------------------------------ 22
-- A panel made nearly clear: the text outlined, the tag on a dark ground of
-- its own, and under 0.2 no shadow round nothing.
withTree("Luxe carries its text on a nearly clear panel", ANNA, function(ns, scenario)
	local r, p = upIn(ns, scenario, "luxe", function(pp) pp.bgColor = { 0.04, 0.04, 0.06, 0.1 } end)
	local look = r.look
	if not (look and look.pillFill) then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
		return
	end
	for _, fs in ipairs({ r.name, r.sub }) do
		if not tostring(fs._font and fs._font.flags):find("OUTLINE", 1, true) then
			fail(scenario, "a line on a nearly clear panel is not outlined")
			break
		end
	end
	local c = look.pillFill[2]._color
	if not (c and c[1] < 0.05 and c[2] < 0.05 and c[3] < 0.05 and c[4] >= 0.4) then
		fail(scenario, "the tag has no dark ground of its own on a nearly clear panel")
	end
	if FT.visible(look.shadow[5]) then fail(scenario, "the shadow is drawn round a clear panel") end
	-- Back to the default card: no outline, the tag in the reason's colour.
	p.bgColor = nil
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	if tostring(r.name._font and r.name._font.flags):find("OUTLINE", 1, true) then
		fail(scenario, "the outline stayed on the default card")
	end
	if not FT.visible(look.shadow[5]) then fail(scenario, "the shadow did not come back") end
end)

-- ------------------------------------------------------------------ 23
-- The scan repaints several times a second; Luxe adds no measuring and no
-- gradient to a repaint that changes nothing.
withTree("Luxe adds no measuring or gradient to a repaint", CROWD, function(ns, scenario)
	local r = upIn(ns, scenario, "luxe", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	local kit = r.look and r.look.kit
	if not kit then
		fail(scenario, "SKIPPED -- Luxe is not the look in use")
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
	if not (r.look.chipFill[2]._shown ~= false and r.look.tray[5]._shown ~= false) then
		fail(scenario, "SKIPPED -- the chip and the list are not both up")
	elseif measured > 0 or graded > 0 then
		fail(scenario, ("five repaints of the same panel measured %d time(s) and graded %d time(s)")
			:format(measured, graded))
	end
end)

-- ------------------------------------------------------------------ 24
-- Every translation has the verdict words now: on a German client each of
-- the new looks says the verdict in German, and the name stays where it was.
for _, style in ipairs({ "luxe", "toast", "arcane" }) do
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
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		if r.sub:GetText() ~= L["buffed"] then
			fail(scenario, "a landed buff on a German client does not say " .. L["buffed"] .. ": "
				.. tostring(r.sub:GetText()))
		end
		if tostring(r.name:GetText()):find("Anna", 1, true) ~= 1 then
			fail(scenario, "a landed buff on a German client moved the name: " .. tostring(r.name:GetText()))
		end
		Mock.advance(3)
		ns.addon:Tick()
		ns.Prompt:ShowOutcome("sent", "Anna Aim")
		if r.sub:GetText() ~= L["sent, unconfirmed"] then
			fail(scenario, "an unconfirmed cast on a German client does not say " .. L["sent, unconfirmed"]
				.. ": " .. tostring(r.sub:GetText()))
		end
	end, function() Mock.locale = "deDE" end)
end
