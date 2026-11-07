-- A sound that will not stop, and a preview that will not go (1.11.9). A player
-- tried three sounds from the list (every sound any addon gave LibSharedMedia,
-- music among them) and heard three jazz tracks at once, through a /reload and
-- with the addon switched off, and the preview stayed on the screen with no way
-- to put it away. Now a new sound stops the one before it, each is cut off after
-- a few seconds, switching the sound off stops it, the last one's handle is kept
-- so the next session stops it, and a click on the preview puts it away.
--
-- Every scenario name starts with "soundstop:" so the mutations in
-- tests/mutations/soundstop.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local function with(scenario, body)
	Mock.reset()
	local restore = H.strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.sounds, Mock.stoppedSounds = {}, {}
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function stopped(handle)
	for _, h in ipairs(Mock.stoppedSounds or {}) do
		if h == handle then return true end
	end
	return false
end

do
	local scenario = "soundstop: a new sound stops the one before it"
	with(scenario, function(ns)
		ns.PlayPromptSound(ns.SOUND_KEY)
		local first = Mock.soundHandles
		ns.PlayPromptSound(ns.SOUND_KEY)
		if not stopped(first) then fail(scenario, "the first sound was still playing when the second began") end
		if #Mock.sounds ~= 2 then fail(scenario, ("%d sounds played, not two"):format(#Mock.sounds)) end
	end)
end

do
	local scenario = "soundstop: a sound is cut off after a few seconds"
	with(scenario, function(ns)
		ns.PlayPromptSound(ns.SOUND_KEY)
		local handle = Mock.soundHandles
		Mock.runTimers(1)
		if stopped(handle) then fail(scenario, "the sound was stopped after one second") end
		Mock.runTimers(5)
		if not stopped(handle) then fail(scenario, "the sound was still playing after six seconds") end
	end)
end

do
	local scenario = "soundstop: switching the sound off stops it"
	with(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "soundEnabled")
		if not control then
			fail(scenario, "SKIPPED -- no Play a sound switch")
			return
		end
		control.set(nil, true)
		ns.PlayPromptSound(ns.SOUND_KEY)
		local handle = Mock.soundHandles
		control.set(nil, false)
		if not stopped(handle) then fail(scenario, "Play a sound switched off left the sound playing") end
	end)
end

do
	local scenario = "soundstop: a sound left playing by the session before is stopped"
	with(scenario, function(ns)
		ns.PlayPromptSound(ns.SOUND_KEY)
		local handle = Mock.soundHandles
		if ns.db.char.soundHandle ~= handle then fail(scenario, "the handle was not kept: " .. tostring(ns.db.char.soundHandle)) end
		-- The next session: nothing in memory, the handle in the saved variables.
		ns.addon:OnEnable()
		if not stopped(handle) then fail(scenario, "the next session did not stop the sound left playing") end
		if ns.db.char.soundHandle ~= nil then fail(scenario, "the handle stayed saved after it was stopped") end
	end)
end

do
	local scenario = "soundstop: a click on the preview puts it away"
	with(scenario, function(ns)
		ns.Prompt:ToggleTest()
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the preview did not start")
			return
		end
		H.pressButton(ns, "RightButton")
		if ns.Prompt:InTest() then fail(scenario, "a right click left the preview up") end
		ns.Prompt:ToggleTest()
		H.pressButton(ns, "LeftButton")
		if ns.Prompt:InTest() then fail(scenario, "a left click left the preview up") end
	end)
end
