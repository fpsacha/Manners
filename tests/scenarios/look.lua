-- The look and the effects: what the prompt draws, and when it moves.
--
-- Every effect here is art on a frame the addon owns, and a broken one throws
-- nothing: a shine that never plays, a pulse that never stops, a fade that
-- leaves the panel invisible, a glow drawn over the icon it is meant to frame.
-- The only evidence is what the frames were told, so these run on the recording
-- CreateFrame in tests/frametree.lua, which remembers anchors, colours and every
-- Play and Stop -- the mock's own animation groups answer "not playing" to
-- everything, which makes a pulse that runs forever and one that never starts
-- the same pulse.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- Loaded on the recording CreateFrame, and put back afterwards whatever
-- happens, so the files after this one get the mock exactly as it was.
local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		ok, err = pcall(body, ns)
	end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function plays(group) return group and group._plays or 0 end
local function playing(group) return group ~= nil and group._playing == true end

-- Where each region sits, worked out from the anchors the way the client
-- does: two edges on an axis give its extent, one edge and a size the rest.
-- Enough to ask whether two things overlap, which is all it is for.
local function layout(snapshot)
	local byId, rects = {}, {}
	local root
	for _, r in ipairs(snapshot) do
		byId[r.id] = r
		if r.parent == nil then root = r.id end
	end
	local function frac(point)
		local fx, fy = 0.5, 0.5
		if point:find("LEFT", 1, true) then fx = 0 elseif point:find("RIGHT", 1, true) then fx = 1 end
		if point:find("BOTTOM", 1, true) then fy = 0 elseif point:find("TOP", 1, true) then fy = 1 end
		return fx, fy
	end
	local busy = {}
	local function rect(id)
		if rects[id] then return rects[id] end
		if id == root then rects[id] = { 0, 0, 1600, 1000 } return rects[id] end
		local r = byId[id]
		if not r or busy[id] then return nil end
		busy[id] = true
		local L, R, B, T, CX, CY
		for _, p in ipairs(r.points or {}) do
			local rel = rect(p[2] or r.parent)
			if rel then
				local rfx, rfy = frac(p[3] or p[1])
				local ax = rel[1] + (rel[3] - rel[1]) * rfx + (p[4] or 0)
				local ay = rel[2] + (rel[4] - rel[2]) * rfy + (p[5] or 0)
				local fx, fy = frac(p[1])
				if fx == 0 then L = ax elseif fx == 1 then R = ax else CX = ax end
				if fy == 0 then B = ay elseif fy == 1 then T = ay else CY = ay end
			end
		end
		local w, h = r.width or 0, r.height or 0
		if not (L and R) then
			if L then R = L + w elseif R then L = R - w elseif CX then L, R = CX - w / 2, CX + w / 2 end
		end
		if not (B and T) then
			if B then T = B + h elseif T then B = T - h elseif CY then B, T = CY - h / 2, CY + h / 2 end
		end
		busy[id] = nil
		if not (L and R and B and T) then return nil end
		rects[id] = { L, B, R, T }
		return rects[id]
	end
	return rect
end

local function overlaps(a, b)
	return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01
end

-- ------------------------------------------------------------------ look 1
-- The glow frames the icon and never lies over it.
--
-- It was one filled square on a frame of its own, and a child frame draws over
-- everything its parent draws -- so at the top of every pulse the spell icon
-- was washed over with the reason colour until it was a pale smudge. The halo
-- is pieces of a soft glow outside the ring now; if one of them strays onto the
-- icon, the smudge is back. And it stops at the panel's edge: two pixels past
-- it read as bars stuck to the prompt, and lit the framed look's border.
withTree("the glow frames the icon and never lies over it",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "the glow frames the icon and never lies over it"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	if not (r.glowStrips and r.icon and r.glow) then
		fail(scenario, "SKIPPED -- the glow's pieces are not reachable")
		return
	end
	local snap = FT.snapshot(UIParent)
	local rect = layout(snap)
	local iconBox = rect(r.icon._serial)
	local panel = rect(r.art._serial)
	if not (iconBox and panel) then
		fail(scenario, "SKIPPED -- the icon or the panel could not be placed")
		return
	end
	local placed = 0
	for i, strip in ipairs(r.glowStrips) do
		local box = rect(strip._serial)
		if box and box[3] - box[1] > 0 and box[4] - box[2] > 0 then
			placed = placed + 1
			if overlaps(box, iconBox) then
				fail(scenario, ("glow strip %d lies over the spell icon, which washes the icon"
					.. " out at the top of every pulse"):format(i))
			end
			if box[2] < panel[2] - 0.01 or box[4] > panel[4] + 0.01 then
				fail(scenario, ("glow strip %d reaches %.0f past the panel's edge, where it"
					.. " reads as a bar stuck to the prompt"):format(i,
					math.max(panel[2] - box[2], box[4] - panel[4])))
			end
		end
	end
	if placed < 4 then
		fail(scenario, "SKIPPED -- only " .. placed .. " of the glow's strips have a size")
	end
end)

