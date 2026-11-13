-- What the default look wears (Looks/Glass.lua, a dressing over the glass
-- Prompt/Panel.lua draws): the gryphons at its ends, the gilt rails, the light
-- in the glass, the ready border round the icon, the gilt catching the light.
-- Every scenario here is named "look-glass: ...".
--
-- Run on the recording CreateFrame in tests/frametree.lua. The pane, the
-- bezel, the text and the lights Panel.lua draws are held by the scenarios
-- they always had; nothing here asks about them again.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local ART = "Interface\\AddOns\\Manners\\Textures\\Glass\\Glass_"
-- Every file the generator writes, as the Lua names them without Glass_.
local FILES = { "GryphonL", "GryphonR", "GryphonLitL", "GryphonLitR", "Eye", "Rail", "Caustic", "Ants", "AntsGlow", "Star" }
-- What Looks/Glass.lua and the generator agree on, and the figures read here.
local EYE_X, EYE_Y = 91 / 256, 68 / 256
local GRYPHON_OVER, GRYPHON_IN, RAIL_TILE, ANT_TILE = 18, 0.10, 16, 16
local CAUSTIC_ALPHA, COMBAT_GILT, FLOURISH = 0.085, 0.5, 0.6

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
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.01)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in the default look with its gryphons switched on, a
-- passer-by on it (or Anna owed).
local function up(ns, scenario, owed, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.effects, p.flashStyle, p.gryphons = "full", "pulse", true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	if owed then owe(ns, "Anna Aim") end
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.dress
end

local function skipped(scenario, dress)
	if dress and dress.gryphon and dress.antFlow then return false end
	fail(scenario, "SKIPPED -- the glass wears nothing")
	return true
end

local function rectOf(r)
	local x0, x1 = FT.span(r, "x")
	local y0, y1 = FT.span(r, "y")
	if not (x0 and y0) then return nil end
	return { x0, y0, x1, y1 }
end

local function fight(ns, on)
	Mock.inCombat = on
	if on then
		ns.addon:PLAYER_REGEN_DISABLED()
	elseif ns.addon.PLAYER_REGEN_ENABLED then
		ns.addon:PLAYER_REGEN_ENABLED()
	end
end

local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

-- ------------------------------------------------------------------ 1
withTree("look-glass: the art is there, each file a power of two and 32 bits", ANNA, function(ns, scenario)
	for _, name in ipairs(FILES) do
		local h = header(dir .. "/Textures/Glass/Glass_" .. name .. ".tga")
		if not h then
			fail(scenario, "Textures/Glass/Glass_" .. name .. ".tga is missing")
		else
			for _, side in ipairs({ h.width, h.height }) do
				if side < 1 or side > 256 or math.floor(math.log(side) / math.log(2) + 0.5) ~= math.log(side) / math.log(2) then
					fail(scenario, name .. " is " .. h.width .. "x" .. h.height)
				end
			end
			if h.bits ~= 32 or h.imageType ~= 2 then fail(scenario, name .. " is not a 32-bit uncompressed TGA") end
		end
	end
	-- And nothing drawn names a file that is not written.
	local _, _, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	local known = {}
	for _, name in ipairs(FILES) do known[(ART .. name):lower()] = true end
	for _, t in ipairs(dress.own) do
		if not known[tostring(t._file):lower()] then fail(scenario, "a texture draws " .. tostring(t._file)) end
	end
	local toc = io.open(dir .. "/Manners.toc", "rb"):read("*a")
	local flow, looks, glass = toc:find("Looks\\Flow.lua", 1, true), toc:find("Looks\\Looks.lua", 1, true), toc:find("Looks\\Glass.lua", 1, true)
	if not (flow and looks and glass and looks < flow and flow < glass) then
		fail(scenario, "the toc does not load Looks.lua, Flow.lua and Glass.lua in that order")
	end
end)

-- ------------------------------------------------------------------ 2
withTree("look-glass: a gryphon at each end, an eye in each, and rails along the pane", ANNA, function(ns, scenario)
	for _, size in ipairs({ { 220, 44 }, { 320, 58 }, { 160, 26 }, { 420, 100 } }) do
		local r, p, dress = up(ns, scenario, false, function(p) p.width, p.height = size[1], size[2] end)
		if skipped(scenario, dress) then return end
		local W, Ht = size[1], size[2]
		local pane = rectOf(r.art)
		local G = math.max(34, math.min(140, Ht + GRYPHON_OVER))
		for i = 1, 2 do
			local g = dress.gryphon[i]
			local box = rectOf(g)
			if not (g:IsShown() and box) then
				fail(scenario, "gryphon " .. i .. " is not up at " .. W .. "x" .. Ht)
			else
				if not (near(box[3] - box[1], G) and near(box[4] - box[2], G)) then
					fail(scenario, ("gryphon %d is %.1f tall at a pane %d tall, not %.1f"):format(i, box[4] - box[2], Ht, G))
				end
				-- Outside the pane but for a tenth of itself, which reaches in.
				local inside = i == 1 and (box[3] - pane[1]) or (pane[3] - box[1])
				if not near(inside, G * GRYPHON_IN, 0.05) then
					fail(scenario, ("gryphon %d reaches %.1f in over the pane, not %.1f"):format(i, inside, G * GRYPHON_IN))
				end
				if box[4] <= pane[4] then fail(scenario, "gryphon " .. i .. " does not stand over the pane's top") end
				-- Its eye where the file has it: the right one's file is drawn
				-- looking the other way.
				local eye = rectOf(dress.eye[i])
				local ex = (eye[1] + eye[3]) / 2 - box[1]
				local ey = box[4] - (eye[2] + eye[4]) / 2
				local wantX = G * (i == 1 and EYE_X or 1 - EYE_X)
				if not (near(ex, wantX, 0.05) and near(ey, G * EYE_Y, 0.05)) then
					fail(scenario, ("gryphon %d's eye is at %.1f, %.1f of its file, not %.1f, %.1f"):format(i, ex, ey, wantX, G * EYE_Y))
				end
			end
			if dress.lit[i]._blend ~= "ADD" or (dress.lit[i]:GetAlpha() or 1) > 0.001 then
				fail(scenario, "gryphon " .. i .. "'s light is up at rest")
			end
		end
		if not tostring(dress.gryphon[1]._file):find("GryphonL", 1, true) or not tostring(dress.gryphon[2]._file):find("GryphonR", 1, true) then
			fail(scenario, "the ends do not each have their own gryphon")
		end
		-- The rails: whole tiles' worth along the pane, the bottom one flipped.
		for _, rail in ipairs({ dress.railTop, dress.railBottom }) do
			local box, c = rectOf(rail), rail._texCoord or {}
			if not (rail:IsShown() and box and near(box[1], pane[1]) and near(box[3], pane[3])) then
				fail(scenario, "a rail does not run the pane's length at " .. W .. "x" .. Ht)
			end
			if not near((c[2] or 0) - (c[1] or 0), W / RAIL_TILE, 0.001) then
				fail(scenario, ("a rail shows %.2f tiles along %d units"):format((c[2] or 0) - (c[1] or 0), W))
			end
		end
		local top, bottom = dress.railTop._texCoord, dress.railBottom._texCoord
		if not (top[3] < top[4] and bottom[3] > bottom[4]) then fail(scenario, "the bottom rail is not the top one upside down") end
	end
end)

-- ------------------------------------------------------------------ 3
withTree("look-glass: Gryphons at the ends takes them away, and another look takes it all off", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	local control = H.findOption(ns.optionsTable, "gryphons")
	if not control then fail(scenario, "Look has no switch for the gryphons") return end
	if control.disabled() then fail(scenario, "the switch is greyed on Glass") end
	-- Off as the look comes (the setting as it is before anybody touches it),
	-- and off when it is switched off.
	if ns.defaults.profile.prompt.gryphons ~= false then fail(scenario, "as the look comes, a piece of gryphon is asked for by default") end
	for _, how in ipairs({ { nil, "as the look comes" }, { false, "with the switch off" } }) do
		p.gryphons = how[1]
		ns.Prompt:ApplyStyle()
		tick(ns)
		for i = 1, 2 do
			for _, t in ipairs({ dress.gryphon[i], dress.lit[i], dress.eye[i] }) do
				if t:IsShown() then fail(scenario, how[2] .. ", a piece of gryphon " .. i .. " is up") end
			end
		end
		if not dress.railTop:IsShown() then fail(scenario, how[2] .. ", the rails are gone as well") end
	end
	p.gryphons = true
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not dress.gryphon[1]:IsShown() then fail(scenario, "switched on, the gryphons did not come") end
	-- Another look of Panel.lua's, then one from Looks/: nothing of Glass's left.
	for _, style in ipairs({ "framed", "forge" }) do
		p.style = style
		ns.Prompt:ApplyStyle()
		tick(ns)
		if ns.Prompt:Regions().dress then fail(scenario, style .. " still wears the glass's dressing") end
		if not control.disabled() then fail(scenario, "the switch is live on " .. style) end
		for _, t in ipairs(dress.own) do
			if FT.visible(t) then fail(scenario, "on " .. style .. " a piece of Glass's is still drawn: " .. tostring(t._file)) break end
		end
		if dress.flow.driver:IsShown() then fail(scenario, "on " .. style .. " Glass's clock still runs") end
		for _, g in ipairs(dress.anims) do
			if g._playing then fail(scenario, "on " .. style .. " an animation of Glass's still plays") break end
		end
	end
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not (ns.Prompt:Regions().dress == dress and dress.gryphon[1]:IsShown()) then fail(scenario, "back on Glass, the gryphons did not come back") end
end)

-- ------------------------------------------------------------------ 4
withTree("look-glass: light drifts in the glass at rest on Full; not on Calm, in a fight or with the prompt down", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	local function resting()
		local n = 0
		for _, h in ipairs(dress.causticFlow) do if h:IsPlaying() then n = n + 1 end end
		for _, g in ipairs(dress.eyeGlint) do if g._playing then n = n + 1 end end
		return n
	end
	if resting() ~= #dress.causticFlow + 2 then fail(scenario, "at rest on Full only " .. resting() .. " of the lights run") end
	if #dress.idle ~= 2 then fail(scenario, "what loops at rest is not named: " .. #dress.idle) end
	for i, t in ipairs(dress.caustic) do
		if not near(t:GetAlpha(), CAUSTIC_ALPHA, 0.001) then fail(scenario, "sheet " .. i .. " of the light is at " .. tostring(t:GetAlpha())) end
		if t._blend == "ADD" then fail(scenario, "the light in the glass is additive at rest") end
		local wrap = t._ft or {}
		if wrap.wrapH ~= "REPEAT" or wrap.wrapV ~= "REPEAT" then fail(scenario, "sheet " .. i .. " does not wrap, so it cannot scroll") end
	end
	-- The two sheets cross: neither moves as the other does.
	local a, b = dress.causticFlow[1], dress.causticFlow[2]
	if a.du * b.du >= 0 then fail(scenario, "the two sheets of light drift the same way") end
	-- It moves: the window is somewhere else two seconds on.
	local before = dress.caustic[1]._texCoord[1]
	Mock.advance(2)
	dress.flow:Tick(GetTime())
	if near(dress.caustic[1]._texCoord[1], before, 0.0005) then fail(scenario, "two seconds on, the light has not moved") end
	-- The window is the pane's size in tiles, so the light is never stretched.
	p.width = 320
	ns.Prompt:ApplyStyle()
	tick(ns)
	local c = dress.caustic[1]._texCoord
	if not near(c[2] - c[1], (320 - 2) / 72, 0.01) then fail(scenario, ("on a pane 320 wide the light shows %.2f tiles"):format(c[2] - c[1])) end

	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if resting() ~= 0 then fail(scenario, "on Calm " .. resting() .. " of the lights still run") end
	if dress.flow.driver:IsShown() then fail(scenario, "on Calm the clock runs") end
	if (dress.caustic[1]:GetAlpha() or 1) > 0.001 then fail(scenario, "on Calm the light stays in the glass, still") end
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if resting() == 0 then fail(scenario, "back on Full nothing runs") end

	p.hideInCombat = false
	fight(ns, true)
	tick(ns)
	if resting() ~= 0 then fail(scenario, "in a fight " .. resting() .. " of the lights still run") end
	local v = dress.gryphon[1]._color or {}
	if not near(v[1], COMBAT_GILT) then fail(scenario, "in a fight the gilt is at " .. tostring(v[1])) end
	fight(ns, false)
	tick(ns)
	if resting() == 0 then fail(scenario, "after the fight nothing runs") end
	v = dress.gryphon[1]._color or {}
	if not near(v[1], 1) then fail(scenario, "after the fight the gilt stays dim") end

	-- Nobody left: the prompt comes down and nothing of Glass's goes on.
	strangers({})
	ns.BlockPerson("Anna Aim")
	for _ = 1, 4 do
		Mock.advance(3)
		tick(ns)
	end
	if ns.Prompt:GetButton():IsShown() then
		fail(scenario, "SKIPPED -- the panel did not come down with nobody left")
	elseif resting() ~= 0 or dress.flow.driver:IsShown() then
		fail(scenario, "with the prompt down " .. resting() .. " of the lights still run")
	end
	-- Somebody new walks up: the prompt comes back, and the light with it.
	strangers({ nameplate1 = { "Bert", "Beside" } })
	owe(ns, "Bert Beside")
	for _ = 1, 12 do
		Mock.advance(1)
		tick(ns)
		if ns.Prompt:GetButton():IsShown() then break end
	end
	tick(ns)
	if not ns.Prompt:GetButton():IsShown() then
		fail(scenario, "SKIPPED -- the panel did not come back for somebody new")
	elseif resting() == 0 then
		fail(scenario, "somebody is on the prompt again, and the light does not come back")
	end
end)

-- ------------------------------------------------------------------ 5
withTree("look-glass: somebody owed runs the ready border round the icon, in their colour", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario, true)
	if skipped(scenario, dress) then return end
	-- Its fade in over.
	Mock.advance(0.5)
	FT.settle()
	local ants = dress.antsFrame
	if not (ants:IsShown() and near(ants:GetAlpha(), 1)) then fail(scenario, "with Anna owed the border is not up") end
	local bezel = math.min(p.iconSize / 0.75, p.height - 1)
	local box, icon = rectOf(ants), rectOf(r.icon)
	if not (box and near((box[1] + box[3]) / 2, (icon[1] + icon[3]) / 2) and near(box[3] - box[1], bezel + 2)) then
		fail(scenario, "the border does not sit round the bezel")
	end
	-- Four strips of one file, each along its own side, the dash handed on.
	local span = (bezel + 2) / ANT_TILE
	for i = 1, 4 do
		local h = dress.antFlow[i]
		if not h:IsPlaying() then fail(scenario, "side " .. i .. " of the border does not run") end
		if (h.turn or 0) ~= i - 1 then fail(scenario, "side " .. i .. " is laid at " .. tostring(h.turn) .. " quarter turns") end
		if not near(h.uSpan, span, 0.001) then fail(scenario, ("side %d shows %.2f tiles of %.2f"):format(i, h.uSpan, span)) end
		if h.du >= 0 then fail(scenario, "side " .. i .. "'s dash runs backwards") end
		if #(dress.ants[i]._texCoord or {}) ~= (i == 1 and 4 or 8) then fail(scenario, "side " .. i .. " is not turned onto its side") end
	end
	for i = 2, 4 do
		local lag = (dress.antFlow[i - 1].u0 - dress.antFlow[i].u0) % 1
		if not near(lag, span % 1, 0.001) then fail(scenario, ("side %d starts %.3f of a tile after side %d, not %.3f"):format(i, lag, i - 1, span % 1)) end
	end
	if not dress.breath._playing then fail(scenario, "the bloom under the border does not breathe") end
	for i = 1, 2 do
		if not dress.eyeBurn[i]._playing then fail(scenario, "gryphon " .. i .. "'s eye does not burn") end
		if dress.eyeGlint[i]._playing then fail(scenario, "gryphon " .. i .. "'s eye glints as at rest with somebody owed") end
	end
	-- In the reason's colour, taken towards white, never additive at rest.
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	local v = dress.bloom._color or {}
	if not (near(v[1], cr) and near(v[2], cg) and near(v[3], cb)) then fail(scenario, "the bloom is not in the owed colour") end
	for i = 1, 4 do
		if dress.ants[i]._blend == "ADD" then fail(scenario, "the border is additive while it runs") end
	end

	-- Calm: the border stands, lit and still.
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if not ants:IsShown() then fail(scenario, "on Calm the border is gone with somebody owed") end
	for i = 1, 4 do
		if dress.antFlow[i]:IsPlaying() then fail(scenario, "on Calm side " .. i .. " still runs") end
	end
	if dress.breath._playing or dress.eyeBurn[1]._playing then fail(scenario, "on Calm something of Glass's loops") end
	p.effects = "full"
	-- No icon, no border.
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if FT.visible(dress.ants[1]) then fail(scenario, "with the icon off the border is drawn round nothing") end
	p.showIcon = true
	ns.Prompt:ApplyStyle()
	tick(ns)
	-- The favour done: the border comes down, the light at rest comes back.
	wipe(ns.owed)
	tick(ns)
	tick(ns)
	if ants:IsShown() then fail(scenario, "nobody owed any more, and the border is still up") end
	for i = 1, 4 do
		if dress.antFlow[i]:IsPlaying() then fail(scenario, "nobody owed, and side " .. i .. " still runs") end
	end
	if not dress.eyeGlint[1]._playing then fail(scenario, "nobody owed, and the eyes do not go back to their glint") end
end)

