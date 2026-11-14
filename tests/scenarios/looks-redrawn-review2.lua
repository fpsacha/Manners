-- The second review of the redrawn looks (Looks/Letter.lua, Looks/Ribbon.lua)
-- and of the Look page's cards (Options/Window/WidgetsTheme.lua).
--
--   * Letter: the arrival (the unroll, the seal's pour, the letter written in
--     under its cover) is not played over an outcome, neither in the outcome's
--     own repaint nor at a scan while the verdict stands.
--   * Letter: the flourish a landing is signed with stands with the verdict
--     while somebody else is still on the prompt.
--   * Letter: the pen crosses the whole sheet when a list hangs in the paint
--     that begins the writing, and only the lines when the list has gone.
--   * Ribbon: an outcome's headline on the name line keeps its own colours.
--   * Ribbon: the cloth is not faded in from nothing in the settle at the end
--     of the entrance, where the panel already stands at its full strength.
--   * the cards: the longest description is whole in every language at the
--     window's smallest size.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "looks-redrawn-review2:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local PAIR = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local FULL = { ["Anna Aim"] = true, ["Brannoc Vale"] = true }

local function withTree(scenario, names, body)
	Mock.reset()
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

-- Who stands about from here on: the nameplates the queue walks. withTree
-- puts UnitExists back.
local function about(ns, names)
	strangers(names)
	wipe(ns.nameplateUnits)
	wipe(ns.passersBy)
	for unit in pairs(names) do ns.nameplateUnits[unit] = true end
end

-- Nobody about and nobody owed: the prompt taken down.
local function down(ns)
	about(ns, {})
	tick(ns)
	Mock.advance(5)
	tick(ns)
	Mock.advance(5)
	tick(ns)
	return not ns.Prompt:GetButton():IsShown()
end

