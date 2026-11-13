-- Manners -- the prompt taken off the screen for a fight (Look, Hide the prompt
-- in combat), and nothing cast from it while it is off.
--
-- WHY NOT A VISIBILITY DRIVER ALONE
--
-- The prompt is a secure button, and in a fight an addon's Lua may neither hide
-- it nor change what it casts. A visibility driver ("[combat] hide; show")
-- would hide it, but a hidden secure button still fires from its key binding
-- (Bindings.xml, CLICK MannersPrompt:LeftButton) and from /click, casting the
-- macro the fight froze on it out of sight: the client's press path,
-- SecureActionButton_OnClick and PerformAction (Gethe/wow-ui-source,
-- Blizzard_FrameXML/SecureTemplates.lua, PerformAction at line 730 on forever,
-- 727 on classic_era), asks nothing about whether the button is shown. And the
-- Manners macro on a bar casts by its own lines under /click MannersBar
-- (Clicks.lua, click macro), which no driver can reach: MannersBar is a plain
-- button and holds nothing, and the lines are in the macro, which no addon may
-- edit in a fight.
--
-- WHAT DOES IT, ON ALL FIVE CLIENTS
--
-- A header of SecureHandlerStateTemplate with a state driver, "[combat] fight;
-- peace". Blizzard's SecureStateDriver.lua (the same file on forever, live,
-- classic, classic_anniversary and classic_era) evaluates it with
-- SecureCmdOptionParse every 0.2 s and at once after PLAYER_REGEN_DISABLED and
-- PLAYER_REGEN_ENABLED (lines 63, 119, 142, 193), and writes state-mannersfight
-- only when it changes (resolveDriver, line 113); the template's
-- OnAttributeChanged (SecureHandlerTemplates.xml line 13,
-- SecureHandler_StateOnAttributeChanged in SecureHandlers.lua line 107) runs
-- _onstate-mannersfight in the restricted environment, in combat too. There a
-- frame handle to a protected frame may SetAttribute and Hide
-- (RestrictedFrames.lua, GetPossiblyForbiddenHandleFrame line 79, HANDLE:Hide
-- line 402, HANDLE:SetAttribute line 522), so the snippet, as the fight
-- begins, takes type1, macrotext1, type and macrotext off the prompt and off
-- every list row (the "type" a press looks up is then nil, and PerformAction
-- does nothing), and only then hides the prompt, whose children the rows are.
-- Disarmed first: a snippet stopped half way leaves a prompt on screen that
-- casts nothing, never one off screen that casts.
--
-- The bar macro is emptied by Lua just before the lockdown, at
-- PLAYER_REGEN_DISABLED, as every pull already writes it (Clicks.lua, Wanted:
-- the bar line alone for a fight the prompt sits out). The prompt is hidden
-- only when the macro is then read back holding its first line alone, or there
-- is no such macro (ns.BarMacroDisarmed): a write deferred by a bar press in
-- that same frame, or refused, or a macro changed by hand, leaves the prompt
-- up for the fight, armed, as it would be with the setting off, and says so.
-- `manners-hide` on the header carries that verdict to the snippet.
--
-- AFTER THE FIGHT
--
-- The snippet writes nothing back, so nothing frozen at the pull can come back
-- with it. At PLAYER_REGEN_ENABLED, out of lockdown, the repaint arms the
-- prompt afresh for whoever it should name now (the key it was armed with at
-- the pull carried armedForFight, which is off again: Macro.lua, Arm), writes
-- the bar macro, and shows the panel where it should be shown, as any repaint
-- does. The header is put back to "peace" and its verdict to no, so the next
-- pull is seen whatever the driver last read, and a driver that reads
-- [combat] a moment late hides nothing outside a fight.