-- ------------------------------------------------------------------ 6
withTree("look-glass: a favour catches the gilt, a landing flashes it and winks the star", ANNA, function(ns, scenario)
	local r, p, dress = up(ns, scenario)
	if skipped(scenario, dress) then return end
	-- A favour just done.
	owe(ns, "Anna Aim")
	tick(ns)
	local caught = 0
	for _, g in ipairs(dress.catch) do caught = caught + (g._plays or 0) end
	if caught < 2 then fail(scenario, "a favour just done did not catch the gilt of both gryphons") end
	for i, g in ipairs(dress.catch) do
		if FT.groupLength(g) > FLOURISH + 0.001 then fail(scenario, ("gryphon %d's flash lasts %.2f s"):format(i, FT.groupLength(g))) end
	end
	Mock.advance(1)
	FT.settle()
	local before = dress.wink._plays or 0
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	if (dress.wink._plays or 0) ~= before + 1 then fail(scenario, "a landing did not wink the star") end
	if FT.groupLength(dress.wink) > FLOURISH + 0.001 then fail(scenario, ("the star lasts %.2f s"):format(FT.groupLength(dress.wink))) end
	local again = 0
	for _, g in ipairs(dress.catch) do again = again + (g._plays or 0) end
	if again < caught + 2 then fail(scenario, "a landing did not flash the gilt") end
	-- A landing is brighter than a favour.
	if not (dress.catch[1].up._toAlpha and dress.catch[1].up._toAlpha > 0.8) then fail(scenario, "a landing's flash peaks at " .. tostring(dress.catch[1].up._toAlpha)) end
	-- Everything goes back to nothing.
	Mock.advance(1)
	FT.settle()
	for i = 1, 2 do
		if (dress.lit[i]:GetAlpha() or 1) > 0.001 then fail(scenario, "gryphon " .. i .. "'s light is left on after the flash") end
	end
	if (dress.star:GetAlpha() or 1) > 0.001 then fail(scenario, "the star is left on") end
	-- A refusal is Panel.lua's; Glass adds nothing to it.
	local wink = dress.wink._plays or 0
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "x")
	if (dress.wink._plays or 0) ~= wink then fail(scenario, "a refusal winks the star") end
	-- Nor in a fight.
	p.hideInCombat = false
	fight(ns, true)
	tick(ns)
	local n = 0
	for _, g in ipairs(dress.catch) do n = n + (g._plays or 0) end
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "y")
	local m = 0
	for _, g in ipairs(dress.catch) do m = m + (g._plays or 0) end
	if m ~= n then fail(scenario, "in a fight a landing still flashes the gilt") end
end)
