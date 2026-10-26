-- Hunt 33, from the decision to the cast and what the player sees: Prompt/Press.lua,
-- Clicks.lua, Prompt/Macro.lua, Speech.lua, Phrases.lua and the looks. Every name
-- starts with "hunt33-<area>:" and then the fault.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- Globals a scenario replaces, put back after it whether it finished or threw.
local TOUCHED = { "UnitSex", "IsShiftKeyDown" }

-- One scenario: the mock reset, `names` standing about as strangers on their
-- tokens, the addon loaded and driven to a fresh prompt, body(ns) run, and
-- everything put back after it.
local function run(scenario, names, body, setup)
	Mock.reset()
	if setup then setup() end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }

-- ------------------------------------------------------------------ a key held down
-- hunt33-press: the release of a held key is not a second press
--
-- The key binding delivers a down click, which casts, and an up click, which the
-- secure button ignores (Rows.lua: "an up the client delivers anyway is the end
-- of it", and PreClick's own comment: "Down and up both land here"). The prompt's
-- PreClick and PostClick never look at which of the two they were handed: they
-- pair the two by the clock, and only inside a quarter of a second. A key held
-- longer is two presses to them. After a refused cast the release is resolved
-- afresh: the prompt, still wearing the red flash about Anna, is found to be on
-- somebody else, so it "moves on" -- wiping the refusal off the panel at once and
-- saying so in chat. After a cast that landed, the release meets the global
-- cooldown and writes "ready in 1.1s" over the confirmation.
local function press(ns, down)
	local button = ns.Prompt:GetButton()
	button.scripts.PreClick(button, "LeftButton", down)
	local armed = button:GetAttribute("macrotext1")
	button.scripts.PostClick(button, "LeftButton", down)
	return armed
end

run("hunt33-press: the release of a slowly pressed key does not wipe the refusal", PEOPLE, function(ns)
	local scenario = "hunt33-press: the release of a slowly pressed key does not wipe the refusal"
	owe(ns, "Anna Aim")
	owe(ns, "Bert Beside")
	ns.addon:Tick()
	local macro = press(ns, true)
	if not (macro and macro:find("Anna Aim", 1, true)) then
		fail(scenario, "SKIPPED -- the press was not aimed at Anna: " .. tostring(macro))
		return
	end
	ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
	if ns.Prompt.state.outcomeKind ~= "failed" then
		fail(scenario, "SKIPPED -- the refusal did not flash the panel")
		return
	end
	Mock.printed = {}
	local parked = ns.pendingClick
	-- The key is let go three tenths of a second after it went down: a slow press,
	-- inside the refusal's own 0.6 s.
	Mock.advance(0.3)
	press(ns, false)
	if ns.Prompt.state.outcomeKind ~= "failed" then
		fail(scenario, "the key was let go and the refusal's flash was wiped from the panel 0.3 s into its 0.6 s")
	end
	for _, line in ipairs(Mock.printed) do
		if line:find("moved on", 1, true) then
			fail(scenario, "the key was let go and chat said: " .. line)
		end
	end
	-- The release is not a press: nothing new is filed, for Bert or for anybody.
	if ns.pendingClick ~= parked then
		fail(scenario, "the key was let go and a press on " .. tostring(ns.pendingClick and ns.pendingClick.name)
			.. " was filed")
	end
end)

run("hunt33-press: the release of a slowly pressed key does not say the prompt is not ready", PEOPLE, function(ns)
	local scenario = "hunt33-press: the release of a slowly pressed key does not say the prompt is not ready"
	owe(ns, "Anna Aim")
	owe(ns, "Bert Beside")
	ns.addon:Tick()
	local macro = press(ns, true)
	if not (macro and macro:find("Anna Aim", 1, true)) then
		fail(scenario, "SKIPPED -- the press was not aimed at Anna: " .. tostring(macro))
		return
	end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna Aim", "Cast-1", 1459)
	local r = ns.Prompt:Regions()
	Mock.advance(0.3)
	press(ns, false)
	local text = r.sub and r.sub:GetText()
	if type(text) == "string" and text:find("ready in", 1, true) then
		fail(scenario, "the key was let go 0.3 s after a cast that landed and the panel's second line read: " .. text)
	end
end)

run("hunt33-press: the release of a slowly pressed key does not explain the empty prompt twice", {}, function(ns)
	local scenario = "hunt33-press: the release of a slowly pressed key does not explain the empty prompt twice"
	-- Nobody owed, nobody to offer: the prompt is down and a keypress says why.
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	if button:IsShown() then
		fail(scenario, "SKIPPED -- the prompt was up with nobody to buff")
		return
	end
	Mock.printed = {}
	press(ns, true)
	Mock.advance(0.3)
	press(ns, false)
	local said = 0
	for _, line in ipairs(Mock.printed) do
		if line:find("nobody to buff right now", 1, true) then said = said + 1 end
	end
	if said ~= 1 then
		fail(scenario, ("one slow press of a key on an empty prompt printed the explanation %d times"):format(said))
	end
end)

run("hunt33-press: the release of a key held past a refusal files no press on the next person", PEOPLE, function(ns)
	local scenario = "hunt33-press: the release of a key held past a refusal files no press on the next person"
	owe(ns, "Anna Aim")
	owe(ns, "Bert Beside")
	ns.addon:Tick()
	local macro = press(ns, true)
	if not (macro and macro:find("Anna Aim", 1, true)) then
		fail(scenario, "SKIPPED -- the press was not aimed at Anna: " .. tostring(macro))
		return
	end
	ns.addon:UI_ERROR_MESSAGE(nil, 0, "Out of range.")
	-- Held for most of a second: the refusal's flash is over, and the prompt is on
	-- Bert, whom nobody pressed.
	Mock.advance(0.8)
	ns.addon:Tick()
	Mock.printed = {}
	press(ns, false)
	-- The release ran no macro: nothing can answer a press on Bert. Two seconds on
	-- the game "answers that press with nothing at all".
	Mock.advance(2.5)
	ns.addon:Tick()
	for _, line in ipairs(Mock.printed) do
		if line:find("Bert", 1, true) then
			fail(scenario, "Bert was never pressed, and two seconds after the key came up chat said: " .. line)
		end
	end
end)

-- ------------------------------------------------------------------ gendered lines
-- hunt33-speech: a woman is given a man's line in French, Italian, Spanish and Portuguese
--
-- The lines are first-person ("I am old, dry and extremely flammable"). Where the
-- language agrees an adjective with its speaker, the translation picks the
-- masculine, and nothing in Phrases.lua or Speech.lua ever asks UnitSex, so a
-- female character says it in a man's voice every time it is picked.
-- tools/audit_i18n_gender.py lists 52 such lines; these four stand for them.
local MASCULINE = {
	frFR = "Éloignez les torches de moi, {name}. Je suis vieux, sec et très inflammable.",
	itIT = "Tieni le torce lontane, {name}. Sono vecchio, secco e molto infiammabile.",
	esES = "Gracias, {name}. Los susurros se callaron. Así sé que era sincero.",
	ptBR = "Amanheceu, {name}. Goblin rico dorme até tarde. Ainda não sou rico.",
}
for _, code in ipairs({ "frFR", "itIT", "esES", "ptBR" }) do
	local scenario = "hunt33-speech: a female speaker is not given a masculine first-person line in " .. code
	Mock.reset()
	Mock.locale = code
	local sexAsked = 0
	local real = rawget(_G, "UnitSex")
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			UnitSex = function()
				sexAsked = sexAsked + 1
				return 3
			end
			local RP = ns.InCharacter
			local found
			local function walk(tbl)
				if type(tbl) ~= "table" then return end
				for _, v in pairs(tbl) do
					if v == MASCULINE[code] then
						found = true
					elseif type(v) == "table" then
						walk(v)
					end
				end
			end
			for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
				"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO" }) do
				walk(RP[name])
			end
			if not found then
				fail(scenario, "SKIPPED -- the line is no longer in any pool: " .. MASCULINE[code])
				return
			end
			for _ = 1, 200 do
				RP.Pick({ name = "Anna", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true) }, "say", 250)
			end
			if sexAsked == 0 then
				fail(scenario, "a female character's lines are picked 200 times and the speaker's sex is never asked,"
					.. " while the pools hold \"" .. MASCULINE[code] .. "\"")
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	UnitSex = real
	Mock.reset()
