-- Round 20's options fixes: a settings string, and an import's undo, when a
-- text setting holds a carriage return or another control character; a string
-- 1.6.1 wrote with one; and a place for the options window, in the saved file,
-- that SetPoint cannot take.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "hunt20-options:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function said()
	return table.concat(Mock.printed, "\n")
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Commands.lua's checksum, so a scenario can write a string of its own.
local function checksum(text)
	local h = 0
	for i = 1, #text do h = (h * 31 + text:byte(i)) % 16777213 end
	return ("%06x"):format(h)
end

local function signed(body)
	local head = "MNR1:" .. body
	return head .. ":" .. checksum(head)
end

-- One session after the lifecycle has run, everything put back.
local function session(scenario, body)
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		Mock.printed = {}
		body(ns, ns.db.profile)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The phrase box as a saved file can hold it: a \r or \13 escape in the
-- string. Speech.lua splits it into lines on CR and LF alike, and the load-time
-- repair only refills a blank box, so it is kept as it is.
local LINES = "Cheers {name}!\nThanks, {name}."
local BOXES = {
	{ label = "CRLF", text = "Cheers {name}!\r\nThanks, {name}." },
	{ label = "a lone CR", text = "Cheers {name}!\rThanks, {name}." },
	{ label = "a bell", text = "Cheers {name}!\7\nThanks, {name}." },
}

-- ------------------------------------------------------------------ own export
-- EncodeText wrote any byte as %XX and DecodeText refused every control byte
-- but LF and tab, so a CR in the phrase box made the player's own export a
-- string that "gives speech.phrases a value it cannot have".
for _, case in ipairs(BOXES) do
	local scenario = "hunt20-options: a phrase box holding " .. case.label .. " exports as a string that reads back"
	session(scenario, function(ns, p)
		p.speech.phrases = case.text
		p.prompt.width = 260
		local export = ns.ExportSettings()
		local parsed, why = ns.ParseSettings(export)
		if not parsed then
			fail(scenario, "your own export cannot be imported back: " .. tostring(why) .. " -- " .. tostring(export))
			return
		end
		local back = parsed.values["speech.phrases"]
		if back ~= LINES then
			fail(scenario, ("the phrase box reads back as %q"):format(tostring(back)))
		end
		p.speech.phrases = "Something else."
		p.prompt.width = 300
		local ok, message = ns.ImportSettings(export)
		if not ok then
			fail(scenario, "importing your own export was refused: " .. tostring(message))
		elseif p.speech.phrases ~= LINES or p.prompt.width ~= 260 then
			fail(scenario, ("importing your own export gave width %s and the lines %q")
				:format(tostring(p.prompt.width), tostring(p.speech.phrases)))
		end
	end)
end

