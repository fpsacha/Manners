-- The prompt's own key in a fight (Prompt/FightKey.lua): with a spell chosen
-- under In a fight, the pull points the prompt's bound keys at a secure
-- button of its own (an override binding, set while the lockdown has not yet
-- begun) and the end of the fight takes them away. The button is never
-- shown; the prompt, its macro, the hold, the hide snippet and the rota are
-- left as they are.
--
-- These hold Manners to the mock's model of override bindings
-- (SetOverrideBindingClick, ClearOverrideBindings and Mock.pressKey in
-- tests/mockapi.lua and tests/mockwidgets.lua) and of the client's secure
-- click, not to the client: whether the override takes at
-- PLAYER_REGEN_DISABLED on each client, and where a bare /cast lands on
-- Forever with a mob targeted, only a fight can say (STATUS.md).
--
-- Every name starts with "fightkey:" so a mutation in
-- tests/mutations/fightkey.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, findOption = H.strangers, H.freshPrompt, H.owe, H.findOption

local PROMPT_KEY = "CLICK MannersPrompt:LeftButton"
local FIGHT_KEY = "CLICK MannersFightKey:LeftButton"
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" }, nameplate3 = { "Cara", "Cole" } }
local NAMES = { "Anna Aim", "Bob Bright", "Cara Cole" }
local SHIELD = "Power Word: Shield"

-- The names the client gives the spells these scenarios use.
local SPELL_NAMES = {
	[17] = "Power Word: Shield", [139] = "Renew", [2061] = "Flash Heal", [11426] = "Ice Barrier",
	[1463] = "Mana Shield", [19750] = "Flash of Light", [498] = "Divine Protection", [85673] = "Word of Glory",
}

-- A spellbook that holds every spell there is: the priest's buffs and each
-- row of the list are known unless a scenario says what is.
local function everything()
	return setmetatable({}, { __index = function() return true end })
end

local function base(key)
	local meta = getmetatable(_G)
	local index = meta and meta.__index
	if type(index) == "function" then return index(_G, key) end
	return nil
end

