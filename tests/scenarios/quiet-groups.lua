-- Say nothing in a party, Say nothing in a raid (What I say; speech.quietInParty,
-- speech.quietInRaid; Speech.lua, ns.GroupQuiet, read by ns.ChannelOpen).
-- Asked for by the author: "need a way to turn off the rp text when in a raid /
-- group". While you are in a party (a group that is no raid), or in a raid, with
-- that switch on, no spoken line is armed with a cast, to a member or a
-- passer-by; the cast itself is armed as before, and the bar macro's copy agrees.
--
-- Every scenario name starts with "quiet-groups:" so the mutations in
-- tests/mutations/quiet-groups.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local MUNIN = "Munin Hugins"

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function speaks(text)
	return text ~= nil and text:find("\n/say ", 1, true) ~= nil
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- The macro's lines with the spoken one taken out: the cast, as armed.
local function castOnly(text)
	if type(text) ~= "string" then return nil end
	local out = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		if not line:find("^/say ") then out[#out + 1] = line end
	end
	return table.concat(out, "\n")
end

-- The group as the client tells it: "solo", "party" (two of you) or "raid".
local function group(kind)
	if kind == "raid" then
		Mock.groupSize, Mock.raid = 2, { size = 2, player = 1 }
	elseif kind == "party" then
		Mock.groupSize, Mock.raid = 2, nil
	else
		Mock.groupSize, Mock.raid = 0, nil
	end
end

-- A session with Munin owed a favour and a line that always fits: on a
-- nameplate (a passer-by) or, with `member`, on party1. `kind` is the group.
local function session(scenario, member, kind)
	Mock.reset()
	local units = member and { party1 = { "Munin", "Hugins" } } or { nameplate1 = { "Munin", "Hugins" } }
	local restore = H.strangers(units)
	group(kind)
	local ns = load(scenario)
	if not ns then
		restore()
		group("solo")
		return nil
	end
	H.freshPrompt(ns, scenario)
	group(kind)
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "SAY"
	speech.phrases = "Thanks, {name}."
	speech.quietInParty, speech.quietInRaid = false, false
	H.owe(ns, MUNIN)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, function()
		restore()
		group("solo")
	end
end

-- The macro armed at Munin under the switches given, after a repaint.
local function armedWith(ns, party, raid)
	local speech = ns.db.profile.speech
	speech.quietInParty, speech.quietInRaid = party, raid
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	local text = macro(ns)
	if not (text and text:find(MUNIN, 1, true)) then return nil end
	return text
end

-- One case: the switches, the line wanted, and the cast lines the same as with
-- both switches off.
local function judge(scenario, ns, label, party, raid, want)
	local loud = armedWith(ns, false, false)
	local text = armedWith(ns, party, raid)
	if not (loud and text) then
		fail(scenario, "SKIPPED -- Munin is not armed (" .. label .. "): " .. flat(text or loud))
		return
	end
	if not speaks(loud) then
		fail(scenario, "SKIPPED -- no line with both switches off (" .. label .. "): " .. flat(loud))
		return
	end
	if speaks(text) ~= want then
		fail(scenario, ("%s: the macro %s a spoken line: %s"):format(label, want and "lost" or "kept", flat(text)))
	end
	if castOnly(text) ~= castOnly(loud) then
		fail(scenario, ("%s: the cast lines changed: %s against %s"):format(label, flat(text), flat(loud)))
	end
	-- The tooltip quotes what the press will say, and only that.
	local entry = ns.Prompt.state.current
	local quoted = entry and table.concat(ns.Prompt:ClickSummary(entry), " / ") or ""
	if (quoted:find("Says:", 1, true) ~= nil) ~= want then
		fail(scenario, ("%s: the tooltip %s a line"):format(label, want and "leaves out" or "quotes"))
	end
end

-- ------------------------------------------------------------ quiet-groups 1
-- In a party, to a member: quiet with Say nothing in a party, speaking with
-- only Say nothing in a raid.
do
	local scenario = "quiet-groups: a party member hears no line with Say nothing in a party"
	local ns, restore = session(scenario, true, "party")
	if ns then
		judge(scenario, ns, "party, member, party switch", true, false, false)
		guarded(scenario, ns)
		restore()
	end
end

do
	local scenario = "quiet-groups: Say nothing in a raid leaves a party speaking"
	local ns, restore = session(scenario, true, "party")
	if ns then
		judge(scenario, ns, "party, member, raid switch", false, true, true)
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ quiet-groups 2
-- In a party, to a passer-by: quiet too.
do
	local scenario = "quiet-groups: a passer-by hears no line while you are in a quiet party"
	local ns, restore = session(scenario, false, "party")
	if ns then
		judge(scenario, ns, "party, passer-by, party switch", true, false, false)
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ quiet-groups 3
-- In a raid: quiet with Say nothing in a raid; Say nothing in a party alone
-- leaves a raid speaking.
do
	local scenario = "quiet-groups: no line in a raid with Say nothing in a raid"
	local ns, restore = session(scenario, false, "raid")
	if ns then
		judge(scenario, ns, "raid, passer-by, raid switch", false, true, false)
		guarded(scenario, ns)
		restore()
	end
end

do
	local scenario = "quiet-groups: Say nothing in a party leaves a raid speaking"
	local ns, restore = session(scenario, false, "raid")
	if ns then
		judge(scenario, ns, "raid, passer-by, party switch", true, false, true)
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ quiet-groups 4
-- Solo, both switches on: the line, as ever.
do
	local scenario = "quiet-groups: solo, both switches leave the line"
	local ns, restore = session(scenario, false, "solo")
	if ns then
		judge(scenario, ns, "solo, both switches", true, true, true)
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ quiet-groups 5
-- A group formed and then left: the line goes at the next repaint and comes
-- back at the one after the group ends, with no setting touched.
do
	local scenario = "quiet-groups: the line follows a group formed and left"
	local ns, restore = session(scenario, false, "solo")
	if ns then
		local speech = ns.db.profile.speech
		speech.quietInParty, speech.quietInRaid = true, true
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local steps = {
			{ "solo", "solo", true },
			{ "a party formed", "party", false },
			{ "the party made a raid", "raid", false },
			{ "the group left", "solo", true },
		}
		for _, step in ipairs(steps) do
			local label, kind, want = step[1], step[2], step[3]
			group(kind)
			Mock.advance(1)
			ns.addon:Tick()
			local text = macro(ns)
			if not (text and text:find(MUNIN, 1, true)) then
				fail(scenario, "SKIPPED -- Munin is not armed (" .. label .. "): " .. flat(text))
			elseif speaks(text) ~= want then
				fail(scenario, ("%s: the macro %s the line at the next repaint: %s"):format(label,
					want and "did not get back" or "kept", flat(text)))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ quiet-groups 6
-- The bar macro's copy (Clicks.lua, click macro) carries no line while the
-- prompt's has none, and the line again once the group is left.
do
	local scenario = "quiet-groups: the bar macro agrees with the prompt"
	local ns, restore = session(scenario, false, "party")
	if ns then
		ns.CreateClickMacro()
		local function body()
			local index = GetMacroIndexByName("Manners")
			local m = index and Mock.macroList[index]
			return m and m.body or nil
		end
		-- The line rolled solo first, then the party formed with nothing else
		-- touched: the line kept from that roll must not ride on the bar.
		ns.db.profile.speech.quietInParty = true
		ns.Prompt:InvalidateMacro()
		for _, case in ipairs({ { "solo", "solo", true, true }, { "quiet party", "party", true, false },
			{ "solo again", "solo", true, true }, { "party, switch off", "party", false, true } }) do
			local label, kind, quiet, want = case[1], case[2], case[3], case[4]
			group(kind)
			if ns.db.profile.speech.quietInParty ~= quiet then
				ns.db.profile.speech.quietInParty = quiet
				ns.Prompt:InvalidateMacro()
			end
			Mock.advance(1)
			ns.addon:Tick()
			local text, bar = macro(ns), body()
			if not (bar and bar:find(MUNIN, 1, true)) then
				fail(scenario, "SKIPPED -- the bar macro is not written for Munin (" .. label .. "): " .. flat(bar))
			elseif speaks(text) ~= want then
				fail(scenario, ("%s: the prompt's macro %s the line: %s"):format(label, want and "lost" or "kept", flat(text)))
			elseif speaks(bar) ~= want then
				fail(scenario, ("%s: the bar macro %s the line the prompt %s: %s"):format(label,
					want and "lost" or "kept", want and "has" or "leaves out", flat(bar)))
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ quiet-groups 7
-- The two switches on the What I say page, under Say a line, indented, on the
-- short list, and named to search with the switch to turn on; off by default,
-- and a damaged value put back.
do
	local scenario = "quiet-groups: the switches sit under Say a line, off by default"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local defaults = ns.defaults.profile.speech
		for _, key in ipairs({ "quietInParty", "quietInRaid" }) do
			if defaults[key] ~= false then fail(scenario, key .. " is not off by default") end
			ns.db.profile.speech[key] = "yes"
		end
		ns.ClampSettings()
		for _, key in ipairs({ "quietInParty", "quietInRaid" }) do
			if ns.db.profile.speech[key] ~= false then
				fail(scenario, key .. " kept a damaged value: " .. tostring(ns.db.profile.speech[key]))
			end
		end
		local layout = ns.WindowLayout
		if type(layout) == "table" and H.layoutInToc() then
			local list, sections = H.pagePaths(ns, "click")
			local at = {}
			for i, path in ipairs(list or {}) do at[path] = i end
			for _, path in ipairs({ "click.quietInParty", "click.quietInRaid" }) do
				local page, section, index = H.placedOn(ns, path)
				if page ~= "click" then
					fail(scenario, path .. " is not on What I say")
				else
					local item = section.items[index]
					if not (type(item) == "table" and item.indent == true) then
						fail(scenario, path .. " is not indented")
					end
					if sections[path] ~= sections["click.enabled"] or not (at[path] > at["click.enabled"]) then
						fail(scenario, path .. " is not under Say a line when I buff someone")
					end
				end
				if not (layout.simple and layout.simple.items[path]) then
					fail(scenario, path .. " is left out of the short list")
				end
				if not (layout.parents and layout.parents[path] == "click.enabled") then
					fail(scenario, path .. " does not name Say a line to search")
				end
			end
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------ quiet-groups 8
-- A pasted settings string can make you quieter, never louder: it may switch
-- either on, and never switches one off that you have on.
do
	local scenario = "quiet-groups: a pasted string can only make you quieter"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		for _, speaking in ipairs({ true, false }) do
			speech.enabled = speaking
			speech.quietInParty, speech.quietInRaid = true, false
			local text = ns.ExportSettings()
			speech.quietInParty, speech.quietInRaid = false, true
			local ok, said = ns.ImportSettings(text)
			speech = ns.db.profile.speech
			if not ok then
				fail(scenario, "SKIPPED -- the string did not import: " .. tostring(said))
			else
				local label = speaking and "speaking" or "not speaking"
				if speech.quietInParty ~= true then
					fail(scenario, label .. ": a pasted Say nothing in a party did not travel")
				end
				if speech.quietInRaid ~= true then
					fail(scenario, label .. ": a pasted string switched off Say nothing in a raid")
				end
			end
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------ quiet-groups 9
-- What stays as it was: the whispered thank-you goes in a quiet party, and
-- /manners debug says why no line goes out.
do
	local scenario = "quiet-groups: the thank-you whisper still goes, and debug says why no line"
	local ns, restore = session(scenario, true, "party")
	if ns then
		ns.db.profile.speech.quietInParty = true
		ns.db.profile.speech.quietInRaid = true
		-- The chat call, caught: the mock client has none.
		local sent, real = {}, rawget(_G, "SendChatMessage")
		rawset(_G, "SendChatMessage", function(text, kind, _, to)
			sent[#sent + 1] = { text = text, kind = kind, to = to }
		end)
		local whispered = ns.ThankWhisper({ name = MUNIN, inGroup = true }, "party1")
		rawset(_G, "SendChatMessage", real)
		if whispered ~= true or #sent ~= 1 or sent[1].kind ~= "WHISPER" then
			fail(scenario, "the whispered thank-you did not go in a quiet party")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not said:find("no line goes out when you buff", 1, true) then
			fail(scenario, "/manners debug does not say the party keeps the line out")
		end
		group("solo")
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		said = table.concat(Mock.printed, "\n")
		if said:find("no line goes out when you buff", 1, true) then
			fail(scenario, "/manners debug names a quiet group while solo")
		end
		guarded(scenario, ns)
		restore()
	end
end
