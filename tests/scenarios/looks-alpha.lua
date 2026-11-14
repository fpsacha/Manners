-- A colour never changes a texture's transparency, on any of the nineteen looks.
--
-- The game keeps ONE alpha for a texture: SetVertexColor(r, g, b, a) writes
-- over what SetAlpha set, and an alpha left out is documented as 1. The mock
-- keeps the two apart, so a look that dims a light with SetAlpha and colours
-- it afterwards is right here and wrong in the game: 1.11.19's Glass covered
-- its pane with a grey marble that way (GitHub issue 15).
--
-- So every look is taken through one script three times -- on the mock as it
-- is, with every texture's SetVertexColor made to set the alpha it is given
-- (the game), and with an alpha left out read as 1 as well (the game as its
-- documentation has it) -- and at every checkpoint every texture must stand at
-- the same alpha in all three. The script: at rest; every reason in each
-- marker mode and both palettes; somebody owed; a fight starting and ending;
-- an outcome that succeeded and one that was refused; hover; the list shown;
-- Calm.
--
-- And a texture an Alpha animation plays on is coloured from the alpha the
-- look WROTE DOWN for it (ns.Looks.Rest), never from GetAlpha, which in the
-- game may answer a flash's passing value and leave the light lit for good.
--
-- MANNERS_ALPHA_TRACE=1 prints the call that moved each alpha.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local STYLES = { "glass", "framed", "minimal", "luxe", "toast", "arcane", "ribbon", "letter", "leather", "forge", "archmage",
	"lightbringer", "fel", "wild", "frost", "stormcaller", "warchief", "gearworks", "ebon" }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local REASONS = { "target", "owed", "asked", "self", "group", "nearby" }
local MODES = { "both", "icon", "stripe", "off" }
local PALETTES = { "standard", "colourblind" }
local TRACE = os.getenv("MANNERS_ALPHA_TRACE") == "1"

local function fight(ns, on)
	Mock.inCombat = on
	if on then
		ns.addon:PLAYER_REGEN_DISABLED()
	elseif ns.addon.PLAYER_REGEN_ENABLED then
		ns.addon:PLAYER_REGEN_ENABLED()
	end
end

local function short(t)
	local file = t._file and tostring(t._file):match("[^\\/]+$")
	return file or (t._colorTexture and "a flat colour") or (t._atlas and tostring(t._atlas)) or "a texture"
end

-- Whether an Alpha animation plays on this texture: one of its own groups', or
-- one of a group anywhere that names it as its target.
local function alphaAnimated()
	local on = {}
	for _, r in ipairs(FT.all) do
		for _, g in ipairs(r._groups or {}) do
			for _, a in ipairs(g._anims or {}) do
				if a._kind == "Alpha" then
					local target = a._target
					if not target and a._childKey and type(r[a._childKey]) == "table" then target = r[a._childKey] end
					on[target or r] = true
				end
			end
		end
	end
	return on
end