-- ------------------------------------------------------------------ look 2
-- Somebody who buffs you makes the panel catch the light, once -- including a
-- passer-by already on the panel.
--
-- "Flash once" and the stripe's sweep were keyed on a new name reaching the
-- panel. A stranger already being offered who then buffs you keeps the same
-- name, so the one event the setting is named after went by with nothing.
withTree("the panel catches the light when somebody already on it buffs you",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "the panel catches the light when somebody already on it buffs you"
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.flashStyle = "once"
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	local shine, flash = r.shine and r.shine.anim, r.glow and r.glow.anim
	if not (shine and flash) then
		fail(scenario, "SKIPPED -- the shine or the flash is not reachable")
		return
	end
	local top = ns.Prompt:GetButton():IsShown() and ns.BuildQueue()[1]
	if not (top and top.name == "Anna Aim" and top.reason ~= "owed") then
		fail(scenario, "SKIPPED -- Anna was not on the panel as a passer-by")
		return
	end
	local shineBefore, flashBefore = plays(shine), plays(flash)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if plays(shine) == shineBefore then
		fail(scenario, "a passer-by on the panel buffed you and the panel did not catch the light")
	end
	if plays(flash) == flashBefore then
		fail(scenario, "a passer-by on the panel buffed you and Flash once did not flash")
	end
	-- And once: the next scan is the same person, owed the same favour.
	local shineAfter = plays(shine)
	Mock.advance(0.4)
	ns.addon:Tick()
	if plays(shine) ~= shineAfter then
		fail(scenario, "the light played again on a scan that changed nothing")
	end
end)

-- ------------------------------------------------------------------ look 3
-- A landed buff pops and shines, a refusal shakes, and a cast nobody confirmed
-- gets neither.
--
-- The last is on purpose: the settle path only infers that one, and the panel
-- says no more than it does. A flourish is a claim.
withTree("each outcome gets its own motion and only its own",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "each outcome gets its own motion and only its own"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	local burst, shine, shake = r.burst and r.burst.anim, r.shine and r.shine.anim, r.shake
	if not (burst and shine and shake) then
		fail(scenario, "SKIPPED -- the outcome effects are not reachable")
		return
	end
	local function outcome(kind)
		local b, s, k = plays(burst), plays(shine), plays(shake)
		Mock.advance(1)
		ns.Prompt:ShowOutcome(kind, "Anna Aim", kind == "failed" and "Out of range." or nil)
		return plays(burst) > b, plays(shine) > s, plays(shake) > k
	end
	local b, s, k = outcome("cast")
	if not b then fail(scenario, "a buff the game confirmed did not pop the ring") end
	if not s then fail(scenario, "a buff the game confirmed did not send light across the panel") end
	if k then fail(scenario, "a buff that landed shook the text as if it had been refused") end
	b, s, k = outcome("failed")
	if not k then fail(scenario, "a refused buff did not shake") end
	if b or s then fail(scenario, "a refused buff popped or shone as if it had landed") end
	b, s, k = outcome("sent")
	if b or s or k then
		fail(scenario, "a cast nobody confirmed got a flourish, which claims more than the"
			.. " settle path knows")
	end
end)

