-- Bug hunt 34, fixes B: the never-offer list's namesakes (Queue.lua ListedAs,
-- NeverOffer, PutOnNeverList), what a typed name still does, and the saved
-- marker. The proofs of hunt 33 sit in hunt33-*.lua; these are the cases
-- beside them. Names start with "hunt34-never:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local function run(scenario, flavour, names, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = "MAGE"
	local restore
	local ok, err = pcall(function()
		restore = strangers(names or {})
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.crossRealm = true
		Mock.advance(60)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

for _, flavour in ipairs({ "vanilla", "mainline" }) do
	-- The namesake from another realm can be listed after the same-realm Anna,
	-- and the two are two entries.
	local scenario = "hunt34-never: a same-realm Anna on the list does not make Anna-Aim 'already listed' ("
		.. flavour .. ")"
	run(scenario, flavour, { nameplate1 = { "Anna" }, nameplate2 = { "Anna", "Aim" } }, function(ns)
		ns.ClearNeverList()
		ns.PutOnNeverList("Anna")
		local listed, already = ns.NeverOffer("Anna-Aim")
		if already then
			fail(scenario, "listing Anna-Aim after Anna was refused as already listed as " .. tostring(listed))
		end
		if not (ns.IsNeverOffered("Anna") and ns.IsNeverOffered("Anna-Aim")) then
			fail(scenario, "the two Annas are not both on the list")
		end
		-- And taking one off leaves the other.
		ns.AllowAgain("Anna")
		if ns.IsNeverOffered("Anna") or not ns.IsNeverOffered("Anna-Aim") then
			fail(scenario, "taking Anna off the list touched Anna-Aim, or left Anna on it")
		end
	end)

	-- A name the player typed is still the name the prompt shows: "Anna" also
	-- answers to Anna-Aim, and lets go her favour; and when a favour is filed
	-- under exactly "Anna" too, that is the one meant.
	local typedScenario = "hunt34-never: a typed Anna still answers to Anna-Aim, an exact Anna first (" .. flavour .. ")"
	run(typedScenario, flavour, { nameplate2 = { "Anna", "Aim" } }, function(ns)
		ns.ClearNeverList()
		wipe(ns.owed)
		ns.owed["Anna-Aim"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		ns.PutOnNeverList("Anna", true)
		if not ns.IsNeverOffered("Anna-Aim") then
			fail(typedScenario, "a typed 'Anna' no longer lists Anna-Aim, as the prompt shows her")
		end
		if ns.owed["Anna-Aim"] then
			fail(typedScenario, "a typed 'Anna' kept the favour Anna-Aim did you")
		end

		ns.ClearNeverList()
		wipe(ns.owed)
		ns.owed["Anna"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		ns.owed["Anna-Aim"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		ns.PutOnNeverList("Anna", true)
		if ns.owed["Anna"] then
			fail(typedScenario, "a typed 'Anna' kept the favour of the Anna filed exactly so")
		end
		if not ns.owed["Anna-Aim"] then
			fail(typedScenario, "a typed 'Anna' let go the favour of Anna-Aim though an Anna of the same realm is owed one")
		end
	end)

	-- An exact entry (here in other letters) beats a realm-less one when both answer.
	local bothScenario = "hunt34-never: the exact entry is the one named when two answer (" .. flavour .. ")"
	run(bothScenario, flavour, { nameplate2 = { "Anna", "Aim" } }, function(ns)
		ns.ClearNeverList()
		local never = ns.db.profile.never
		never["Anna"] = true
		never["anna-aim"] = "filed"
		if ns.ListedAs("Anna-Aim") ~= "anna-aim" then
			fail(bothScenario, "Anna-Aim is listed as " .. tostring(ns.ListedAs("Anna-Aim")))
		end
	end)

	-- The two routes that hand over a name the player typed: /manners never and
	-- the options box. Both mean the person as the prompt shows her.
	local routeScenario = "hunt34-never: a name typed in chat or the options box answers to the other realm too ("
		.. flavour .. ")"
	run(routeScenario, flavour, { nameplate2 = { "Anna", "Aim" } }, function(ns)
		ns.ClearNeverList()
		ns.addon:HandleSlash("never Anna")
		if not ns.IsNeverOffered("Anna-Aim") then
			fail(routeScenario, "/manners never Anna did not list Anna-Aim, whom the prompt shows as Anna")
		end
		ns.ClearNeverList()
		local add = H.findOption(ns.optionsTable, "neverAdd")
		if not add then
			fail(routeScenario, "SKIPPED -- no add box")
		else
			add.set({ "neverAdd" }, "Anna")
			if not ns.IsNeverOffered("Anna-Aim") then
				fail(routeScenario, "the options box's Anna did not list Anna-Aim, whom the prompt shows as Anna")
			end
		end
	end)
end

-- The marker survives the repair a profile goes through at login; junk does not.
do
	local scenario = "hunt34-never: the clamp keeps typed and filed entries and drops the rest"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			H.drive(scenario, ns)
			local never = ns.db.profile.never
			wipe(never)
			never["Typed"] = true
			never["Filed-Realm"] = "filed"
			never["Odd"] = "yes"
			never["Falsy"] = false
			ns.ClampSettings()
			if never["Typed"] ~= true then fail(scenario, "a typed entry did not survive the repair") end
			if never["Filed-Realm"] ~= "filed" then fail(scenario, "a filed entry did not survive the repair") end
			if never["Odd"] or never["Falsy"] then fail(scenario, "an entry that is neither survived the repair") end
			local list = table.concat(ns.NeverList(), ",")
			if list ~= "Filed-Realm,Typed" then fail(scenario, "the list reads " .. list) end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end