end

-- ------------------------------------------------------------------ one of a group
-- hunt33-text: the group cast's tooltip counts one person as "are"
--
-- A group cast is offered once two people need it (atLeast, GroupBuffs.lua), so one
-- can be missing the buff and one running out. Button.lua writes both counts into
-- plural-only sentences: "1 in Gwen's party are missing ...", "1 more are running out."
run("hunt33-text: a group tooltip does not say one person are", {}, function(ns)
	local scenario = "hunt33-text: a group tooltip does not say one person are"
	local button = ns.Prompt:GetButton()
	local buff = ns.FindBuff("MAGE", "intellect")
	local entry = { name = "Gwen Hale", short = "Gwen Hale", unit = "party1", reason = "group", buff = buff,
		inGroup = true, ranged = true,
		groupCast = { spell = 23028, spellName = "Arcane Brilliance", label = "Gwen's party", members = {},
			missing = 1, low = 1, reagentWaived = true } }
	ns.Prompt.state.current = entry
	local onEnter = button.scripts.OnEnter
	if not onEnter then fail(scenario, "SKIPPED -- no OnEnter") return end
	onEnter(button)
	local tip = table.concat(Mock.tooltip or {}, "\n")
	if not tip:find("missing", 1, true) then fail(scenario, "SKIPPED -- no group lines in the tooltip: " .. tip) return end
	if tip:find("1 in ", 1, true) and tip:find(" are missing", 1, true) then
		fail(scenario, "one person missing the buff reads \"1 in ... are missing\"")
	end
	if tip:find("1 more are running out", 1, true) then
		fail(scenario, "one person running out reads \"1 more are running out\"")
	end
end)