-- ------------------------------------------------------------------ the undo
-- The undo was the profile written out as a settings string, first read back
-- when the player typed /manners import undo, after the import had written
-- over everything: with a CR in the phrase box it could not be read, the
-- stranger's look stayed, and the typed lines were gone for the Roleplay set.
for _, case in ipairs(BOXES) do
	local scenario = "hunt20-options: an import's undo puts back a phrase box holding " .. case.label
	session(scenario, function(ns, p)
		p.speech.phrases = case.text
		p.prompt.width = 260
		p.prompt.style = "framed"
		local ok, message = ns.ImportSettings(signed("prompt.width=400;prompt.style=toast"))
		if not ok or p.prompt.width ~= 400 then
			fail(scenario, "SKIPPED -- the stranger's string did not apply: " .. tostring(message))
			return
		end
		Mock.printed = {}
		ns.addon:HandleSlash("import undo")
		if p.prompt.width ~= 260 or p.prompt.style ~= "framed" then
			fail(scenario, ("/manners import undo left the imported look (width %s, %s): %s")
				:format(tostring(p.prompt.width), tostring(p.prompt.style), said()))
		end
		if p.speech.phrases ~= case.text then
			fail(scenario, ("/manners import undo did not put the phrase box back: %q")
				:format(tostring(p.speech.phrases)))
		end
		if not said():find("are back", 1, true) then
			fail(scenario, "/manners import undo said: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ 1.6.1's strings
-- Up to 1.6.1 an export wrote such a box's CRs as %0D. The player's own string
-- from then reads now, with the CRs as line breaks; a control byte other than
-- a line break or a tab is still refused (ease.lua: "a control character").
do
	local scenario = "hunt20-options: a string 1.6.1 wrote with a CR in the phrase box reads"
	session(scenario, function(ns, p)
		for _, body in ipairs({
			"speech.phrases=Cheers+{name}!%0D%0AThanks%2C+{name}.",
			"speech.phrases=Cheers+{name}!%0DThanks%2C+{name}.",
		}) do
			p.speech.phrases = "Something else."
			local ok, message = ns.ImportSettings(signed("prompt.width=260;" .. body))
			if not ok then
				fail(scenario, body .. " was refused: " .. tostring(message))
			elseif p.speech.phrases ~= LINES then
				fail(scenario, ("%s gave the lines %q"):format(body, tostring(p.speech.phrases)))
			end
		end
	end)
end

-- ------------------------------------------------------------------ the window's place
-- Place() handed whatever the saved file held to SetPoint. The client takes
-- only the nine anchors and throws on any other name, so UI.Build threw,
-- OpenOptions fell back to the old dialog, and nothing rewrote the place: the
-- window never opened again on that account. An offset no screen has, or not
-- a number at all, is put back to the centre too, as the ledger window does.
local ANCHORS = {
	CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

-- A frame whose SetPoint refuses what the client refuses.
local function strict(f)
	local setPoint = f.SetPoint
	f.SetPoint = function(self, point, ...)
		if not ANCHORS[point] then error("SetPoint(): Invalid region point " .. tostring(point), 2) end
		local relPoint = select(2, ...)
		if select("#", ...) >= 2 and type(relPoint) == "string" and not ANCHORS[relPoint] then
			error("SetPoint(): Invalid region point " .. relPoint, 2)
		end
		return setPoint(self, point, ...)
	end
	return f
end

for _, case in ipairs({
	{ label = "anchors the game does not know", window = { point = "FOO", relPoint = "BAR", x = 10, y = 20 } },
	{ label = "a relative anchor the game does not know",
		window = { point = "TOPLEFT", relPoint = "BAR", x = 10, y = 20 } },
	{ label = "an offset no screen has", window = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 1e300, y = 20 } },
	{ label = "an offset that is not a number", window = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 0 / 0, y = 20 } },
	{ label = "a place it can take", window = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 100, y = -50 },
		keep = true },
	{ label = "a place without its relative anchor", window = { point = "TOPLEFT", x = 100, y = -50 },
		keep = true },
}) do
	local scenario = "hunt20-options: the options window opens with " .. case.label .. " saved"
	Mock.reset()
	local saved = rawget(_G, "CreateFrame")
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if ns.WindowUI.frame then
			fail(scenario, "SKIPPED -- the window was built before it was opened")
			return
		end
		-- The saved file, as the next login reads it.
		local s = ns.WindowUI.State()
		for key, value in pairs(case.window) do s[key] = value end
		CreateFrame = function(...) return strict(saved(...)) end
		ns.OpenOptions("general")
		ns.Prompt:ExitTest()
		local f = ns.OptionsWindow
		if not (f and f:IsShown() and ns.WindowUI.frame == f) then
			fail(scenario, "the options window did not open")
		end
		noErrors(scenario, ns)
		local point = f and f.points[#f.points]
		if case.keep then
			if not (point and point[1] == "TOPLEFT" and point[3] == "TOPLEFT" and point[4] == 100 and point[5] == -50) then
				fail(scenario, "the window is not where it was left: " .. tostring(point and point[1]))
			end
			if s.point ~= "TOPLEFT" then fail(scenario, "the place it was left was forgotten") end
		else
			if not (point and point[1] == "CENTER" and point[3] == "CENTER" and point[4] == 0 and point[5] == 0) then
				fail(scenario, ("the window was put at %s %s %s %s"):format(tostring(point and point[1]),
					tostring(point and point[3]), tostring(point and point[4]), tostring(point and point[5])))
			end
			if s.point ~= nil or s.relPoint ~= nil or s.x ~= nil or s.y ~= nil then
				fail(scenario, "the place SetPoint cannot take is still saved, for the next login to meet")
			end
		end
	end)
	rawset(_G, "CreateFrame", saved)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
