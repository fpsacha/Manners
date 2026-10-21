-- What a guarded failure leaves behind besides Manners' own error log: the
-- game's error handler hears of it, once per kind of failure, so an error addon
-- (or the game's Lua error window) sees it as it sees any addon's.
--
-- Every scenario name starts with "hunt28-guard:" so tests/mutations/hunt28-guard.py
-- can name the one that has to catch each fault.

local dir, H = ...
local fail, load = H.fail, H.load

do
	local scenario = "hunt28-guard: a failure reaches the game's error handler once per kind"
	Mock.reset()
	local heard = {}
	local saved = rawget(_G, "geterrorhandler")
	rawset(_G, "geterrorhandler", function()
		return function(message) heard[#heard + 1] = tostring(message) end
	end)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		heard = {}
		ns.Guard("hunt28 first", error, "boom one", 0)
		ns.Guard("hunt28 first", error, "boom one", 0)
		ns.Guard("hunt28 second", error, "boom two", 0)
		if #heard ~= 2 then
			fail(scenario, ("the game's error handler heard %d failures, not 2 (one per kind): %s")
				:format(#heard, table.concat(heard, " | ")))
		elseif not (heard[1]:find("boom one", 1, true) and heard[1]:find("hunt28 first", 1, true)) then
			fail(scenario, "the game's error handler was not told what broke and where: " .. heard[1])
		end
		-- A handler that throws is somebody else's failure, and never Manners'.
		rawset(_G, "geterrorhandler", function() return function() error("the handler broke") end end)
		local guarded = ns.Guard("hunt28 third", error, "boom three", 0)
		if guarded ~= false then fail(scenario, "a failure with a broken handler was not reported as a failure") end
		-- No handler at all, as in an old client: nothing to tell.
		rawset(_G, "geterrorhandler", nil)
		ns.Guard("hunt28 fourth", error, "boom four", 0)
		-- Manners' own record of each stays as it was.
		local kept = 0
		for _, e in ipairs(ns.errors) do
			if tostring(e.where):find("hunt28", 1, true) then kept = kept + 1 end
		end
		if kept ~= 5 then fail(scenario, ("Manners kept %d of the 5 failures, not all of them"):format(kept)) end
	end)
	rawset(_G, "geterrorhandler", saved)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