-- ------------------------------------------------------------------ room for the name
-- hunt33-layout: the name line is given room at the sizes the settings allow
--
-- The name is hung between the icon and the count chip by two points. The sliders
-- let the width go down to 80 and the font up to 32, and the room between the
-- points is then negative (the left point is to the right of the right one), so the
-- client has nothing to draw the name in. Toast's medallion is as tall as the panel,
-- so a tall, narrow Toast leaves the name two units. (Whether the client draws a
-- string with crossed points at all is not known; no look should rely on it.)
local CASES = {
	{ style = "glass", width = 80, height = 36, font = 24 },
	{ style = "framed", width = 80, height = 58, font = 32 },
	{ style = "minimal", width = 80, height = 36, font = 24 },
	{ style = "arcane", width = 80, height = 36, font = 24 },
	{ style = "toast", width = 140, height = 120, font = 13 },
	{ style = "letter", width = 80, height = 36, font = 24 },
}
for _, case in ipairs(CASES) do
	local scenario = ("hunt33-layout: the name has room at %dx%d, %d pt, in %s"):format(case.width, case.height, case.font, case.style)
	Mock.reset()
	FT.install()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style, p.width, p.height, p.fontSize = case.style, case.width, case.height, case.font
			p.showIcon, p.showCount, p.showQueue = true, true, false
			p.iconSize = math.max(12, math.min(30, ns.IconCeiling(p)))
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			owe(ns, "Bert Beside")
			ns.addon:Tick()
			FT.settle()
			local room = FT.boundWidth(ns.Prompt:Regions().name)
			if type(room) ~= "number" then
				fail(scenario, "SKIPPED -- the name line has no two points")
			elseif room < 20 then
				fail(scenario, ("the name line is %s units wide between its points (chip %s)"):format(
					tostring(room), tostring(ns.Prompt:Regions().chip:IsShown())))
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	FT.uninstall()
	Mock.reset()
end