local function castsSince(n)
	local out = {}
	for i = n + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused then out[#out + 1] = e end
	end
	return out
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- One session on the client `flavour`: a priest (unless opts.class) in a
-- party-less world with three people owed a buff on nameplates, the prompt's
-- key on F. opts.spell is the fight key's spell, opts.known the spells
-- known (everything by default), opts.edit(p, ns) runs before the first
-- scan, opts.bar puts the Manners macro on a bar slot, opts.key = false binds
-- nothing.
local function with(base_, flavour, body, opts)
	opts = opts or {}
	local scenario = base_ .. " (" .. flavour .. ")"
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = opts.class or "PRIEST"
	local known = everything()
	if opts.known then
		known = {}
		for id, on in pairs(opts.known) do known[id] = on end
	end
	Mock.knownSpells = known
	local restore = strangers(opts.people or PEOPLE)
	local savedSpell = rawget(_G, "C_Spell")
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			local real = base("C_Spell")
			rawset(_G, "C_Spell", setmetatable({
				GetSpellName = function(id) return SPELL_NAMES[id] or (real and real.GetSpellName(id)) end,
			}, { __index = real }))
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.KeyNudge = nil
			local p = ns.db.profile.prompt
			if opts.spell then p.fightKeySpell = opts.spell end
			if opts.edit then opts.edit(p, ns) end
			ns.Prompt:ApplyStyle()
			Mock.bindings = Mock.bindings or {}
			if opts.key ~= false then Mock.bindings.F = PROMPT_KEY end
			if opts.owed ~= false then
				for _, name in ipairs(opts.owed or NAMES) do owe(ns, name) end
			end
			ns.addon:Tick()
			if opts.bar then
				ns.CreateClickMacro()
				Mock.dropOnBar(2)
				ns.addon:Tick()
			end
			Mock.runTimers(0)
			body(ns, scenario, ns.db.profile.prompt)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	Mock.inCombat = false
	rawset(_G, "C_Spell", savedSpell)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function each(name, body, opts)
	for _, flavour in ipairs(FLAVOURS) do with(name, flavour, body, opts) end
end

-- The pull as the client orders it: PLAYER_REGEN_DISABLED just before the
-- lockdown, then the lockdown, then the state driver's next frame.
local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

local function overridden()
	local n = 0
	for _ in pairs(Mock.overrides or {}) do n = n + 1 end
	return n
end

local function fightButton()
	return Mock.namedFrames and Mock.namedFrames.MannersFightKey
end

-- The macro the button should hold on this client, for a spell that can go on
-- others: the conditional one, or a bare cast on Forever.
local function friendMacro(flavour, name)
	if flavour == "camelot" then return "/cast " .. name end
	return "/cast [@mouseover,help,nodead][help,nodead][@player] " .. name
end

-- Whether the prompt is up and armed to buff somebody before the fight, which
-- these scenarios need to say what the key does instead.
local function armed(ns, scenario)
	local button = ns.Prompt:GetButton()
	if button:GetAttribute("type1") ~= "macro" then
		fail(scenario, "SKIPPED -- the prompt is not armed before the fight")
		return false
	end
	return true
end

-- One press of F, the key a player holds the prompt on.
local function pressF()
	Mock.advance(2)
	return Mock.pressKey("F")
end

-- ------------------------------------------------------------------ 1
each("fightkey: Nothing by default leaves the key on the prompt", function(ns, scenario, p)
	if p.fightKeySpell ~= "none" then fail(scenario, "the setting is " .. tostring(p.fightKeySpell) .. " in a new profile") end
	if not armed(ns, scenario) then return end
	if fightButton() then fail(scenario, "a button was made with nothing chosen") end
	pull(ns)
	if overridden() > 0 then fail(scenario, "an override binding was set with nothing chosen") end
	if ns.FightKey:Taken() then fail(scenario, "the key says it was taken with nothing chosen") end
	local before = #Mock.castLog
	pressF()
	local casts = castsSince(before)
	if #casts ~= 1 then
		fail(scenario, "the key cast " .. #casts .. " spells in the fight")
	elseif tostring(casts[1].spell):find("Shield", 1, true) then
		fail(scenario, "the key cast " .. tostring(casts[1].spell) .. " with nothing chosen")
	end
	release(ns)
end)

-- ------------------------------------------------------------------ 2
each("fightkey: a priest's key casts Power Word: Shield in a fight", function(ns, scenario)
	if not armed(ns, scenario) then return end
	local button = fightButton()
	if not button then fail(scenario, "no button was made with a spell chosen") return end
	if overridden() > 0 then fail(scenario, "an override was set out of a fight") end
	local promptMacro = ns.Prompt:GetButton():GetAttribute("macrotext1")
	pull(ns)
	local over = Mock.overrides.F
	if not over then fail(scenario, "the prompt's key was not pointed anywhere at the pull") release(ns) return end
	if over.command ~= FIGHT_KEY then fail(scenario, "the key was pointed at " .. tostring(over.command)) end
	if ns.FightKey:Taken() ~= SHIELD then fail(scenario, "the key says it casts " .. tostring(ns.FightKey:Taken())) end
	local before = #Mock.castLog
	pressF()
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= SHIELD then
		fail(scenario, "F in the fight cast " .. (casts[1] and tostring(casts[1].spell) or "nothing") .. " (" .. #casts .. " casts)")
	end
	local now = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
	if not now:find("/cast", 1, true) or now:find("Shield", 1, true) then
		fail(scenario, "the prompt's own macro changed: " .. flat(now) .. " (was " .. flat(promptMacro) .. ")")
	end
	release(ns)
end, { spell = "shield" })

-- ------------------------------------------------------------------ 3
each("fightkey: out of a fight the key buffs again", function(ns, scenario)
	if not armed(ns, scenario) then return end
	pull(ns)
	if not Mock.overrides.F then fail(scenario, "SKIPPED -- the pull took no key") release(ns) return end
	release(ns)
	if overridden() > 0 then fail(scenario, "an override binding is still set after the fight") end
	if ns.FightKey:Taken() then fail(scenario, "the key still says it is taken") end
	local before = #Mock.castLog
	pressF()
	local casts = castsSince(before)
	if #casts ~= 1 then
		fail(scenario, "F after the fight cast " .. #casts .. " spells")
	elseif casts[1].spell == SHIELD then
		fail(scenario, "F after the fight still cast Power Word: Shield")
	end
	-- The next fight takes it again.
	pull(ns)
	if not Mock.overrides.F then fail(scenario, "the next fight did not take the key") end
	release(ns)
	if overridden() > 0 then fail(scenario, "an override is left after the second fight") end
end, { spell = "shield" })

-- ------------------------------------------------------------------ 4
each("fightkey: the macro is the conditional one off Forever and a bare cast on Forever", function(ns, scenario, p)
	local button = fightButton()
	if not button then fail(scenario, "no button was made") return end
	local want = friendMacro(ns.Flavour.flavour, SHIELD)
	for _, attr in ipairs({ "macrotext1", "macrotext" }) do
		if button:GetAttribute(attr) ~= want then
			fail(scenario, attr .. " is " .. flat(button:GetAttribute(attr)) .. ", wanted " .. want)
		end
	end
	if button:GetAttribute("type1") ~= "macro" or button:GetAttribute("type") ~= "macro" then
		fail(scenario, "the button is not armed to run a macro")
	end
	-- Me: only you, on a client where [@player] resolves; a bare cast on Forever.
	local on = findOption(ns.optionsTable, "fightKeyOn")
	if not on then fail(scenario, "no Who it lands on control") return end
	local isHidden = on.hidden() == true
	if isHidden ~= (ns.Flavour.flavour == "camelot") then
		fail(scenario, "Who it lands on is " .. (isHidden and "hidden" or "shown") .. " on " .. ns.Flavour.flavour)
	end
	p.fightKeyOn = "me"
	ns.FightKey:Refresh()
	local me = ns.Flavour.flavour == "camelot" and "/cast " .. SHIELD or "/cast [@player] " .. SHIELD
	if button:GetAttribute("macrotext1") ~= me then
		fail(scenario, "with Me the macro is " .. flat(button:GetAttribute("macrotext1")) .. ", wanted " .. me)
	end
	p.fightKeyOn = "friend"
	ns.FightKey:Refresh()
	if button:GetAttribute("macrotext1") ~= want then fail(scenario, "back to friend the macro is " .. flat(button:GetAttribute("macrotext1"))) end
	-- A spell only for yourself is a bare cast either way.
	local self_ = { id = 11426, name = "Ice Barrier", self = true }
	for _, who in ipairs({ "friend", "me" }) do
		local macro = ns.FightKey.MacroFor(self_, who)
		if macro ~= "/cast Ice Barrier" then fail(scenario, "a self spell with " .. who .. " is " .. tostring(macro)) end
	end
	if #want > ns.MACRO_LIMIT then fail(scenario, "the macro is over the limit") end
end, { spell = "shield" })

each("fightkey: the macro is the conditional one off Forever and a bare cast on Forever", function(ns, scenario)
	-- A mage's Ice Barrier lands on you only: a bare cast, and no choice of who.
	local button = fightButton()
	if not button then fail(scenario, "no button for the mage") return end
	if button:GetAttribute("macrotext1") ~= "/cast Ice Barrier" then
		fail(scenario, "a mage's macro is " .. flat(button:GetAttribute("macrotext1")))
	end
	local on = findOption(ns.optionsTable, "fightKeyOn")
	if on and on.hidden() ~= true then fail(scenario, "Who it lands on is shown for a spell only for yourself") end
end, { spell = "barrier", class = "MAGE", owed = false })

-- ------------------------------------------------------------------ 5
each("fightkey: the list offers only spells the character knows", function(ns, scenario)
	local function keys()
		local out = {}
		for _, entry in ipairs(ns.FightKey.Choices()) do out[#out + 1] = entry.key end
		return table.concat(out, ",")
	end
	if keys() ~= "none,shield,flash" then fail(scenario, "with two of three known the list is " .. keys()) end
	local list = ns.FightKey.Choices()
	if not (list[2] and list[2].name == SHIELD and list[3] and list[3].name == "Flash Heal") then
		fail(scenario, "the names are not the client's own")
	end
	local select_ = findOption(ns.optionsTable, "fightKeySpell")
	if not select_ then fail(scenario, "no select") return end
	if select_.hidden() == true then fail(scenario, "the select is hidden with spells to pick") end
	local values = select_.values()
	if values.none ~= "Nothing (keep to buffs)" or values.shield ~= SHIELD or values.renew ~= nil then
		fail(scenario, "the select's values are wrong: " .. tostring(values.none) .. " / " .. tostring(values.renew))
	end
	local sorted = table.concat(select_.sorting(), ",")
	if sorted ~= "none,shield,flash" then fail(scenario, "the select's order is " .. sorted) end
	-- Learning Renew puts it in its place; forgetting all of them leaves nothing to pick.
	Mock.knownSpells[139] = true
	ns.Guard("probe", ns.ProbeCapabilities)
	if keys() ~= "none,shield,renew,flash" then fail(scenario, "after learning Renew the list is " .. keys()) end
	Mock.knownSpells = {}
	ns.Guard("probe", ns.ProbeCapabilities)
	if keys() ~= "none" then fail(scenario, "with nothing known the list is " .. keys()) end
	if select_.hidden() ~= true then fail(scenario, "the select is shown with nothing to pick") end
end, { known = { [17] = true, [2061] = true }, owed = false })

-- ------------------------------------------------------------------ 6
each("fightkey: a change in a fight counts from the next one", function(ns, scenario, p)
	if not armed(ns, scenario) then return end
	local button = fightButton()
	if not button then fail(scenario, "no button") return end
	Mock.protect(button)
	pull(ns)
	if not Mock.overrides.F then fail(scenario, "SKIPPED -- the pull took no key") release(ns) return end
	Mock.protectedCalls = {}
	local before = overridden()
	local macro = button:GetAttribute("macrotext1")
	-- The select's own set, in the fight: saved, and nothing else.
	local select_ = findOption(ns.optionsTable, "fightKeySpell")
	p.fightKeySpell = "renew"
	ns.Guard("fight key", ns.FightKey.Refresh, ns.FightKey)
	ns.addon:Tick()
	if #Mock.protectedCalls > 0 then
		fail(scenario, "the addon called " .. table.concat(Mock.protectedCalls, ", ") .. " on the fight key's button in the fight")
	end
	if button:GetAttribute("macrotext1") ~= macro then fail(scenario, "the macro changed in the fight: " .. flat(button:GetAttribute("macrotext1"))) end
	if overridden() ~= before then fail(scenario, "the override changed in the fight") end
	local count = #Mock.castLog
	pressF()
	local casts = castsSince(count)
	if #casts ~= 1 or casts[1].spell ~= SHIELD then
		fail(scenario, "F in the fight cast " .. (casts[1] and tostring(casts[1].spell) or "nothing") .. " after the change")
	end
	if not select_ then fail(scenario, "no select") end
	release(ns)
	ns.addon:Tick()
	if button:GetAttribute("macrotext1") ~= friendMacro(ns.Flavour.flavour, "Renew") then
		fail(scenario, "after the fight the macro is " .. flat(button:GetAttribute("macrotext1")))
	end
	pull(ns)
	count = #Mock.castLog
	pressF()
	casts = castsSince(count)
	if #casts ~= 1 or casts[1].spell ~= "Renew" then
		fail(scenario, "F in the next fight cast " .. (casts[1] and tostring(casts[1].spell) or "nothing"))
	end
	release(ns)
end, { spell = "shield" })

-- ------------------------------------------------------------------ 7
each("fightkey: nothing new is shown in a fight", function(ns, scenario)
	local button = fightButton()
	if not button then fail(scenario, "no button") return end
	local function check(when)
		if button:IsShown() then fail(scenario, "the fight key's button is shown " .. when) end
		if button:IsVisible() then fail(scenario, "the fight key's button is visible " .. when) end
	end
	check("before the fight")
	pull(ns)
	check("at the pull")
	Mock.advance(1)
	ns.addon:Tick()
	Mock.runTimers(0.5)
	pressF()
	check("in the fight")
	release(ns)
	check("after the fight")
	ns.addon:Tick()
	check("after a scan")
end, { spell = "shield" })

-- ------------------------------------------------------------------ 8
each("fightkey: with the prompt hidden for the fight the key casts the fight spell and the prompt casts nothing", function(ns, scenario)
	local button = ns.Prompt:GetButton()
	if not armed(ns, scenario) then return end
	pull(ns)
	if not ns.Prompt:HiddenForFight() then fail(scenario, "SKIPPED -- the prompt was not hidden for the fight") release(ns) return end
	if button:GetAttribute("type1") == "macro" or button:GetAttribute("macrotext1") then
		fail(scenario, "the hidden prompt still holds a macro")
	end
	if not Mock.overrides.F then fail(scenario, "the key was not pointed at the fight key") release(ns) return end
	local before = #Mock.castLog
	pressF()
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= SHIELD then
		fail(scenario, "F with the prompt hidden cast " .. (casts[1] and tostring(casts[1].spell) or "nothing"))
	end
	before = #Mock.castLog
	Mock.advance(2)
	Mock.pressBinding(PROMPT_KEY)
	if #castsSince(before) > 0 then fail(scenario, "the hidden prompt cast something") end
	release(ns)
	if overridden() > 0 then fail(scenario, "an override is left after the fight") end
end, { spell = "shield", bar = true, edit = function(p) p.hideInFight = true end })

-- ------------------------------------------------------------------ 9
each("fightkey: a click on the prompt still steps the rota", function(ns, scenario)
	if not armed(ns, scenario) then return end
	local header = ns.Prompt:FightHeader()
	pull(ns)
	local held = header and header:GetAttribute("manners-rota-n")
	if not (type(held) == "number" and held >= 3) then
		fail(scenario, "SKIPPED -- the rota holds " .. tostring(held))
		release(ns)
		return
	end
	if not Mock.overrides.F then fail(scenario, "the key was not pointed at the fight key") release(ns) return end
	local at = header:GetAttribute("manners-rota-i")
	local before = #Mock.castLog
	pressF()
	local f = castsSince(before)
	if #f ~= 1 or f[1].spell ~= SHIELD then fail(scenario, "F cast " .. (f[1] and tostring(f[1].spell) or "nothing")) end
	if header:GetAttribute("manners-rota-i") ~= at then fail(scenario, "the fight key's press stepped the rota") end
	-- A click on the prompt: a buff, at the next person each time.
	local who = {}
	for i = 1, 2 do
		before = #Mock.castLog
		Mock.advance(2)
		Mock.pressBinding(PROMPT_KEY)
		local c = castsSince(before)
		if #c ~= 1 or tostring(c[1].spell):find("Shield", 1, true) then
			fail(scenario, "click " .. i .. " on the prompt cast " .. (c[1] and tostring(c[1].spell) or "nothing"))
		end
		who[i] = c[1] and (tostring(c[1].spell) .. " at " .. tostring(c[1].target))
	end
	if who[1] == nil or who[1] == who[2] then
		fail(scenario, "two clicks on the prompt reached " .. tostring(who[1]) .. " and " .. tostring(who[2]))
	end
	if header:GetAttribute("manners-rota-i") == at then fail(scenario, "the clicks did not step the rota") end
	release(ns)
end, { spell = "shield" })

-- ------------------------------------------------------------------ 10
each("fightkey: a spell no longer known gives the key back to the prompt", function(ns, scenario, p)
	if not fightButton() then fail(scenario, "no button") return end
	-- Forgotten before the fight (a respec): the key stays the prompt's.
	Mock.knownSpells = {}
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.addon:Tick()
	if ns.FightKey.Chosen() ~= nil then fail(scenario, "a spell not known is still chosen") end
	if ns.FightKey.Applies() then fail(scenario, "the fight key applies without its spell") end
	if p.fightKeySpell ~= "shield" then fail(scenario, "the saved choice was wiped: " .. tostring(p.fightKeySpell)) end
	if fightButton():GetAttribute("macrotext1") then fail(scenario, "the button is still armed") end
	pull(ns)
	if overridden() > 0 then fail(scenario, "the key was taken for a spell not known") end
	release(ns)
	-- Learned again: the choice is back.
	Mock.knownSpells = everything()
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.addon:Tick()
	if not fightButton():GetAttribute("macrotext1") then fail(scenario, "relearning did not arm the button again") end
	pull(ns)
	if not Mock.overrides.F then fail(scenario, "the choice did not come back with the spell") end
	release(ns)
end, { spell = "shield", owed = false })

-- ------------------------------------------------------------------ 11
each("fightkey: no binding is touched under the lockdown", function(ns, scenario)
	if not fightButton() then fail(scenario, "no button") return end
	pull(ns)
	local over = Mock.overrides.F
	if not over then fail(scenario, "SKIPPED -- the pull took no key") release(ns) return end
	-- In the fight Take and Release are no-ops; the mock raises the client's
	-- error for any override call made under the lockdown.
	local ok, err = pcall(ns.FightKey.Take, ns.FightKey)
	if not ok then fail(scenario, "Take under the lockdown threw: " .. tostring(err)) end
	ok, err = pcall(ns.FightKey.Release, ns.FightKey)
	if not ok then fail(scenario, "Release under the lockdown threw: " .. tostring(err)) end
	ok, err = pcall(ns.FightKey.Refresh, ns.FightKey)
	if not ok then fail(scenario, "Refresh under the lockdown threw: " .. tostring(err)) end
	if Mock.overrides.F ~= over then fail(scenario, "the override was changed under the lockdown") end
	release(ns)
end, { spell = "shield", owed = false })

-- ------------------------------------------------------------------ 12
do
	local scenario = "fightkey: the controls sit under In a fight after the rota"
	local layout
	local function holder(node, path, seen)
		if type(node) ~= "table" then return nil end
		seen = seen or {}
		if seen[node] then return nil end
		seen[node] = true
		if type(node.items) == "table" then
			for i, item in ipairs(node.items) do
				if item == path or (type(item) == "table" and item[1] == path) then return node.items, i end
			end
		end
		for _, child in pairs(node) do
			local items, at = holder(child, path, seen)
			if items then return items, at end
		end
		return nil
	end
	local function pathOf(item) return type(item) == "table" and item[1] or item end
	with(scenario, "camelot", function(ns)
		layout = ns.WindowLayout
		if not layout then fail(scenario, "SKIPPED -- no layout") return end
		local items, at = holder(layout, "appearance.fightRota")
		if not items then fail(scenario, "appearance.fightRota is not placed") return end
		if pathOf(items[at + 1]) ~= "appearance.fightKeySpell" then fail(scenario, "the spell does not follow the rota's switch") end
		local on = items[at + 2]
		if pathOf(on) ~= "appearance.fightKeyOn" or not (type(on) == "table" and on.indent == true) then
			fail(scenario, "Who it lands on is not the next row, indented")
		end
		local simple = layout.simple and layout.simple.items or {}
		if not (simple["appearance.fightKeySpell"] and simple["appearance.fightKeyOn"]) then
			fail(scenario, "the controls are not in the simple view")
		end
		if not (layout.keywords and layout.keywords["appearance.fightKeySpell"]) then fail(scenario, "no search words") end
		-- Every setting is reset with the look's.
		local select_ = findOption(ns.optionsTable, "fightKeySpell")
		if not select_ then fail(scenario, "no select in the options") end
	end, { owed = false })
end
