-- Manners -- the prompt in a fight: the fight's rota (Look, In a fight, each
-- press buffs the next person in line) and the secure header it runs on.
--
-- (Hide the prompt in a fight, which this file held until 1.12, is gone: the
-- notes below on why a hidden secure button still casts stay, for whoever
-- thinks of hiding the prompt again.)
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
-- post-body writes the next macro of the rota on the button: each press in the
-- fight casts at the next person, once round. It reads nothing of the game (a
-- snippet can ask neither the cooldown nor anybody's buffs: the restricted
-- environment's functions are the macro conditionals' and a few action-bar
-- reads, RestrictedEnvironment.lua, and a handle to a frame Lua could write
-- in a fight is refused, RestrictedFrames.lua GetHandleFrame), so "pressed
-- for" is all it can know of who has the buff. After its last it writes
-- nothing on the button, and a press then casts nothing until the fight ends:
-- it went round and round until the review of 2026-11-15, casting a buff of
-- half an hour again at somebody it had buffed seconds before. A press the
-- cooldown turned away still moves on; whoever it passed over is offered
-- again after the fight, as everybody still missing a buff is.
--
-- Lua follows: PostClick (Press.lua) files the press on the person it was
-- armed at, as ever, and then SyncFightRota reads where the snippet has got to
-- and points `current` there, so the panel names who the next press is for.
-- Only a left press steps, as only a left press casts. Not from the Manners
-- macro on a bar, which casts by its own lines and holds the one the pull wrote: no
-- macro may /click a button that runs a macro (CLAUDE.md, Macro), and an
-- addon may not rewrite one in a fight, so the bar macro cannot step at all.
-- Start here says so on the button that makes it (Options/Start.lua).

local _, ns = ...
local Prompt = ns.Prompt
local R = Prompt.regions
local S = Prompt.state
local lib = Prompt.lib
local InCombatLockdown = _G.InCombatLockdown

