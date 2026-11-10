-- The box of many lines (What I say > Your lines) keeps what was typed when the
-- player leaves it. A player wrote their own lines, closed the window, and found
-- them gone: the box committed on Accept alone, and closing the window takes the
-- focus without pressing it. Leaving a one-line box has always committed; this
-- box now does too (Options/Window/WidgetsEntry.lua, MultiLeft). Accept still
-- commits at once, a box that is only for typing into (the paste box) waits for
-- it, and Escape puts the text back.
--
-- Every scenario name starts with "linesbox:" so the mutations in
-- tests/mutations/linesbox.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function session(scenario)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local ctx = { changes = {}, holds = {}, pages = {}, relayouts = 0 }
	ctx.Window = CreateFrame("Frame", "MannersOptionsTest", UIParent)
	ctx.Window:SetSize(820, 600)
	ctx.OnChange = function(item) ctx.changes[#ctx.changes + 1] = item.path end
	ctx.OnHold = function(on) ctx.holds[#ctx.holds + 1] = on end
	ctx.ScrollPage = function(delta) ctx.pages[#ctx.pages + 1] = delta end
	ctx.Relayout = function(row) ctx.relayouts = ctx.relayouts + 1 row:Layout(row.width) end
	return ns, ctx
end

local function build(scenario, ns, ctx, kind, path)
	local item = ns.WindowBind.Item(path, {}, ctx)
	if not item then
		fail(scenario, "SKIPPED -- the model has no " .. path)
		return nil
	end
	local row = ns.WindowWidgets.Build(kind, ctx.Window, item)
	row:Layout(560)
	return row
end

local function run(scenario, body)
	local ok, err = pcall(body, scenario)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	Mock.reset()
end

local MINE = "Thank you, {name}.\nMuch obliged."

run("linesbox: leaving the box keeps the lines typed", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "multiline", "click.phrases")
	if row then
		local SP = ns.db.profile.speech
		SP.presetChoice = "polite"
		SP.phrases = ns.PhraseSetText("polite")
		row:Refresh()
		Mock.type(row.box, MINE)
		if SP.phrases == MINE then fail(scenario, "typing committed before the box was left") end
		row.box:ClearFocus()
		if SP.phrases ~= MINE then
			fail(scenario, "leaving the box threw the lines away: " .. tostring(SP.phrases))
		end
		if row.accept:IsEnabled() then fail(scenario, "Accept stays lit after the lines were kept") end
	end
end)

run("linesbox: Escape puts the lines back", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "multiline", "click.phrases")
	if row then
		local SP = ns.db.profile.speech
		SP.presetChoice = "polite"
		SP.phrases = ns.PhraseSetText("polite")
		local before = SP.phrases
		row:Refresh()
		Mock.type(row.box, MINE)
		Mock.press(row.box, "ESCAPE")
		if SP.phrases ~= before then fail(scenario, "Escape kept the lines typed: " .. tostring(SP.phrases)) end
		if row.box:GetText() ~= before then fail(scenario, "Escape left the typed text in the box") end
	end
end)

run("linesbox: a box for typing into waits for Accept", function(scenario)
	local ns, ctx = session(scenario)
	local paste = ns and build(scenario, ns, ctx, "multiline", "profiles.sharePaste")
	if paste then
		Mock.type(paste.box, "not settings at all")
		paste.box:ClearFocus()
		for _, p in ipairs(ctx.changes) do
			if p == "profiles.sharePaste" then fail(scenario, "leaving the paste box applied what was in it") end
		end
		if paste.err:IsShown() then
			fail(scenario, "leaving the paste box tried its text: " .. tostring(paste.err:GetText()))
		end
		if paste.box:GetText() ~= "not settings at all" then
			fail(scenario, "leaving the paste box emptied it: " .. tostring(paste.box:GetText()))
		end
	end
end)
