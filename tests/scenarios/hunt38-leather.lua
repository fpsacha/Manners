-- Hunt 38, the Leather look (Looks/Leather.lua and the two hooks it has in
-- Prompt/Text.lua): faults found by reading it and by playing it through every
-- state on the recording tree (tests/frametree.lua). One scenario each, named
-- "hunt38-leather: ...".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

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

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in Leather with Anna owed on top.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "leather"
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

-- ------------------------------------------------------------------ 1
-- On Calm a favour arriving is one soft fade of the thread's glow. With the
-- flash set to "once" the look played it and stopped it in the same breath
-- (Attention's early StopAttention stops the fade too), so the player on Calm
-- who chose "once" never saw the favour arrive.
withTree("hunt38-leather: on Calm with the flash on once, a favour's soft glow plays out", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.effects, pp.flashStyle = "calm", "once" end)
	if not (look and look.soft) then fail(scenario, "SKIPPED -- Leather is not the look in use") return end
	wipe(ns.owed)
	tick(ns)
	Mock.advance(3)
	tick(ns)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	if not look.soft:IsPlaying() then
		fail(scenario, "the soft glow of a favour arriving on Calm (flash: once) is not playing right after it arrived")
	end
	Mock.advance(0.2)
	FT.settle()
	if not look.soft:IsPlaying() then fail(scenario, "the soft glow was cut off while it fades") end
	Mock.advance(2)
	FT.settle()
	if (look.glowFrame._alpha or 0) > 0.001 then fail(scenario, "the glow is left lit after the fade") end
end)