-- The prompt's settings for `style` on Full effects, nobody owed yet.
local function dress(ns, scenario, style, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle = style, "full", "pulse"
	p.hideInCombat, p.showIcon, p.showSub, p.width = false, true, true, 260
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	return p
end

local function plays(list)
	local n = 0
	for _, g in ipairs(list) do n = n + (g._plays or 0) end
	return n
end

local function anyPlaying(list)
	for _, g in ipairs(list) do
		if g._playing then return true end
	end
	return false
end

-- Every call of the look's Attention from here on, kept: { isNew, arrived }.
local function watch(look)
	local calls = {}
	local inner = look.Attention
	look.Attention = function(self, isNew, arrived, ...)
		calls[#calls + 1] = { isNew and true or false, arrived and true or false }
		return inner(self, isNew, arrived, ...)
	end
	return calls, function() look.Attention = inner end
end

local function sawNew(calls)
	for _, c in ipairs(calls) do
		if c[1] then return true end
	end
	return false
end

-- Two people owed on the Letter, the arrival long over. Returns the look, who
-- is on top and who is next.
local function twoOwed(ns, scenario, edit)
	local p = dress(ns, scenario, "letter", edit)
	owe(ns, "Anna Aim")
	owe(ns, "Brannoc Vale")
	tick(ns)
	local look = ns.Prompt:Regions().look
	if not (look and look.unrollGroups and look.holds and look.coverGroups and look.swash) then
		fail(scenario, "SKIPPED -- Letter is not the look in use")
		return
	end
	Mock.advance(3)
	FT.settle()
	tick(ns)
	local top = ns.Prompt:PanelName()
	if not FULL[top or ""] then
		fail(scenario, "SKIPPED -- neither of the two owed is on the prompt: " .. tostring(top))
		return
	end
	local nextUp = top == "Anna Aim" and "Brannoc Vale" or "Anna Aim"
	if anyPlaying(look.unrollGroups) or anyPlaying(look.holds) or anyPlaying(look.coverGroups) then
		fail(scenario, "SKIPPED -- three seconds on, the first arrival is still playing")
		return
	end
	return look, top, nextUp, p
end

-- What the arrival plays, counted.
local function arrivalPlays(look)
	return { unroll = plays(look.unrollGroups), holds = plays(look.holds), cover = plays(look.coverGroups),
		stamp = plays(look.stamp), press = plays(look.pressAnims) }
end

local function sameArrival(scenario, look, before, when)
	local now = arrivalPlays(look)
	local parts = { { "unroll", "the scroll unrolls again" }, { "stamp", "the seal is poured again" },
		{ "press", "the seal is pressed again" }, { "holds", "the words are held back again" },
		{ "cover", "the lines are covered and written in again" } }
	for _, part in ipairs(parts) do
		if now[part[1]] ~= before[part[1]] then
			fail(scenario, ("%s, over the verdict: %s"):format(when, part[2]))
		end
	end
end

-- ------------------------------------------------------------------ 1
-- The arrival is for a new favour on a prompt that has nothing else to say:
-- never over an outcome.
withTree("looks-redrawn-review2: Letter does not play the arrival in an outcome's own repaint", PAIR, function(ns, scenario)
	local look, top, nextUp = twoOwed(ns, scenario)
	if not look then return end
	local before = arrivalPlays(look)
	local calls, unwatch = watch(look)
	-- The press for `top` is confirmed: its debt is gone, and the outcome's own
	-- repaint finds the other on top.
	ns.owed[top] = nil
	ns.Prompt:ShowOutcome("cast", top)
	unwatch()
	if not sawNew(calls) then
		fail(scenario, "SKIPPED -- the outcome's repaint did not bring the next person owed to the top as news")
		return
	end
	if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- no outcome is live after ShowOutcome") return end
	sameArrival(scenario, look, before, "in the outcome's own repaint")
	-- The verdict over: the next favour of somebody new is an arrival again.
	Mock.advance(1)
	tick(ns)
	Mock.advance(3)
	FT.settle()
	before = arrivalPlays(look)
	ns.owed[nextUp] = nil
	tick(ns)
	owe(ns, top)
	tick(ns)
	if arrivalPlays(look).unroll == before.unroll then
		fail(scenario, "with no verdict on the panel a new favour no longer unrolls the scroll")
	end
end)

withTree("looks-redrawn-review2: Letter does not play the arrival at a scan under a verdict", PAIR, function(ns, scenario)
	local look, top = twoOwed(ns, scenario)
	if not look then return end
	-- The verdict first, with `top` still the one owed (the settle has not yet
	-- taken the debt): nothing is new.
	ns.Prompt:ShowOutcome("cast", top)
	local before = arrivalPlays(look)
	local calls, unwatch = watch(look)
	Mock.advance(0.3)
	ns.owed[top] = nil
	tick(ns)
	unwatch()
	if not sawNew(calls) then
		fail(scenario, "SKIPPED -- the scan did not bring the next person owed to the top as news")
		return
	end
	if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the outcome ended before the scan") return end
	sameArrival(scenario, look, before, "at the scan that brought the next person up")
end)

-- ------------------------------------------------------------------ 2
-- The flourish a landing is signed with stands with the verdict, whoever is
-- next on the prompt, and goes with it.
withTree("looks-redrawn-review2: Letter's signed flourish stands with the verdict while somebody is still owed", PAIR, function(ns, scenario)
	local look, top = twoOwed(ns, scenario)
	if not look then return end
	if not look.swashW then fail(scenario, "SKIPPED -- the look has no room for a flourish at this size") return end
	ns.owed[top] = nil
	ns.Prompt:ShowOutcome("cast", top)
	if not (look.signed and look.swash:IsShown()) then
		fail(scenario, "a landing with somebody still owed is not signed: the quill travels and no flourish is written")
	end
	if not anyPlaying(look.signGroups) then fail(scenario, "the flourish is not being written in as the buff lands") end
	-- The scan under the verdict repaints the next person's reason first.
	Mock.advance(0.3)
	tick(ns)
	if not ns.Prompt:OutcomeLive() then fail(scenario, "SKIPPED -- the outcome ended before the scan") return end
	if not (look.signed and look.swash:IsShown()) then
		fail(scenario, "the flourish is gone at the next scan, the verdict still standing")
	end
	-- And it goes with the verdict.
	Mock.advance(1)
	tick(ns)
	if look.signed or look.swash:IsShown() then fail(scenario, "the flourish outlives the verdict") end
end)

withTree("looks-redrawn-review2: Letter's signed flourish stands when the next reason is another colour", PAIR, function(ns, scenario)
	local p = dress(ns, scenario, "letter")
	owe(ns, "Anna Aim")
	tick(ns)
	local look = ns.Prompt:Regions().look
	if not (look and look.swash and look.signGroups) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	if not look.swashW then fail(scenario, "SKIPPED -- the look has no room for a flourish at this size") return end
	Mock.advance(3)
	FT.settle()
	tick(ns)
	-- Anna's buff lands; the passer-by is next, in another reason's colour, so
	-- the outcome's own repaint paints a reason before the verdict.
	local painted = 0
	local inner = look.PaintReason
	look.PaintReason = function(self, ...)
		painted = painted + 1
		return inner(self, ...)
	end
	ns.owed["Anna Aim"] = nil
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	look.PaintReason = inner
	if painted == 0 then
		fail(scenario, "SKIPPED -- the outcome's repaint painted no reason: nobody of another colour was next")
		return
	end
	if not (look.signed and look.swash:IsShown()) then
		fail(scenario, "a reason painted under the verdict took the flourish away as it was signed")
	end
end)

-- A refusal after a landing takes the flourish with it, as before.
withTree("looks-redrawn-review2: Letter's flourish goes when a refusal follows the landing", PAIR, function(ns, scenario)
	local look, top, nextUp = twoOwed(ns, scenario)
	if not look then return end
	ns.owed[top] = nil
	ns.Prompt:ShowOutcome("cast", top)
	Mock.advance(0.2)
	ns.Prompt:ShowOutcome("failed", nextUp, "Out of range")
	if look.swash:IsShown() then fail(scenario, "a refusal is signed with the landing's flourish") end
end)

-- ------------------------------------------------------------------ 3
-- The pen's reach is this paint's: the whole sheet under a list, the longer
-- line without one.
local function reachOf(look)
	local o = look.write and look.write.run and look.write.run._offset
	return o and o[1]
end

withTree("looks-redrawn-review2: Letter's pen crosses the sheet when a list hangs with the arrival", CROWD, function(ns, scenario)
	dress(ns, scenario, "letter", function(p) p.showQueue, p.queueRows = true, 3 end)
	local button = ns.Prompt:GetButton()
	-- Nobody owed and nobody offered: the prompt is down, with no list.
	local isDown = down(ns)
	local look = ns.Prompt:Regions().look
	if not (look and look.write and look.coverGroups) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	if not isDown then fail(scenario, "SKIPPED -- the prompt is up with nobody about") return end
	if look.listShown then fail(scenario, "SKIPPED -- a list is already hanging before anybody is owed") return end
	local before = plays(look.coverGroups)
	about(ns, CROWD)
	owe(ns, "Anna Aim")
	tick(ns)
	if not button:IsShown() then fail(scenario, "SKIPPED -- the prompt did not come up for the favour") return end
	if plays(look.coverGroups) == before then fail(scenario, "SKIPPED -- the favour's arrival wrote no letter") return end
	if not look.listShown then fail(scenario, "SKIPPED -- no list hangs under the favour") return end
	local g = look.g
	local room = g.rodR - 0.5 - (g.textX - 2)
	local reach = reachOf(look)
	if not (reach and math.abs(reach - room) < 0.01) then
		fail(scenario, ("a list hangs with the arrival and the pen reaches %s of the sheet's %.1f: the rows past it pop in"):format(
			tostring(reach), room))
	end
	local pen = look.write.pen._offset
	if not (pen and math.abs(pen[1] - room) < 0.01) then
		fail(scenario, "the quill does not travel as far as the cover it draws off")
	end
	if not anyPlaying(look.coverGroups) then fail(scenario, "the cover is not being drawn off after the reach was taken again") end
end)

withTree("looks-redrawn-review2: Letter's pen stops at the lines when the list has gone", CROWD, function(ns, scenario)
	local p = dress(ns, scenario, "letter", function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	tick(ns)
	local look = ns.Prompt:Regions().look
	if not (look and look.write and look.coverGroups) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
	if not look.listShown then fail(scenario, "SKIPPED -- no list hangs with four passers-by") return end
	Mock.advance(3)
	FT.settle()
	-- The others leave and one of them does the favour in the same scan: this
	-- paint has no list.
	local function restore() end
	about(ns, ANNA)
	Mock.advance(8)
	tick(ns)
	Mock.advance(3)
	FT.settle()
	if look.listShown then fail(scenario, "SKIPPED -- a list still hangs with one person about") return end
	-- A list again, and in one scan the others leave and Anna does the favour.
	about(ns, CROWD)
	tick(ns)
	Mock.advance(3)
	FT.settle()
	if not look.listShown then fail(scenario, "SKIPPED -- the list did not come back with the others") return end
	about(ns, ANNA)
	Mock.advance(8)
	local before = plays(look.coverGroups)
	owe(ns, "Anna Aim")
	tick(ns)
	local reach = reachOf(look)
	local g = look.g
	local room = g.rodR - 0.5 - (g.textX - 2)
	if plays(look.coverGroups) == before then fail(scenario, "SKIPPED -- the favour's arrival wrote no letter") restore() return end
	if look.listShown then fail(scenario, "SKIPPED -- a list still hangs with one person about") restore() return end
	local kit = ns.Prompt:LookKit()
	local wide = math.max(kit.TextWidth(kit.name) or 0, kit.TextWidth(kit.sub) or 0)
	if wide + 8 >= room - 1 then fail(scenario, "SKIPPED -- the lines are as wide as the sheet") restore() return end
	if not (reach and math.abs(reach - math.max(24, wide + 8)) < 0.01) then
		fail(scenario, ("the list has gone and the pen reaches %s, not the longer line's %.1f"):format(tostring(reach), wide + 8))
	end
	restore()
end)

-- ------------------------------------------------------------------ 4
-- With one line the name line holds the outcome's headline, and its red and
-- its green are the built-in ones, not taken to the lettering's gold.
local function oneLineRibbon(ns, scenario)
	dress(ns, scenario, "ribbon", function(p) p.showSub = false end)
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	local look = r.look
	if not (look and look.fade and look.Fitted) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	if r.sub:IsShown() then fail(scenario, "SKIPPED -- the reason line is up with it switched off") return end
	Mock.advance(3)
	FT.settle()
	return r, look
end

-- The verdict's ink as the line holds it: the first colour code. Prompt's own
-- care for a legible line may pale it; the hue is what is asked about: a red
-- has as much green as blue, a green as much red as blue, and the lettering's
-- gold, mixed in, leaves neither so.
local function verdictInk(text)
	local r, g, b = text:match("^|c%x%x(%x%x)(%x%x)(%x%x)")
	if not r then return nil end
	return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local function keeps(kind, text)
	local r, g, b = verdictInk(text)
	if not r then return false end
	if kind == "failed" then return r - g > 0.1 and math.abs(g - b) < 0.06 end
	return g - r > 0.1 and math.abs(r - b) < 0.06
end

for _, case in ipairs({
	{ "failed", "ff8080", "a refusal's red", "Out of range" },
	{ "cast", "8ce88c", "a landing's green" },
}) do
	local kind, hex, what, detail = case[1], case[2], case[3], case[4]
	withTree("looks-redrawn-review2: Ribbon's one-line headline keeps " .. what, ANNA, function(ns, scenario)
		local r, look = oneLineRibbon(ns, scenario)
		if not r then return end
		ns.Prompt:ShowOutcome(kind, "Anna Aim", detail)
		local text = tostring(r.name:GetText())
		if not text:find("Anna", 1, true) then
			fail(scenario, "SKIPPED -- the headline is not on the name line: " .. text:gsub("|", "||"))
			return
		end
		if not keeps(kind, text) then
			fail(scenario, ("the headline on the name line has lost %s (|cff%s) to the gold: %s"):format(what, hex,
				(text:gsub("|", "||"))))
		end
		-- A scan under the verdict writes the person and then the headline
		-- again; a refit leaves it.
		Mock.advance(0.3)
		tick(ns)
		look:Fitted(r.name)
		text = tostring(r.name:GetText())
		if ns.Prompt:OutcomeLive() and not keeps(kind, text) then
			fail(scenario, ("a scan later the headline has lost %s (|cff%s) to the gold: %s"):format(what, hex,
				(text:gsub("|", "||"))))
		end
	end)
end

-- The class colour of a name is still taken to the gold, before and after.
withTree("looks-redrawn-review2: Ribbon still takes a class colour to the gold after a headline", ANNA, function(ns, scenario)
	local r, look = oneLineRibbon(ns, scenario)
	if not r then return end
	local kit = ns.Prompt:LookKit()
	local raw = "|cffff0000Anna|r"
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	tick(ns)
	kit.SetLine(kit.name, raw)
	local text = tostring(r.name:GetText())
	if text:lower():find("|cffff0000", 1, true) then
		fail(scenario, "after a headline a coloured name is no longer taken to the gold")
	end
end)

-- ------------------------------------------------------------------ 5
-- The cloth's fade is for a prompt coming up from nothing: the first part of
-- the entrance, not the settle after it.
local function ribbonRising(ns, scenario, after)
	dress(ns, scenario, "ribbon")
	local button = ns.Prompt:GetButton()
	if not down(ns) then fail(scenario, "SKIPPED -- the prompt is up with nobody about") return end
	-- A passer-by brings the prompt up: the entrance begins.
	about(ns, ANNA)
	ns.addon:Tick()
	local r = ns.Prompt:Regions()
	local look = r.look
	if not (look and look.fade and look.slide) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	if not (button:IsShown() and r.art.intro and r.art.intro._playing) then
		fail(scenario, "SKIPPED -- a passer-by did not bring the prompt up with its entrance")
		return
	end
	local length = FT.groupLength(r.art.intro)
	if not (after < length) then fail(scenario, "SKIPPED -- the entrance is over before the favour: " .. length) return end
	local before = plays(look.fade)
	local calls, unwatch = watch(look)
	Mock.advance(after)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	unwatch()
	if not sawNew(calls) then fail(scenario, "SKIPPED -- the favour was not news to the prompt") return end
	if not r.art.intro._playing then fail(scenario, "SKIPPED -- the entrance was ended by the favour") return end
	return look, plays(look.fade) - before
end

withTree("looks-redrawn-review2: Ribbon's cloth is not faded in from nothing in the entrance's settle", ANNA, function(ns, scenario)
	local look, faded = ribbonRising(ns, scenario, 0.28)
	if not look then return end
	if faded > 0 then
		fail(scenario, "a favour in the settle of the entrance, the panel at its full strength: the cloth is faded in from nothing")
	end
	if not anyPlaying(look.slide) then fail(scenario, "the cloth does not slide out for the favour") end
end)

withTree("looks-redrawn-review2: Ribbon's cloth still fades in while the entrance fades the panel in", ANNA, function(ns, scenario)
	local look, faded = ribbonRising(ns, scenario, 0.1)
	if not look then return end
	if faded == 0 then fail(scenario, "a favour while the panel is fading in: the cloth no longer fades in with it") end
end)

-- ------------------------------------------------------------------ 6
-- Every card's description is whole at the window's smallest size, in every
-- language: the row is as tall as its tallest card.
for _, locale in ipairs({ "enUS", "deDE", "frFR", "esES", "ptBR", "itIT", "koKR", "zhCN", "zhTW" }) do
	local scenario = "looks-redrawn-review2: every card's description is whole at the window's smallest (" .. locale .. ")"
	Mock.reset()
	Mock.locale = locale
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions("appearance", true)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards and UI.RowShown("appearance.style")) then
			fail(scenario, "SKIPPED -- the gallery is not on the Look page")
			return
		end
		local seen, longest = 0, 0
		for i = 1, #row.cards do
			local card = row.cards[i]
			if card:IsShown() then
				seen = seen + 1
				local lines, cut = FT.textLines(card.desc)
				longest = math.max(longest, #lines)
				if cut then
					fail(scenario, ("the %s card's description is cut off after %d lines of %.0f wide: %s"):format(
						tostring(card.key), #lines, FT.boundWidth(card.desc) or 0, tostring(card.desc:GetText())))
				end
				-- And the card is tall enough to hold what it draws.
				local _, descTop = FT.span(card.desc, "y")
				local cardBottom = FT.span(card, "y")
				if descTop and cardBottom and descTop - FT.textHeight(card.desc) < cardBottom - 0.5 then
					fail(scenario, ("the %s card's description runs out of the card's foot"):format(tostring(card.key)))
				end
			end
		end
		if seen < 10 then fail(scenario, "SKIPPED -- only " .. seen .. " cards are on the page") end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