-- ------------------------------------------------------------------ look 4
-- Calm plays none of the new motion.
withTree("Calm plays none of the new motion",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "Calm plays none of the new motion"
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.effects = "calm"
	ns.Prompt:ApplyStyle()
	local r = ns.Prompt:Regions()
	local groups = { burst = r.burst and r.burst.anim, shine = r.shine and r.shine.anim,
		shake = r.shake, outro = r.outro }
	for name, g in pairs(groups) do
		if not g then
			fail(scenario, "SKIPPED -- no " .. name .. " to watch")
			return
		end
	end
	local before = {}
	for name, g in pairs(groups) do before[name] = plays(g) end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	-- The last buff, with nobody left: the one moment the fade would run.
	ns.BlockPerson("Anna Aim")
	wipe(ns.owed)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	for name, g in pairs(groups) do
		if plays(g) ~= before[name] then
			fail(scenario, "with Effects on Calm the " .. name .. " still played")
		end
	end
end)

-- ------------------------------------------------------------------ look 5
-- The fade on the way out runs only while the panel is going down, and the
-- next person on the panel cancels it.
--
-- It leaves art at nothing when it finishes, because the button is not hidden
-- for another moment. A repaint that did not put the alpha back would paint the
-- next person onto an invisible panel -- a prompt that is there, takes a click
-- and casts, and cannot be seen.
withTree("the fade out is cancelled by the next person and never leaves the panel invisible",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "the fade out is cancelled by the next person and never leaves the panel invisible"
	freshPrompt(ns, scenario)
	local r = ns.Prompt:Regions()
	local outro = r.outro
	if not outro then
		fail(scenario, "SKIPPED -- no fade out to watch")
		return
	end
	-- Only Anna about, owed, pressed and gone: the panel is on its way down.
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	if not button:IsShown() then
		fail(scenario, "SKIPPED -- Anna was not put on the panel")
		return
	end
	-- The fade is for a panel going down, and this one is not.
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if playing(outro) then
		fail(scenario, "the panel started fading out with Anna still on it")
	end
	ns.BlockPerson("Anna Aim")
	wipe(ns.owed)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not playing(outro) then
		fail(scenario, "after the last buff the panel did not fade on its way out")
		return
	end
	-- Played out to the end, where it parks art at nothing.
	Mock.advance(0.61)
	FT.settle()
	if (r.art:GetAlpha() or 1) > 0.01 then
		fail(scenario, "SKIPPED -- the finished fade did not leave the panel at nothing")
		return
	end
	-- Bert walks up before the repaint that would have hidden the button.
	Mock.unitNames.nameplate2 = { "Bert", "Beside" }
	ns.nameplateUnits.nameplate2 = true
	ns.addon:Tick()
	local top = ns.BuildQueue()[1]
	if not (top and button:IsShown()) then
		fail(scenario, "SKIPPED -- nobody came back onto the panel: " .. tostring(top and top.name))
	elseif (r.art:GetAlpha() or 0) < 0.99 then
		fail(scenario, ("%s was painted onto a panel left at alpha %.2f by the fade"):format(
			tostring(top.name), r.art:GetAlpha() or 0))
	elseif playing(outro) then
		fail(scenario, "the fade out went on playing over the next person")
	end
end)