-- One look through the script. `game`: nil for the mock as it is, "given" for
-- a SetVertexColor that sets the alpha it is given, "strict" for one that also
-- reads an alpha left out as 1. Returns the checkpoints (label, alphas by
-- texture order), the textures' names, the calls that moved an alpha, and the
-- faults of the written-down alpha.
local function run(scenario, style, game)
	Mock.reset()
	local realNew = Mock.newFrame
	local moved, restFaults = {}, {}
	local animated, sharedIcon = nil, nil
	if game then
		Mock.newFrame = function(...)
			local f = realNew(...)
			local set = f.SetVertexColor
			f.SetVertexColor = function(self, r, g, b, a, ...)
				if self._kind == "Texture" then
					local was = self._alpha or 1
					local to = a
					if to == nil and game == "strict" then to = 1 end
					if to ~= nil then
						if math.abs(to - was) > 0.001 then
							local where = debug.traceback("", 2):match("\n%s*([^\n]-%.lua:%d+)") or "?"
							local at = debug.traceback("", 2)
							-- The first line of the addon's own in the trace.
							for line in at:gmatch("[^\n]+") do
								local file, n = line:match("([%w_/\\%.]-[%w_]+%.lua):(%d+)")
								if file and not file:find("tests", 1, true) and not file:find("frametree", 1, true) then
									where = file:match("[^/\\]+%.lua$") .. ":" .. n
									break
								end
							end
							local key = where .. " " .. short(self)
							if not moved[key] then
								moved[key] = ("%s: %s from %.3f to %.3f%s"):format(where, short(self), was, to,
									a == nil and " (no alpha given)" or "")
								moved[#moved + 1] = moved[key]
							end
						end
						self._alpha = to
					end
				end
				-- Coloured where an Alpha animation plays on it: through the
				-- helper, which knows what the texture rests at. The shared icon
				-- is every look's and takes no hold (Looks.lua, ONE ALPHA): it
				-- stands at full alpha wherever it is coloured, which the check
				-- above holds it to, so a look's fade on it (the Letter's spell
				-- struck into the wax) is an animation's alpha and no more.
				if self._kind == "Texture" and animated and animated[self] and self.restAlpha == nil and self ~= sharedIcon then
					local key = "rest " .. short(self)
					if not restFaults[key] then
						restFaults[key] = true
						restFaults[#restFaults + 1] = short(self) .. " has an Alpha animation and is coloured with no resting alpha written down"
					end
				end
				return set(self, r, g, b, a, ...)
			end
			return f
		end
	end
	FT.install()
	local restore = strangers(CROWD)
	local ns = load(scenario)
	local points, names = {}, {}
	local ok, err = true, nil
	local function point(label)
		local alphas = {}
		local n = 0
		for _, r in ipairs(FT.all) do
			if r._kind == "Texture" then
				n = n + 1
				-- What is drawn: on the mock a colour's alpha and SetAlpha's
				-- multiply, in the game there is the one. A gradient carries
				-- its own alphas and is left out.
				if r._gradient then
					alphas[n] = false
				elseif game then
					alphas[n] = r._alpha or 1
				else
					alphas[n] = (r._alpha or 1) * ((r._color and r._color[4]) or 1)
				end
				names[n] = names[n] or short(r)
				-- What the look wrote down is what the texture stands at.
				if r.restAlpha ~= nil and math.abs(r.restAlpha - (r._alpha or 1)) > 0.001 and not game then
					local key = "drift " .. n
					if not restFaults[key] then
						restFaults[key] = true
						restFaults[#restFaults + 1] = ("%s: %s stands at %.3f and its written-down alpha is %.3f"):format(label, short(r),
							r._alpha or 1, r.restAlpha)
					end
				end
			end
		end
		points[#points + 1] = { label = label, alphas = alphas }
	end
	if ns then
		ok, err = pcall(function()
			local P = ns.Prompt
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = style, "full", "pulse", true, false
			p.showQueue = false
			P:ApplyStyle()
			ns.addon:Tick()
			animated = alphaAnimated()
			sharedIcon = P:LookKit().icon
			point("at rest")
			FT.settle()
			point("at rest, settled")
			for _, palette in ipairs(PALETTES) do
				p.reasonPalette = palette
				for _, mode in ipairs(MODES) do
					p.accentMode = mode
					P:ApplyStyle()
					ns.addon:Tick()
					for _, reason in ipairs(REASONS) do
						P:PaintAccent(reason)
						point(("the reason %s, marker %s, palette %s"):format(reason, mode, palette))
					end
				end
			end
			p.reasonPalette, p.accentMode = "standard", "both"
			P:ApplyStyle()
			ns.addon:Tick()
			point("back to both")
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			animated = alphaAnimated()
			point("somebody owed")
			for _, reason in ipairs(REASONS) do
				P:PaintAccent(reason)
			end
			point("a reason's colour while the lights play")
			ns.addon:Tick()
			Mock.advance(3)
			FT.settle()
			ns.addon:Tick()
			point("owed, settled")
			fight(ns, true)
			ns.addon:Tick()
			point("a fight starts")
			P:PaintAccent("target")
			P:PaintAccent("owed")
			Mock.advance(1)
			FT.settle()
			point("in a fight")
			fight(ns, false)
			ns.addon:Tick()
			point("the fight ends")
			Mock.advance(1)
			FT.settle()
			ns.addon:Tick()
			point("after the fight")
			P:ShowOutcome("cast", "Anna Aim", "x")
			point("an outcome that succeeded")
			P:PaintAccent("group")
			P:PaintAccent("owed")
			point("a reason's colour over the landing")
			Mock.advance(2)
			FT.settle()
			ns.addon:Tick()
			point("after the landing")
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			P:ShowOutcome("failed", "Anna Aim", "Out of range.")
			point("an outcome that was refused")
			P:PaintAccent("group")
			P:PaintAccent("owed")
			point("a reason's colour over the refusal")
			Mock.advance(2)
			FT.settle()
			ns.addon:Tick()
			point("after the refusal")
			local b = P:GetButton()
			b.scripts.OnEnter(b)
			point("hover")
			P:PaintAccent("asked")
			point("a reason's colour under the cursor")
			b.scripts.OnLeave(b)
			Mock.advance(1)
			FT.settle()
			point("the cursor gone")
			p.showQueue, p.queueRows = true, 3
			owe(ns, "Brannoc Vale")
			Mock.promptCentreY = 700
			P:ApplyStyle()
			ns.addon:Tick()
			point("the list below")
			Mock.promptCentreY = 40
			P:ApplyStyle()
			ns.addon:Tick()
			point("the list above")
			p.effects = "calm"
			P:ApplyStyle()
			ns.addon:Tick()
			point("Calm")
			for _, reason in ipairs(REASONS) do
				P:PaintAccent(reason)
			end
			point("a reason's colour on Calm")
			P:ShowOutcome("cast", "Anna Aim", "x")
			point("a landing on Calm")
			Mock.advance(2)
			FT.settle()
			ns.addon:Tick()
			P:ShowOutcome("failed", "Brannoc Vale", "Out of range.")
			point("a refusal on Calm")
			Mock.advance(2)
			FT.settle()
			ns.addon:Tick()
			point("Calm, settled")
		end)
	end
	restore()
	FT.uninstall()
	Mock.newFrame = realNew
	Mock.promptCentreY = nil
	Mock.reset()
	if not ns then return nil end
	if not ok then
		fail(scenario, ("threw (%s): %s"):format(tostring(game or "mock"), tostring(err)))
		return nil
	end
	return points, names, moved, restFaults
end

-- The two runs side by side: the first checkpoint each texture differs at.
local function compare(scenario, what, plain, other, names, moved)
	if #plain ~= #other then
		fail(scenario, ("%s: %d checkpoints against the mock's %d"):format(what, #other, #plain))
		return
	end
	local said, count = {}, 0
	for i, at in ipairs(plain) do
		local theirs = other[i].alphas
		if #theirs ~= #at.alphas then
			fail(scenario, ("%s: %d textures at '%s' against the mock's %d"):format(what, #theirs, at.label, #at.alphas))
			return
		end
		for n, a in ipairs(at.alphas) do
			if not said[n] and a and theirs[n] and math.abs(a - theirs[n]) > 0.001 then
				said[n] = true
				count = count + 1
				if count <= 6 then
					fail(scenario, ("%s: at '%s' %s (texture %d) stands at alpha %.3f, and at %.3f on the mock"):format(what, at.label,
						names[n] or "?", n, theirs[n], a))
				end
			end
		end
	end
	if count > 6 then fail(scenario, ("%s: and %d more textures"):format(what, count - 6)) end
	if count > 0 and TRACE then
		for _, line in ipairs(moved) do print(("    [%s] %s"):format(what, line)) end
	end
end

for _, style in ipairs(STYLES) do
	local scenario = "looks-alpha: " .. style .. ": a colour leaves every texture as faint as it was"
	local plain, names, _, drift = run(scenario, style, nil)
	if plain then
		-- The script reaches the look at all: it has textures, and something of
		-- it is dimmed (or the comparison holds nothing).
		local dimmed = 0
		for _, at in ipairs(plain) do
			for _, a in ipairs(at.alphas) do
				if a and a < 0.999 then dimmed = dimmed + 1 end
			end
		end
		if #plain < 60 then fail(scenario, "only " .. #plain .. " checkpoints were reached") end
		if dimmed == 0 then fail(scenario, "no texture is ever dimmed: the script holds nothing") end
		for _, line in ipairs(drift) do fail(scenario, line) end
		local again = run(scenario, style, nil)
		if again then compare(scenario, "a second run on the mock", plain, again, names, {}) end
		local given, _, moved, restFaults = run(scenario, style, "given")
		if given then
			compare(scenario, "with the game's one alpha", plain, given, names, moved)
			for i, line in ipairs(restFaults) do
				if i <= 6 then fail(scenario, line) end
			end
		end
		local strict, _, movedStrict = run(scenario, style, "strict")
		if strict then compare(scenario, "with an alpha left out read as 1", plain, strict, names, movedStrict) end
	end
end

---------------------------------------------------------------------------
-- A dim lies OVER a light's own alpha (Looks.Dim), and a light's flash goes to
-- its own strength (the animation's), since no colour carries an alpha: the
-- client keeps one number, and of an alpha given with a colour and one given
-- by SetAlpha the last call won. Luxe's shadow went to full after every fight,
-- Toast's clock burned brighter in a fight than out of one, Arcane's well
-- stood at full, and the lights whose colour carried their strength flashed
-- to twice it.
---------------------------------------------------------------------------

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.005)
end

local function withLook(scenario, style, body)
	Mock.reset()
	FT.install()
	local restore = strangers(CROWD)
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style, p.effects, p.flashStyle, p.showIcon, p.hideInCombat = style, "full", "pulse", true, false
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			FT.settle()
			local look = ns.Prompt:Regions().look
			if not look then
				fail(scenario, "SKIPPED -- " .. style .. " is not the look in use")
				return
			end
			body(ns, look, p)
		end)
	end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- `lights`: name -> texture. Each rests at its own alpha, stands at that times
-- `dim` in a fight (through a repaint of the reason too), and comes back.
local function dimsOver(scenario, ns, lights, own, dim, repaint)
	for name, t in pairs(lights) do
		if not near(t._alpha or 1, own[name]) then
			fail(scenario, ("at rest the %s stands at %s, its own alpha is %s"):format(name, tostring(t._alpha), tostring(own[name])))
		end
	end
	fight(ns, true)
	ns.addon:Tick()
	FT.settle()
	for pass = 1, 2 do
		for name, t in pairs(lights) do
			if not near(t._alpha or 1, own[name] * dim[name]) then
				fail(scenario, ("in a fight%s the %s stands at %s, not its own %s dimmed to %s"):format(pass == 2 and ", after a reason's colour," or "",
					name, tostring(t._alpha), tostring(own[name]), tostring(own[name] * dim[name])))
			end
		end
		if pass == 1 then repaint() end
	end
	fight(ns, false)
	ns.addon:Tick()
	FT.settle()
	repaint()
	for name, t in pairs(lights) do
		if not near(t._alpha or 1, own[name]) then
			fail(scenario, ("after the fight the %s stands at %s, not its own %s"):format(name, tostring(t._alpha), tostring(own[name])))
		end
	end
end

withLook("looks-alpha: luxe: a fight's dim lies over the shadow's own alpha", "luxe", function(ns, look)
	local scenario = "looks-alpha: luxe: a fight's dim lies over the shadow's own alpha"
	local shadow = look.shadow[5]
	local own = shadow._alpha or 1
	if not (own > 0.3 and own < 0.9) then fail(scenario, "the shadow has no alpha of its own at rest: " .. tostring(own)) end
	dimsOver(scenario, ns, { shadow = shadow }, { shadow = own }, { shadow = 0.92 }, function()
		ns.Prompt:PaintAccent("group")
		ns.Prompt:PaintAccent("owed")
	end)
end)

withLook("looks-alpha: toast: a fight's dim lies over the clock's own alpha", "toast", function(ns, look)
	local scenario = "looks-alpha: toast: a fight's dim lies over the clock's own alpha"
	dimsOver(scenario, ns, { ember = look.ember, bead = look.bead }, { ember = 0.55, bead = 0.85 }, { ember = 0.7, bead = 0.7 }, function()
		ns.Prompt:PaintAccent("group")
		ns.Prompt:PaintAccent("owed")
	end)
end)

withLook("looks-alpha: arcane: a fight's dim lies over each light's own alpha", "arcane", function(ns, look)
	local scenario = "looks-alpha: arcane: a fight's dim lies over each light's own alpha"
	local runes = look.runes._alpha or 1
	if not (runes > 0.05 and runes < 1) then fail(scenario, "the runes have no alpha of their own at rest: " .. tostring(runes)) end
	dimsOver(scenario, ns, { well = look.well, drain = look.drain, track = look.track, spark = look.spark, runes = look.runes },
		{ well = 0.40, drain = 0.85, track = 0.10, spark = 0.9, runes = runes },
		{ well = 0.62, drain = 0.60, track = 0.60, spark = 0.60, runes = 0.35 }, function()
			ns.Prompt:PaintAccent("group")
			ns.Prompt:PaintAccent("owed")
		end)
	-- The outcome's wash stands at the outcome's own strength, and fades from it.
	ns.Prompt:ShowOutcome("cast", "Anna Aim", "x")
	local wash = look.wash._alpha or 1
	if not (wash > 0.05 and wash < 0.95) then fail(scenario, "the outcome's wash stands at " .. tostring(wash) .. ", not at the outcome's own strength") end
	if not near(look.washAnim.fade._fromAlpha, wash) then
		fail(scenario, ("the wash fades from %s, and stands at %s"):format(tostring(look.washAnim.fade._fromAlpha), tostring(wash)))
	end
end)

-- The highest alpha a group's Alpha animations reach.
local function peak(g)
	local top = 0
	for _, a in ipairs(g._anims or {}) do
		if a._kind == "Alpha" then top = math.max(top, a._fromAlpha or 0, a._toAlpha or 0) end
	end
	return top
end

withLook("looks-alpha: toast: its lights go to their own strength, which no colour carries", "toast", function(ns, look)
	local scenario = "looks-alpha: toast: its lights go to their own strength, which no colour carries"
	for name, want in pairs({ warm = { look.pulse[2], 0.34 }, arrival = { look.arrive[1], 0.55 }, glint = { look.sweep[1], 0.8 } }) do
		if not near(peak(want[1]), want[2]) then
			fail(scenario, ("the %s goes to %s, its own strength is %s"):format(name, tostring(peak(want[1])), tostring(want[2])))
		end
	end
	for name, t in pairs({ warm = look.ringWarm, arrival = look.ringArrive, glint = look.glints[1], cursor = look.ringHover }) do
		local c = t._color
		if c and c[4] ~= nil and not near(c[4], 1) then fail(scenario, "the " .. name .. "'s colour carries an alpha: " .. tostring(c[4])) end
	end
	local b = ns.Prompt:GetButton()
	b.scripts.OnEnter(b)
	Mock.advance(0.3)
	FT.settle()
	if not near(look.ringHover._alpha or 1, 0.42) then
		fail(scenario, "under the cursor the gold's light stands at " .. tostring(look.ringHover._alpha) .. ", not its own 0.42")
	end
	ns.Prompt:PaintAccent("group")
	if not near(look.ringHover._alpha or 1, 0.42) then
		fail(scenario, "a reason's colour moved the cursor's light to " .. tostring(look.ringHover._alpha))
	end
	b.scripts.OnLeave(b)
	Mock.advance(0.3)
	FT.settle()
	if not near(look.ringHover._alpha or 1, 0) then fail(scenario, "the cursor gone, its light stays at " .. tostring(look.ringHover._alpha)) end
end)

withLook("looks-alpha: ribbon: the shine along the cloth goes to its own strength", "ribbon", function(_, look)
	local scenario = "looks-alpha: ribbon: the shine along the cloth goes to its own strength"
	if not near(peak(look.travel), 0.5) then fail(scenario, "the shine goes to " .. tostring(peak(look.travel)) .. ", its own strength is 0.5") end
	local c = look.sweep._color
	if c and c[4] ~= nil and not near(c[4], 1) then fail(scenario, "the shine's colour carries an alpha: " .. tostring(c[4])) end
	if not near(look.sweep._alpha or 1, 0) then fail(scenario, "at rest the shine stands at " .. tostring(look.sweep._alpha)) end
end)
