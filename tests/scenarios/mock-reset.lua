-- What Mock.reset lets go of (tests/mockwidgets.lua, install): UIParent and
-- GameTooltip outlive every reset, and the children the mock lists on a frame
-- for Mock.clickAt (_kids) were kept on them from one scenario to the next. A
-- whole-suite worker held every frame of every addon the run loaded, grew past
-- 20 GB and never finished, and tests/scenarios/hunt38-picker.lua's dump of
-- UIParent grew with each reset until the file no longer ended.
--
-- Every scenario name starts with "mock-reset:" so the mutations in
-- tests/mutations/mock-reset.py can name the one that has to catch them.

local dir, H = ...
local fail = H.fail

do
	local scenario = "mock-reset: a reset keeps none of the frames made before it"
	if H.admit(scenario) then
		Mock.reset()
		local fresh = #(UIParent._kids or {})
		-- A thousand resets, each with frames under both: what the screen holds
		-- after the last is what one reset makes, not a thousand of them.
		for _ = 1, 1000 do
			for _ = 1, 5 do CreateFrame("Frame", nil, UIParent) end
			CreateFrame("Frame", nil, GameTooltip)
			Mock.reset()
		end
		local after = #(UIParent._kids or {})
		if after > fresh then
			fail(scenario, ("UIParent lists %d children after a thousand resets, %d after one"):format(after, fresh))
		end
		if #(GameTooltip._kids or {}) > 0 then
			fail(scenario, ("GameTooltip lists %d children after a reset"):format(#GameTooltip._kids))
		end
		-- And a frame made before a reset can be collected after it.
		local held = setmetatable({}, { __mode = "k" })
		held[CreateFrame("Frame", nil, UIParent)] = true
		held[CreateFrame("Frame", nil, GameTooltip)] = true
		Mock.reset()
		collectgarbage("collect")
		collectgarbage("collect")
		local left = 0
		for _ in pairs(held) do left = left + 1 end
		if left > 0 then fail(scenario, left .. " frame(s) made before a reset are still held after it") end
	end
end