-- ------------------------------------------------------------------ look 6
-- In a fight the effects are art, never the button, and "Stay quiet in combat"
-- keeps the outcome still.
withTree("the effects never touch the secure button in a fight",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "the effects never touch the secure button in a fight"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	local r = ns.Prompt:Regions()
	local burst, shine = r.burst and r.burst.anim, r.shine and r.shine.anim
	if not (burst and shine and button:IsShown()) then
		fail(scenario, "SKIPPED -- the panel or its effects are not there")
		return
	end
	Mock.protect(button)
	local attributes = {}
	for k, v in pairs(button.attributes) do attributes[k] = v end
	Mock.inCombat = true
	Mock.protectedCalls = {}
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.protectedCalls = {}
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now, duration = 1.5 } }
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-1", 1459)
	ns.Prompt:SyncCooldown()
	ns.Prompt:StartAttention(true)
	ns.Prompt:PlayShine(1, 1, 1, 0.3)
	ns.Prompt:StopOutro()
	local b, s = plays(burst), plays(shine)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(burst) == b or plays(shine) == s then
		fail(scenario, "with Stay quiet in combat off, a buff landing in a fight got no flourish")
	end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if #Mock.protectedCalls > 0 then
		fail(scenario, "the effects called " .. table.concat(Mock.protectedCalls, ", ")
			.. " on the secure button in a fight")
	end
	for k, v in pairs(attributes) do
		if button.attributes[k] ~= v then
			fail(scenario, "an effect changed the button's " .. tostring(k) .. " in a fight")
		end
	end
	-- And quiet means quiet.
	ns.db.profile.prompt.hideInCombat = true
	b, s = plays(burst), plays(shine)
	local k = plays(r.shake)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(burst) ~= b or plays(shine) ~= s or plays(r.shake) ~= k then
		fail(scenario, "Stay quiet in combat is on and a click in a fight still set the panel moving")
	end
	-- The sweep as well. Every cast of a fight starts a global cooldown, most
	-- of them from the action bars, and a sweep on each is the busiest thing a
	-- panel asked to sit still could do.
	local cd = r.cooldown
	if cd then
		Mock.advance(1)
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now, duration = 1.5 } }
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-9", 1459)
		if cd:IsShown() then
			fail(scenario, "Stay quiet in combat is on and the icon still sweeps with every cast of the fight")
		end
		-- And back as the fight ends, for what is left of the cooldown.
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if not cd:IsShown() then
			fail(scenario, "the fight ended part-way through a global cooldown and the sweep did not come back")
		end
	end
	Mock.inCombat = false
	Mock.spellCooldowns = nil
end)