-- The rota's two halves, run round each click of the prompt in the restricted
-- environment: `self` is the prompt's handle, `control` the header's. The
-- first lets the second run for a left press with a rota, of one too (the
-- one place that is asked: the second runs only on the first's word); the
-- second steps the button to the rota's next macro, and past its last to
-- none: `manners-rota-i` past n, which SyncFightRota reads as the round done.
-- Nothing above n is ever cast from: a longer rota of an earlier fight may
-- have left its later macros on the header.
local ROTA_PRE = [=[
	if button ~= "LeftButton" or down == false then return end
	local n = control:GetAttribute("manners-rota-n") or 0
	if n < 1 then return end
	return nil, "step"
]=]
local ROTA_POST = [=[
	local n = control:GetAttribute("manners-rota-n") or 0
	local i = (control:GetAttribute("manners-rota-i") or 1) + 1
	control:SetAttribute("manners-rota-i", i)
	local text = control:GetAttribute("manners-rota-" .. i)
	if i > n then text = nil end
	self:SetAttribute("macrotext1", text)
	self:SetAttribute("macrotext", text)
]=]
-- The most a rota holds: the people a fight is likely to leave time for.
local ROTA_MAX = 12
Prompt.ROTA_MAX = ROTA_MAX

-- The queue the pull's own repaint arms the fight from (Refresh.lua, the pass
-- PLAYER_REGEN_DISABLED makes before the lockdown), less every passer-by it
-- holds from memory alone (Queue.lua, OfferPassersBy: no token reached them
-- this scan, `remembered`). The memory keeps an offer up for the few seconds
-- it takes to reach the prompt after the cursor or a nameplate left them; at
-- the pull it would freeze somebody who walked off on the button for the
-- whole fight, and make the rota of people who have left. Somebody who asked
-- stays (the request is the reason), and so does a favour owed, which is no
-- memory of where anybody stood. The same table when nothing is left out.
local function ForFight(queue)
	local kept
	for i, entry in ipairs(queue) do
		if entry.remembered and entry.reason == "nearby" then
			if not kept then
				kept = {}
				for j = 1, i - 1 do kept[j] = queue[j] end
			end
		elseif kept then
			kept[#kept + 1] = entry
		end
	end
	return kept or queue
end
lib.ForFight = ForFight

-- The secure header the rota runs on. Made once, out of combat, after the
-- prompt and its rows (Panel.lua, Create); asked again at a pull and at each
-- end of a fight when a login or a /reload in one left it unmade. A client
-- without the secure handlers leaves the prompt as it was, with no rota.
function Prompt:CreateFightHeader()
	if R.fight or not R.button or InCombatLockdown() then return end
	local ok, header = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
	if not ok or type(header) ~= "table" or type(header.SetFrameRef) ~= "function" then return end
	R.fight = header
	-- The rota's wrap round the prompt's click, where the client has one.
	header:SetAttribute("manners-rota-n", 0)
	header:SetAttribute("manners-rota-i", 1)
	if type(_G.SecureHandlerWrapScript) == "function" then
		header.rotaWrapped = pcall(_G.SecureHandlerWrapScript, R.button, "OnClick", header, ROTA_PRE, ROTA_POST) or nil
	end
end

-- For tests and /manners selftest.
function Prompt:FightHeader() return R.fight end

-- PLAYER_REGEN_DISABLED, after the pull's repaint has armed the prompt, still
-- out of lockdown (Core.lua): the rota for this fight, or none. The queue is
-- what that repaint built (Refresh.lua keeps it for this, S.fightQueue).
function Prompt:ArmFightRota()
	if not R.fight then self:CreateFightHeader() end
	local header = R.fight
	if not header or InCombatLockdown() then return end
	header:SetAttribute("manners-rota-n", 0)
	header:SetAttribute("manners-rota-i", 1)
	S.rota = nil
	local db = ns.db and ns.db.profile
	if not (db and db.prompt.fightRota ~= false and header.rotaWrapped) then return end
	-- Nothing to step in a preview, or with nobody on the prompt.
	if S.testMode then return end
	local top, queue = S.current, S.fightQueue
	local armed = R.button:GetAttribute("macrotext1")
	if not (top and top.buff and type(armed) == "string" and armed ~= "" and type(queue) == "table") then return end
	-- The one on the button first, as armed, then the rest of the queue in its
	-- own order, less whoever a cast already in the rota reaches: the members
	-- of a group cast (Arcane Brilliance for the party is one press, not one
	-- and then an Intellect each), and, where one cast lands on the whole
	-- group (a shout; Mists and retail), the rest of the group for that buff.
	local reached, wide = {}, {}
	local function Reaches(entry)
		local key = entry.buff.key
		if entry.groupCast then
			reached[key] = reached[key] or {}
			for _, name in ipairs(entry.groupCast.members or {}) do reached[key][name] = true end
		elseif entry.buff.selfCast or (ns.WIDE_CASTS == true and entry.inGroup == true
			and not entry.buff.alone and not entry.buff.own) then
			wide[key] = true
		end
	end
	local function Reached(entry)
		local key = entry.buff.key
		if reached[key] and reached[key][entry.name] then return true end
		return wide[key] == true and entry.inGroup == true and not entry.groupCast
	end
	local entries, records, texts = { top }, { S.armed or false }, { armed }
	Reaches(top)
	for _, entry in ipairs(queue) do
		if #entries >= ROTA_MAX then break end
		if entry ~= top and entry.buff and not (entry.name == top.name and entry.buff.key == top.buff.key)
			and not Reached(entry) then
			local text, record = lib.FightMacro(entry)
			if text then
				local at = #entries + 1
				entries[at], records[at], texts[at] = entry, record or false, text
				Reaches(entry)
			end
		end
	end
	-- One person is a rota too (the owner's report of 2026-11-15: a group member
	-- buffed in a fight, and every press after cast Arcane Intellect at him
	-- again): one press for them, then nothing until the fight ends.
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
	if type(i) ~= "number" or i == rota.index then return end
	if i > #rota.entries then
		-- Past its last: everybody it began with has had a press, and the
		-- button casts nothing (ROTA_POST). Nobody is on the panel, so a press
		-- of nothing is filed on nobody. Said once: every press after steps
		-- the count on, and casts nothing either.
		if rota.done then return end
		rota.index, rota.steps, rota.done = i, rota.steps + 1, true
		S.current, S.frozenEntry, S.armed = nil, nil, nil
		ns.lastMacro, ns.lastTopEntry, ns.lastTopUnit = nil, nil, nil
		ns.Trail("fight", "the rota has pressed for everybody it began with")
		ns.Guard("rota repaint", self.Refresh, self)
		return
	end
	if not rota.entries[i] then return end
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

-- Whether the fight's rota has pressed for everybody it began with.
function Prompt:FightRotaDone()
	local rota = S.rota
	return rota ~= nil and rota.done == true and InCombatLockdown()
end

-- For the fight summary line (Core.lua): how many steps the rota took and of
-- how many; nil with no rota. Reads Lua state only.
function Prompt:FightRotaSteps()
	local rota = S.rota
	if not rota then return nil end
	return rota.steps, #rota.entries
end

-- PLAYER_REGEN_ENABLED, out of lockdown, before its repaint (Core.lua): the
-- snippet steps nothing outside a fight, and the repaint arms the prompt
-- afresh (the key it was armed with at the pull carried armedForFight, which
-- is off again: Macro.lua, Arm). A header a login in a fight left unmade is
-- made now.
function Prompt:ReleaseFightRota()
	S.rota, S.fightQueue = nil, nil
	local header = R.fight
	if not header then
		self:CreateFightHeader()
		return
	end
	if InCombatLockdown() then return end
	header:SetAttribute("manners-rota-n", 0)
	header:SetAttribute("manners-rota-i", 1)
end
