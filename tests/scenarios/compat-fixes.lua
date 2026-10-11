-- What the compat hunt (the five clients, against Blizzard's own UI source)
-- found and fixed: the prompt's macro run by mouse clicks it was meant to ignore.
--
-- Each was a probe first, red against the code it describes. Every scenario
-- name starts with "compat-fix:" so the mutations in
-- tests/mutations/compat-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- ------------------------------------------------------------------ the other buttons
-- The prompt is a SecureActionButtonTemplate registered for "AnyDown", pressed
-- by the left button and by a key binding, and by nothing else: the right
-- button skips it (and with shift, lists the person as never), and PreClick
-- and PostClick return early for any button but the left, so a macro run by
-- another click is a cast nobody recorded.
--
-- The attribute the client reads for a click is frame:GetAttribute(prefix,
-- name, suffix) (SecureButton_GetModifiedAttribute, Blizzard_FrameXML/
-- SecureTemplates.lua), the prefix being "shift-", "ctrl-", "alt-" or their mix
-- while those keys are down, the suffix the button's number: 1, 2, 3, then
-- 4 to 31 for Button4 to Button31 (BUTTON_LOOKUP_TABLE). It tries
-- prefix..name..suffix, "*"..name..suffix, prefix..name.."*", "*"..name.."*"
-- and the bare name (warcraft.wiki.gg, API_Frame_GetAttribute). A bare "type2"
-- is therefore the unmodified right button alone: with shift down the lookup
-- skips it and finds the bare "type", the macro that key binds need, and
-- shift-right-click, the never-offer gesture, cast on the person it should
-- have listed. SilenceOtherButtons sets "*type<N>" for the same reason
-- Blizzard's own SecureUnitButton_OnLoad sets "*type2".
--
-- This models the client's lookup, not the client: the mock has no secure
-- handler. Run on every client; the template and the lookup are the same on all.

-- frame:GetAttribute(prefix, name, suffix), in the order the client searches.
local function lookup(frame, prefix, name, suffix)
	local a = frame.attributes
	for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix,
		prefix .. name .. "*", "*" .. name .. "*", name }) do
		if a[key] ~= nil then return a[key] end
	end
	return nil
end

-- SecureButton_GetButtonSuffix.
local function suffix(button)
	if button == "LeftButton" then return "1" end
	if button == "RightButton" then return "2" end
	if button == "MiddleButton" then return "3" end
	local n = tonumber(button:match("^Button(%d+)$") or "")
	if n and n >= 4 and n <= 31 then return tostring(n) end
	return "-" .. button
end

-- What a click with `button` and the modifiers in `prefix` runs: the macro's
-- text, or nil for a type the handler has no action for (the "none" the prompt
-- sets, or nothing at all).
local function runs(frame, button, prefix)
	if lookup(frame, prefix, "type", suffix(button)) ~= "macro" then return nil end
	return lookup(frame, prefix, "macrotext", suffix(button))
end

-- SecureButton_GetModifierPrefix: alt, then ctrl, then shift.
local PREFIXES = { "", "shift-", "ctrl-", "ctrl-shift-", "alt-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }

local OTHERS = { "RightButton", "MiddleButton" }
for n = 4, 31 do OTHERS[#OTHERS + 1] = "Button" .. n end

-- The left button runs the macro whatever is held (a key binding with shift,
-- ctrl or alt in it needs that), and none of the others runs it in any of the
-- eight modifier states. Reports every shape that is wrong, in one failure.
local function judge(scenario, button, what)
	local missing, running = {}, {}
	for _, prefix in ipairs(PREFIXES) do
		if not runs(button, "LeftButton", prefix) then missing[#missing + 1] = prefix .. "LeftButton" end
		for _, name in ipairs(OTHERS) do
			if runs(button, name, prefix) then running[#running + 1] = prefix .. name end
		end
	end
	if #missing > 0 then
		fail(scenario, what .. ": the left button no longer runs the macro as " .. table.concat(missing, ", "))
	end
	if #running > 0 then
		fail(scenario, ("%s: %d of %d other click shapes run the macro, among them %s; PreClick and"
			.. " PostClick file nothing for them, so a shift-right-click casts on the person it was meant to"
			.. " list as never"):format(what, #running, #OTHERS * #PREFIXES,
			table.concat(running, ", ", 1, math.min(#running, 4))))
	end
end

-- One session on `flavour` with Anna owed a favour and standing by: body gets
-- the loaded addon and the prompt's button, and nothing in it outlives it.
local function session(scenario, flavour, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		body(ns, ns.Prompt:GetButton())
		ns.tryMacro = nil
	end)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
	local scenario = "compat-fix: only the left mouse button runs the prompt's macro (" .. flavour .. ")"
	session(scenario, flavour, function(ns, button)
		local armed = button:GetAttribute("macrotext1")
		if not (armed and armed:find("/target ", 1, true)) then
			fail(scenario, "SKIPPED -- nobody was armed: " .. tostring(armed))
			return
		end
		judge(scenario, button, "armed")

		-- Disarmed, nothing runs for any button; armed again, the silence is
		-- back whatever the disarm cleared.
		local entry = ns.Prompt.state.current
		ns.Prompt:ApplyTarget(nil)
		for _, prefix in ipairs(PREFIXES) do
			for _, name in ipairs({ "LeftButton", unpack(OTHERS) }) do
				if runs(button, name, prefix) then
					fail(scenario, "a disarmed prompt still runs a macro for " .. prefix .. name)
					break
				end
			end
		end
		if not entry then
			fail(scenario, "SKIPPED -- no entry to arm again")
			return
		end
		ns.Prompt:ApplyTarget(entry)
		if not button:GetAttribute("macrotext1") then
			fail(scenario, "SKIPPED -- the prompt did not arm again")
		else
			judge(scenario, button, "armed again")
		end
	end)

	-- /manners try writes the same type/macrotext pair from its own branch;
	-- the button is wiped first, so only that branch can have silenced it.
	scenario = "compat-fix: a /manners try macro is run by the left button only (" .. flavour .. ")"
	session(scenario, flavour, function(ns, button)
		local entry = ns.Prompt.state.current
		for key in pairs(button.attributes) do button.attributes[key] = nil end
		ns.tryMacro = "/say hello"
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		if button:GetAttribute("macrotext1") ~= "/say hello" then
			fail(scenario, "SKIPPED -- /manners try did not arm: " .. tostring(button:GetAttribute("macrotext1")))
			return
		end
		judge(scenario, button, "armed by /manners try")
	end)
end