-- ------------------------------------------------------------------ look 7
-- Nothing new runs while nothing is happening.
--
-- Every effect added for the look plays once and stops. The pulse for a favour
-- owed is the one thing that loops, and only while somebody is owed; and the
-- button's own tooltip check is the only OnUpdate on the prompt.
withTree("nothing new runs while the prompt is idle",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "nothing new runs while the prompt is idle"
	freshPrompt(ns, scenario)
	local button = ns.Prompt:GetButton()
	local function onPrompt(f)
		f = f._parent
		while f do
			if f == button then return true end
			f = f._parent
		end
		return false
	end
	for _, f in ipairs(FT.all) do
		if onPrompt(f) and f.scripts and f.scripts.OnUpdate then
			fail(scenario, "a " .. tostring(f._kind) .. " on the prompt has an OnUpdate script,"
				.. " which runs on every frame it is shown")
		end
	end
	-- A passer-by, left alone for a while: nothing loops.
	ns.addon:Tick()
	Mock.advance(3)
	FT.settle()
	ns.addon:Tick()
	FT.settle()
	local _, looping = FT.playing()
	if #looping > 0 then
		fail(scenario, #looping .. " looping animation(s) running over a passer-by")
	end
	-- Owed, pressed, landed: everything once, then still.
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	wipe(ns.owed)
	ns.BlockPerson("Anna Aim")
	Mock.advance(3)
	ns.addon:Tick()
	FT.settle()
	Mock.advance(3)
	ns.addon:Tick()
	FT.settle()
	local all = FT.playing()
	if button:IsShown() then
		fail(scenario, "SKIPPED -- the panel did not come down with nobody left")
	elseif #all > 0 then
		local names = {}
		for _, g in ipairs(all) do names[#names + 1] = tostring(g._owner and g._owner._kind) end
		fail(scenario, #all .. " animation(s) still running on a prompt with nobody on it: "
			.. table.concat(names, ", "))
	end
end)

-- ------------------------------------------------------------------ look 8
-- The cooldown sweep follows the global cooldown, and the settings that hide it.
withTree("the icon sweeps with the global cooldown",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "the icon sweeps with the global cooldown"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local cd = ns.Prompt:Regions().cooldown
	if not (cd and cd.SetCooldown) then
		fail(scenario, "SKIPPED -- no cooldown frame on the icon")
		return
	end
	local start = Mock.now
	Mock.spellCooldowns = { [61304] = { startTime = start, duration = 1.3 } }
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-1", 1459)
	local c = cd._cooldown
	if not (c and cd:IsShown()) then
		fail(scenario, "a cast went out and the icon shows no cooldown")
	elseif c.start ~= start or c.duration ~= 1.3 then
		fail(scenario, ("the sweep runs from %s for %s, and the client's cooldown from %s for 1.3"):format(
			tostring(c.start), tostring(c.duration), tostring(start)))
	end
	-- Where the client withholds its figure, the tracked second and a half.
	Mock.spellCooldowns = nil
	Mock.advance(5)
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-2", 1459)
	c = cd._cooldown
	if not (c and cd:IsShown() and c.start == Mock.now and c.duration > 0) then
		fail(scenario, "with the client's figure withheld, a cast showed no cooldown at all")
	end
	-- Off, and with no icon to sweep.
	for _, case in ipairs({ { "showCooldown", false }, { "showIcon", false } }) do
		ns.db.profile.prompt[case[1]] = case[2]
		ns.Prompt:ApplyStyle()
		Mock.advance(5)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-3", 1459)
		if cd:IsShown() then
			fail(scenario, "with " .. case[1] .. " off the icon still sweeps")
		end
		ns.db.profile.prompt[case[1]] = true
	end
	ns.Prompt:ApplyStyle()
	-- And a cooldown that has run out leaves nothing behind.
	Mock.advance(10)
	ns.Prompt:SyncCooldown()
	if cd:IsShown() then
		fail(scenario, "the sweep is still up long after the cooldown ended")
	end
end)

-- ------------------------------------------------------------------ look 9
-- A refusal's red ring is put back.
--
-- The red is written over the ring by the outcome, and only a repaint of a
-- person puts the reason colour back. In a fight the panel is repainted from
-- the frozen entry without one, so the ring stayed red for the rest of it.
withTree("a refusal's red ring is put back, in a fight as well",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "a refusal's red ring is put back, in a fight as well"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local ring = ns.Prompt:Regions().iconBack
	local function red()
		local g = ring._gradient
		local top = g and g[3]
		return type(top) == "table" and top.r == 1.0 and top.g < 0.5
	end
	for _, fight in ipairs({ false, true }) do
		Mock.inCombat = fight
		Mock.advance(1)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		if not red() then
			fail(scenario, "SKIPPED -- the refusal did not turn the ring red"
				.. (fight and " in a fight" or ""))
		else
			Mock.advance(1)
			ns.addon:Tick()
			if red() then
				fail(scenario, "the ring stayed red after the refusal was over"
					.. (fight and ", in a fight" or ""))
			end
		end
	end
	Mock.inCombat = false
end)

-- ------------------------------------------------------------------ look 10
-- The entrance ends where the panel belongs.
--
-- A translation is undone when its group ends, so a rise with nothing before
-- it went up past the panel's place and dropped back with a hop at the end.
withTree("the entrance ends where the panel belongs", {}, function(ns)
	local scenario = "the entrance ends where the panel belongs"
	drive(scenario, ns)
	local intro = ns.Prompt:Regions().intro
	if not (intro and intro._anims) then
		fail(scenario, "SKIPPED -- the entrance is not reachable")
		return
	end
	local dy, moves = 0, 0
	for _, a in ipairs(intro._anims) do
		if a._kind == "Translation" and a._offset then
			dy = dy + a._offset[2]
			moves = moves + 1
		end
	end
	if moves == 0 then
		fail(scenario, "SKIPPED -- the entrance does not move")
	elseif math.abs(dy) > 0.01 then
		fail(scenario, ("the entrance's moves add up to %d pixels, so the panel hops that far"
			.. " when it ends"):format(dy))
	end
end)

-- ------------------------------------------------------------------ look 11
-- The new settings are repaired, and the page offers them.
withTree("the look's settings are clamped and offered", {}, function(ns)
	local scenario = "the look's settings are clamped and offered"
	drive(scenario, ns)
	local p = ns.db.profile.prompt
	if p.effects ~= "full" or p.showCooldown ~= true then
		fail(scenario, "the defaults are not Full effects with the cooldown shown")
	end
	p.effects = "strobe"
	p.showCooldown = "yes please"
	ns.ClampSettings()
	if p.effects ~= "full" then fail(scenario, "an unknown Effects value was kept: " .. tostring(p.effects)) end
	if p.showCooldown ~= true then
		fail(scenario, "a cooldown switch that is not a yes or a no was kept: " .. tostring(p.showCooldown))
	end
	local effects = H.findOption(ns.optionsTable, "effects")
	local cooldown = H.findOption(ns.optionsTable, "showCooldown")
	if not (effects and effects.type == "select" and type(effects.values) == "table"
		and effects.values.full and effects.values.calm) then
		fail(scenario, "the Prompt tab has no Effects choice offering Full and Calm")
	end
	if not (cooldown and cooldown.type == "toggle") then
		fail(scenario, "the Prompt tab has no switch for the cooldown sweep")
	elseif type(cooldown.disabled) == "function" then
		p.showIcon = false
		if not cooldown.disabled() then
			fail(scenario, "the cooldown switch is offered with no icon for it to sweep")
		end
		p.showIcon = true
	end
end)

-- The band of light's strength as it was last painted: 0.30 for a buff that
-- landed, 0.20 for a favour just done. Read off the band's left half, whose
-- inner stop carries it.
local function shineStrength(r)
	local half = r.shine and r.shine._children and r.shine._children[1]
	local g = half and half._gradient
	return type(g) == "table" and type(g[3]) == "table" and g[3].a or nil
end

-- ------------------------------------------------------------------ look 12
-- A rounded icon wears a round glow, and the glow ships.
--
-- The mask rounds the icon, and the square halo went on being drawn round it:
-- a round icon in a square gold picture frame, which is the square pieces
-- poking out that hiding the ring's edge and shade was meant to prevent. And
-- the glows are art files in the package now, so the files have to be there.
withTree("a rounded icon wears a round glow, and the glow ships",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "a rounded icon wears a round glow, and the glow ships"
	for _, file in ipairs({ "Glow", "GlowRound" }) do
		local f = io.open(dir .. "/Textures/" .. file .. ".tga", "rb")
		if f then
			f:close()
		else
			fail(scenario, "Textures/" .. file .. ".tga is not in the package, and the glow round"
				.. " the icon is drawn from it")
		end
	end
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.roundIcon = true
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	if not (r.glowStrips and r.glowRound and r.icon and r.icon._mask) then
		fail(scenario, "SKIPPED -- the icon was not rounded, or the glow is not reachable")
		return
	end
	for i, strip in ipairs(r.glowStrips) do
		if strip._shown ~= false then
			fail(scenario, ("square glow piece %d is shown round a rounded icon"):format(i))
		end
	end
	for i, strip in ipairs(r.burstStrips or {}) do
		if strip._shown ~= false then
			fail(scenario, ("square burst piece %d is shown round a rounded icon"):format(i))
		end
	end
	if r.glowRound._shown == false then
		fail(scenario, "a rounded icon has no glow round it at all")
	else
		local rect = layout(FT.snapshot(UIParent))
		local ring, iconBox = rect(r.glowRound._serial), rect(r.icon._serial)
		if ring and iconBox then
			local want = p.iconSize / 0.70
			if math.abs((ring[3] - ring[1]) - want) > 0.5 then
				fail(scenario, ("the round glow is %.1f across; its rim lands on the icon's edge at %.1f"):format(
					ring[3] - ring[1], want))
			end
			local dx = (ring[1] + ring[3]) / 2 - (iconBox[1] + iconBox[3]) / 2
			local dy = (ring[2] + ring[4]) / 2 - (iconBox[2] + iconBox[4]) / 2
			if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
				fail(scenario, "the round glow is not centred on the icon")
			end
		end
	end
	-- And square again when the icon is.
	p.roundIcon = false
	ns.Prompt:ApplyStyle()
	if r.glowRound._shown ~= false or r.glowStrips[1]._shown == false then
		fail(scenario, "the icon was squared off again and kept the round glow")
	end
end)

-- ------------------------------------------------------------------ look 13
-- Every outcome gets its own fade.
--
-- The fade started once and was never started again, so an outcome that came
-- after it -- a refusal a moment after the buff before it, the realistic case
-- -- was painted onto a panel already faded to nothing, or cut short by a fade
-- that was half over when it arrived.
withTree("every outcome over an empty queue gets its own fade",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "every outcome over an empty queue gets its own fade"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	local outro = r.outro
	if not (outro and ns.Prompt:GetButton():IsShown()) then
		fail(scenario, "SKIPPED -- no panel or no fade to watch")
		return
	end
	ns.BlockPerson("Anna Aim")
	wipe(ns.owed)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(0.61)
	FT.settle()
	if (r.art:GetAlpha() or 1) > 0.01 then
		fail(scenario, "SKIPPED -- the first fade did not run to nothing")
		return
	end
	local before = plays(outro)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if not ns.Prompt:OutcomeLive() then
		fail(scenario, "SKIPPED -- the refusal is not live")
	elseif (r.art:GetAlpha() or 0) < 0.99 then
		fail(scenario, ("a refusal after the fade was painted onto a panel at alpha %.2f"):format(
			r.art:GetAlpha() or 0))
	elseif plays(outro) == before then
		fail(scenario, "a refusal after the fade got no fade of its own")
	end
	-- Half-way through that one, another: started again, not left to finish.
	Mock.advance(0.45)
	before = plays(outro)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(outro) == before then
		fail(scenario, "an outcome that arrived half-way through the fade was cut short by it")
	end
end)

-- ------------------------------------------------------------------ look 14
-- A buff that lands shines once, in its own light, even when somebody buffs you
-- at the same moment.
--
-- The repaint after a success is usually about the next person owed, and it
-- restarted the band in the dimmer colour of a favour arriving -- so the answer
-- to the press was cut off by a nudge.
withTree("a success shines once in its own light",
	{ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }, function(ns)
	local scenario = "a success shines once in its own light"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	local shine = r.shine and r.shine.anim
	local top = ns.BuildQueue()[1]
	if not (shine and top and top.name == "Anna Aim") then
		fail(scenario, "SKIPPED -- Anna is not on the panel, or the shine is not reachable")
		return
	end
	Mock.advance(1)
	FT.settle()
	-- Bert buffs you in the same moment the press on Anna lands.
	ns.BlockPerson("Anna Aim")
	ns.owed["Anna Aim"] = nil
	owe(ns, "Bert Beside")
	local before = plays(shine)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(shine) ~= before + 1 then
		fail(scenario, ("the band of light played %d times for one buff landing"):format(plays(shine) - before))
	elseif math.abs((shineStrength(r) or 0) - 0.30) > 0.001 then
		fail(scenario, ("the success's light was replaced by one at %.2f"):format(shineStrength(r) or 0))
	end
	-- And Bert's favour is not lit later either: it was seen, and the moment
	-- went to the success.
	for _ = 1, 4 do
		Mock.advance(0.4)
		FT.settle()
		ns.addon:Tick()
	end
	if plays(shine) ~= before + 1 then
		fail(scenario, "the light on arrival played after the success for a favour already seen")
	end
end)

-- ------------------------------------------------------------------ look 15
-- Somebody who has been waiting all along reaching the top is not an arrival.
--
-- The light was keyed on an owed name reaching the panel, which is also the
-- next person after every press and somebody coming back after you looked away.
withTree("somebody waiting all along reaching the top does not catch the light",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "somebody waiting all along reaching the top does not catch the light"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	local shine = r.shine and r.shine.anim
	if not shine or plays(shine) == 0 then
		fail(scenario, "SKIPPED -- Anna's favour did not light the panel to begin with")
		return
	end
	-- Bert buffs you from out of sight, and the panel sees it with Anna on it.
	Mock.advance(0.5)
	owe(ns, "Bert Beside")
	ns.addon:Tick()
	if ns.Prompt:PanelName() ~= "Anna Aim" then
		fail(scenario, "SKIPPED -- Anna did not stay on the panel: " .. tostring(ns.Prompt:PanelName()))
		return
	end
	Mock.advance(0.4)
	FT.settle()
	-- Bert walks up, and Anna is dealt with -- retired, the way a press on
	-- her retires her -- a second after he buffed you: he is next.
	Mock.unitNames.nameplate2 = { "Bert", "Beside" }
	ns.nameplateUnits.nameplate2 = true
	ns.BlockPerson("Anna Aim")
	ns.owed["Anna Aim"] = nil
	local before = plays(shine)
	ns.addon:Tick()
	if ns.Prompt:PanelName() ~= "Bert Beside" then
		fail(scenario, "SKIPPED -- Bert did not reach the panel: " .. tostring(ns.Prompt:PanelName()))
	elseif plays(shine) ~= before then
		fail(scenario, "Bert had been waiting since before he reached the panel and it caught the light"
			.. " for him as if he had just buffed you")
	end
end)

-- ------------------------------------------------------------------ look 16
-- The Minimal look has no panel for light to cross.
--
-- The band is additive light, and with nothing under it, it was a white column
-- sweeping across the game world behind the text. The ring round the icon is
-- still the icon's.
withTree("no light crosses the Minimal look",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "no light crosses the Minimal look"
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "minimal"
	ns.Prompt:ApplyStyle()
	local r = ns.Prompt:Regions()
	local shine, burst = r.shine and r.shine.anim, r.burst and r.burst.anim
	if not (shine and burst) then
		fail(scenario, "SKIPPED -- the shine or the burst is not reachable")
		return
	end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(1)
	local b = plays(burst)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(shine) > 0 then
		fail(scenario, "a band of light crossed a Minimal prompt, which has no panel under it")
	end
	if plays(burst) == b then
		fail(scenario, "a buff landing on a Minimal prompt lost the ring round its icon too")
	end
end)

-- ------------------------------------------------------------------ look 17
-- A fight that starts while the panel fades out brings it back gently.
--
-- The button cannot be hidden in a fight, so a panel on its way out when one
-- starts stays up, dimmed and held. It used to snap from wherever the fade had
-- got to straight to the dim, which read as a glitch; now it is taken there.
withTree("a fight during the fade out brings the panel back gently",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "a fight during the fade out brings the panel back gently"
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	local outro, comeback = r.outro, r.comeback
	if not (outro and comeback and comeback._anims and comeback._anims[1]) then
		fail(scenario, "SKIPPED -- the fade out or the way back is not reachable")
		return
	end
	ns.BlockPerson("Anna Aim")
	wipe(ns.owed)
	Mock.advance(1)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if not playing(outro) then
		fail(scenario, "SKIPPED -- the panel did not start fading out")
		return
	end
	-- Three quarters of the way through the wait and the fall: part-faded.
	Mock.advance(0.45)
	local before = plays(comeback)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	local fade = comeback._anims[1]
	if playing(outro) then
		fail(scenario, "the fade out went on in a fight, where the panel cannot go")
	elseif plays(comeback) == before then
		fail(scenario, "a fight caught the panel part-faded and it snapped back instead of returning")
	elseif not (fade._fromAlpha and fade._fromAlpha > 0.6 and fade._fromAlpha < 0.9
		and math.abs((fade._toAlpha or 0) - 0.55) < 0.001) then
		fail(scenario, ("the way back runs from %s to %s, not from where the fade had got to the"
			.. " fight's dim"):format(tostring(fade._fromAlpha), tostring(fade._toAlpha)))
	elseif math.abs((r.art:GetAlpha() or 0) - 0.55) > 0.001 then
		fail(scenario, ("the panel rests at %.2f in the fight, not dimmed"):format(r.art:GetAlpha() or 0))
	end
	Mock.inCombat = false
end)

-- ------------------------------------------------------------------ look 18
-- A repaint in the same colour costs nothing.
--
-- The accent is painted on every scan, and the colour almost never changes
-- between two. With the halo, the ring and the stripe it was a dozen texture
-- writes a scan, each gradient making two colour objects, two and a half times
-- a second for as long as anybody is on the panel.
withTree("a repaint in the same colour paints nothing",
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "a repaint in the same colour paints nothing"
	freshPrompt(ns, scenario)
	ns.addon:Tick()
	if not ns.Prompt:GetButton():IsShown() then
		fail(scenario, "SKIPPED -- nobody on the panel")
		return
	end
	local real, made = CreateColor, 0
	CreateColor = function(...)
		made = made + 1
		return real(...)
	end
	local ok, err = pcall(function()
		for _ = 1, 10 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
	end)
	CreateColor = real
	if not ok then error(err, 0) end
	if made > 10 then
		fail(scenario, ("ten scans of the same passer-by made %d colour objects"):format(made))
	end
end)