--
-- THE FIGHT'S ROTA (1.11.19)
--
-- With the prompt left up, a fight froze it on whoever it named as the fight
-- began: every press cast at that one person, buffed or not, and nobody else
-- in the group was reached until the fight ended, which in a dungeon is most
-- of the time. An addon's Lua cannot change what the button casts in a fight;
-- secure code can. So at the pull, still out of lockdown, the header is handed
-- the macro of everybody the queue then held (manners-rota-1..n, the one on
-- the button first), and the prompt's OnClick is wrapped
-- (SecureHandlerWrapScript: Blizzard's Wrapped_Click runs the pre-body, the
-- click itself, then the post-body when the pre-body gave it a message). The
-- post-body writes the next macro of the rota on the button, round and round:
-- each press in the fight casts at the next person. It reads nothing of the
-- game (a snippet can ask neither the cooldown nor anybody's buffs), so a
-- press the cooldown turned away still moves on, and the one passed over
-- comes round again.
--
-- Lua follows: PostClick (Press.lua) files the press on the person it was
-- armed at, as ever, and then SyncFightRota reads where the snippet has got to
-- and points `current` there, so the panel names who the next press is for.
-- Only a left press steps, as only a left press casts. Not with the prompt
-- hidden for the fight (its macro is off), nor from the Manners macro on a
-- bar, which casts by its own lines and holds the one the pull wrote.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local R = Prompt.regions
local S = Prompt.state
local lib = Prompt.lib
local InCombatLockdown = _G.InCombatLockdown

local GetTime = _G.GetTime

local STATE = "mannersfight"
local DRIVER = "[combat] fight; peace"

-- When a pull last said the prompt stays up, and how long before it says so
-- again.
local stayedSaidAt
local STAYED_REST = 300

-- Runs in the restricted environment: `self` is the header's handle, and
-- frame refs are handles. No upvalues, no globals but the environment's own.
local SNIPPET = [=[
	if newstate ~= "fight" then
		self:SetAttribute("manners-hidden", nil)
		return
	end
	if not self:GetAttribute("manners-hide") then return end
	local count = self:GetAttribute("manners-buttons") or 0
	for i = 1, count do
		local button = self:GetFrameRef("button" .. i)
		if button then
			button:SetAttribute("type1", nil)
			button:SetAttribute("macrotext1", nil)
			button:SetAttribute("type", nil)
			button:SetAttribute("macrotext", nil)
		end
	end
	local prompt = self:GetFrameRef("button1")
	if prompt then
		prompt:Hide(true)
		self:SetAttribute("manners-hidden", true)
	end
]=]

-- The rota's two halves, run round each click of the prompt in the restricted
-- environment: `self` is the prompt's handle, `control` the header's. The
-- first lets the second run for a left press with a rota of two or more; the
-- second steps the button to the rota's next macro.
local ROTA_PRE = [=[
	if button ~= "LeftButton" or down == false then return end
	if (control:GetAttribute("manners-rota-n") or 0) < 2 then return end
	return nil, "step"
]=]
local ROTA_POST = [=[
	local n = control:GetAttribute("manners-rota-n") or 0
	if n < 2 then return end
	local i = (control:GetAttribute("manners-rota-i") or 1) % n + 1
	control:SetAttribute("manners-rota-i", i)
	local text = control:GetAttribute("manners-rota-" .. i)
	self:SetAttribute("macrotext1", text)
	self:SetAttribute("macrotext", text)
]=]
-- The most a rota holds: the people a fight is likely to leave time for.
local ROTA_MAX = 12
Prompt.ROTA_MAX = ROTA_MAX

-- Made once, out of combat, after the prompt and its rows (Panel.lua, Create);
-- asked again at each end of a fight when a login or a /reload in one left it
-- unmade. A client without the secure handlers leaves the prompt as it was.
function Prompt:CreateFightHide()
	if R.fight or not R.button or InCombatLockdown() then return end
	if type(_G.RegisterStateDriver) ~= "function" then return end
	local ok, header = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
	if not ok or type(header) ~= "table" or type(header.SetFrameRef) ~= "function" then return end
	local buttons = { R.button }
	for _, button in ipairs(R.rowButtons or {}) do buttons[#buttons + 1] = button end
	for i, button in ipairs(buttons) do header:SetFrameRef("button" .. i, button) end
	header:SetAttribute("manners-buttons", #buttons)
	header:SetAttribute("manners-hide", false)
	header:SetAttribute("_onstate-" .. STATE, SNIPPET)
	_G.RegisterStateDriver(header, STATE, DRIVER)
	R.fight = header
	-- The rota's wrap round the prompt's click, where the client has one.
	header:SetAttribute("manners-rota-n", 0)
	header:SetAttribute("manners-rota-i", 1)
	if type(_G.SecureHandlerWrapScript) == "function" then
		header.rotaWrapped = pcall(_G.SecureHandlerWrapScript, R.button, "OnClick", header, ROTA_PRE, ROTA_POST) or nil
	end
end

-- Whether the fight about to start hides the prompt as far as Lua can tell
-- before it starts: the setting, and a header to do it. Clicks.lua's Wanted
-- asks it, so the pull writes the bar macro empty.
function Prompt:HidesForFight()
	local db = ns.db and ns.db.profile
	return R.fight ~= nil and db ~= nil and db.prompt.hideInFight == true
end

-- Whether the snippet has the prompt off the screen for the fight on now.
function Prompt:HiddenForFight()
	local header = R.fight
	return header ~= nil and InCombatLockdown() and header:GetAttribute("manners-hidden") == true
end

-- For tests and /manners selftest.
function Prompt:FightHeader() return R.fight end

-- PLAYER_REGEN_DISABLED, after the pull's repaint has armed the prompt and
-- ArmFightHide has given its verdict, still out of lockdown (Core.lua): the
-- rota for this fight, or none. The queue is what that repaint built
-- (Refresh.lua keeps it for this, S.fightQueue).
function Prompt:ArmFightRota()
	local header = R.fight
	if not header or InCombatLockdown() then return end
	header:SetAttribute("manners-rota-n", 0)
	header:SetAttribute("manners-rota-i", 1)
	S.rota = nil
	local db = ns.db and ns.db.profile
	if not (db and db.prompt.fightRota ~= false and header.rotaWrapped) then return end
	-- Nothing to step with the prompt off for the fight, with nobody on it, or
	-- in a preview.
	if header:GetAttribute("manners-hide") or S.testMode then return end
	local top, queue = S.current, S.fightQueue
	local armed = R.button:GetAttribute("macrotext1")
	if not (top and top.buff and type(armed) == "string" and armed ~= "" and type(queue) == "table") then return end
	-- The one on the button first, as armed, then the rest of the queue in its
	-- own order.
	local entries, records, texts = { top }, { S.armed or false }, { armed }
	for _, entry in ipairs(queue) do
		if #entries >= ROTA_MAX then break end
		if entry ~= top and entry.buff and not (entry.name == top.name and entry.buff.key == top.buff.key) then
			local text, record = lib.FightMacro(entry)
			if text then
				local at = #entries + 1
				entries[at], records[at], texts[at] = entry, record or false, text
			end
		end
	end
	if #entries < 2 then return end
	for i, text in ipairs(texts) do header:SetAttribute("manners-rota-" .. i, text) end
	header:SetAttribute("manners-rota-n", #entries)
	S.rota = { entries = entries, records = records, texts = texts, index = 1, steps = 0 }
	ns.Trail("fight", ("the rota for this fight holds %d"):format(#entries))
end

-- After a press in a fight (Press.lua, once its PostClick has filed the press
-- on the person it was armed at): where the snippet has stepped the button
-- to, taken as `current`, so the panel and the next press's bookkeeping name
-- who the button now casts at. Nothing with no rota, or no step.
function Prompt:SyncFightRota()
	local rota, header = S.rota, R.fight
	if not (rota and header and InCombatLockdown()) then return end
	local i = header:GetAttribute("manners-rota-i")
	if type(i) ~= "number" or i == rota.index or not rota.entries[i] then return end
	rota.index, rota.steps = i, rota.steps + 1
	local entry = rota.entries[i]
	S.current, S.frozenEntry, S.armed = entry, nil, rota.records[i] or nil
	ns.lastMacro, ns.lastTopEntry, ns.lastTopUnit = rota.texts[i], entry, entry.unit
	local p = ns.db.profile.prompt
	if p.showIcon and R.icon and lib.EntryIcon then R.icon:SetTexture(lib.EntryIcon(entry)) end
	ns.Guard("rota repaint", self.Refresh, self)
end

-- The rota's place for the panel's second line in a fight: which of how many
-- the button is on, or nil with no rota.
function Prompt:FightRotaAt()
	local rota = S.rota
	if not (rota and InCombatLockdown()) then return nil end
	return rota.index, #rota.entries
end

-- PLAYER_REGEN_ENABLED, out of lockdown, before its repaint (Core.lua): the
-- snippet steps nothing outside a fight, and the repaint arms the prompt
-- afresh.
function Prompt:ReleaseFightRota()
	S.rota, S.fightQueue = nil, nil
	local header = R.fight
	if not header or InCombatLockdown() then return end
	header:SetAttribute("manners-rota-n", 0)
	header:SetAttribute("manners-rota-i", 1)
end

-- PLAYER_REGEN_DISABLED, after the pull's repaint has written the bar macro,
-- and still out of lockdown (Core.lua). The verdict the snippet reads.
function Prompt:ArmFightHide()
	if not R.fight then self:CreateFightHide() end
	local header = R.fight
	if not header or InCombatLockdown() then return end
	header:SetAttribute("manners-hide", false)
	if not self:HidesForFight() then return end
	if not ns.BarMacroDisarmed() then
		-- Not at every pull: a macro changed by hand stays that way.
		local now = GetTime()
		if ns.db.profile.verbose and not (stayedSaidAt and now - stayedSaidAt < STAYED_REST) then
			stayedSaidAt = now
			ns.addon:Print(L["the prompt stays up for this fight: your |cffffd100%s|r macro still held a cast as it began, and a hidden prompt must cast nothing unseen."]
				:format(tostring(ns.CLICK_MACRO_NAME)))
		end
		return
	end
	-- The bar slot draws no spell over a macro that casts nothing this fight;
	-- the arming after it gives the slot back (Macro.lua, Arm).
	ns.SyncMacroSlot(nil)
	header:SetAttribute("manners-hide", true)
end

-- PLAYER_REGEN_ENABLED, out of lockdown, before its repaint (Core.lua).
function Prompt:ReleaseFightHide()
	local header = R.fight
	if not header then
		self:CreateFightHide()
		return
	end
	if InCombatLockdown() then return end
	-- First: a driver that still reads [combat] once the lockdown is over
	-- (the client's combat flag and its lockdown are two things) hides
	-- nothing outside a fight.
	header:SetAttribute("manners-hide", false)
	-- The next pull is a change whatever the driver last read: two fights a
	-- frame apart leave it on "fight" otherwise, and the second goes unseen.
	header:SetAttribute("state-" .. STATE, "peace")
	-- Nothing to put back on the button: the repaint after this arms it for
	-- whoever it names now, since the key it was armed with at the pull
	-- carried armedForFight, which is off again (Macro.lua, Arm). A list row
	-- holds nothing at rest (Rows.lua).
end
