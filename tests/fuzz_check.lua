-- What must hold after every fuzz step (see fuzz_world.lua). Each check
-- names itself in the failure it raises; the first to fail ends the run.
--
-- Loaded by fuzz_world.lua: `dofile(this)(X)`.

return function(X)

-- A message reduced to what stays the same between two runs of the same
-- fault: numbers, addresses, paths and line numbers out.
local function normalise(text)
	text = tostring(text):gsub("\n.*", "")
	text = text:gsub("[^%s'\"%(%)%[%]]*[/\\]([%w_%.%-]+%.lua)", "%1")
	text = text:gsub("(%.lua):%d+", "%1")
	text = text:gsub("0x%x+", "ADDR"):gsub("%x%x%x%x%x%x%x%x+", "HEX")
	text = text:gsub("%d+%.?%d*", "N")
	return text
end
X.normalise = normalise

-- Every occurrence of `word` in `text` that is a word of its own: not the
-- start, the middle or the end of a longer ASCII word ("Mo" is not the "Mo" of
-- "Motw"). Text in other scripts has no ASCII letters, so a name between two
-- Korean words is still found.
local function replaceWord(text, word, with)
	if word == "" then return text end
	local out, from = {}, 1
	while true do
		local at = text:find(word, from, true)
		if not at then break end
		local before = text:sub(at - 1, at - 1)
		local after = text:sub(at + #word, at + #word)
		if before:find("^[A-Za-z0-9_]$") or after:find("^[A-Za-z0-9_]$") then
			out[#out + 1] = text:sub(from, at)
			from = at + 1
		else
			out[#out + 1] = text:sub(from, at - 1) .. with
			from = at + #word
		end
	end
	out[#out + 1] = text:sub(from)
	return table.concat(out)
end

-- A message with the names of the people in it taken out, so that the same
-- fault met with two different people is one signature.
local function anonymise(W, text)
	text = tostring(text)
	if not W.namesLong then
		-- The longest first, so that "Tamsin" does not leave the "en" of "Tamsinen".
		local names = { X.filedName(W, W.me) }
		for _, p in ipairs(W.people) do names[#names + 1] = X.filedName(W, p) end
		table.sort(names, function(a, b)
			if #a ~= #b then return #a > #b end
			return a < b
		end)
		W.namesLong = names
	end
	for _, name in ipairs(W.namesLong) do text = replaceWord(text, name, "NAME") end
	return text
end
X.anonymise = anonymise

-- What a failure is called: the invariant and its message with what differs
-- between two meetings of one fault taken out -- the people, the buff (its key
-- and its spell's name), the macro or line in parentheses or quotes, the
-- numbers. One fault met with another buff, another person or another line is
-- one signature, not as many as there were meetings. A Lua error (`literal`)
-- keeps its quotes and parentheses, which name the variable and the value.
local function signature(W, kind, message, literal)
	local text = anonymise(W, (tostring(message):gsub("\n.*", "")))
	if literal then return kind .. "|" .. normalise(text) end
	if not W.buffWords or W.buffWordsOf ~= W.classBuffs then
		local words, seen = {}, {}
		for _, entry in ipairs(W.classBuffs or {}) do
			for _, word in ipairs({ entry.buff.key, entry.name }) do
				if type(word) == "string" and #word >= 3 and not seen[word] then
					seen[word] = true
					words[#words + 1] = word
				end
			end
		end
		table.sort(words, function(a, b)
			if #a ~= #b then return #a > #b end
			return a < b
		end)
		W.buffWords, W.buffWordsOf = words, W.classBuffs
	end
	for _, word in ipairs(W.buffWords) do text = replaceWord(text, word, "BUFF") end
	text = text:gsub("%b()", "()"):gsub('"[^"]*"', '"Q"')
	return kind .. "|" .. normalise(text)
end
X.signature = signature

-- `sigText` stands in for the message in the signature, for a message that
-- ends in the macro or the line it is about.
local function fail(W, kind, message, where, sigText)
	if W.failure then return end
	W.failure = { kind = kind, message = tostring(message), where = where,
		sig = signature(W, kind, sigText or message) }
end
X.fail = fail

-- Escapes carry their own signature.
local rawEscaped = X.escaped
function X.escaped(W, where, err)
	if W.failure then return end
	local first = tostring(err):gsub("\n.*", "")
	W.failure = { kind = "escape", where = where, message = tostring(err),
		sig = signature(W, "escape", first, true) }
end

local SPOKEN_FREE = { target = true, cast = true, use = true, targetlasttarget = true }
local FORBIDDEN_LINES = { script = true, run = true, console = true, click = true, dump = true,
	reload = true, logout = true, quit = true, camp = true, exit = true }

local function lines(text)
	local out = {}
	for line in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
		if line ~= "" then out[#out + 1] = line end
	end
	return out
end

local function spokenOf(text)
	local out = {}
	for _, line in ipairs(lines(text)) do
		local cmd = line:match("^/(%S+)")
		if not cmd or not SPOKEN_FREE[cmd:lower()] then out[#out + 1] = line end
	end
	return out
end
X.spokenOf = spokenOf

-- The slash command each channel setting speaks with.
local CHANNEL_COMMAND = { SAY = "say", YELL = "yell", PARTY = "party", RAID = "raid", EMOTE = "emote",
	WHISPER = "w" }

-- The person a filed name is, among everyone in the world.
local function personNamed(W, name)
	for _, p in ipairs(W.people) do
		if X.filedName(W, p) == name then return p end
	end
	for _, p in ipairs(W.mobs) do
		if X.filedName(W, p) == name then return p end
	end
	if W.me and X.filedName(W, W.me) == name then return W.me end
	return nil
end
X.personNamed = personNamed

-- ---------------------------------------------------------------- macro

local function checkMacroText(W, macro, label)
	if type(macro) ~= "string" then
		return fail(W, "macro", label .. ": macrotext1 is a " .. type(macro))
	end
	if #macro > 255 then
		return fail(W, "macro", ("%s: macro is %d characters"):format(label, #macro))
	end
	if macro:find("%[@") then
		return fail(W, "macro", label .. ": macro holds a [@ conditional: " .. macro:gsub("\n", " / "), nil,
			label .. ": macro holds a [@ conditional")
	end
	for _, line in ipairs(lines(macro)) do
		local cmd = line:match("^%s*/(%S+)")
		if line:match("^%s") then
			return fail(W, "macro", label .. ": a macro line starts with a space: " .. line)
		end
		if cmd and FORBIDDEN_LINES[cmd:lower()] then
			return fail(W, "macro", label .. ": macro holds /" .. cmd:lower() .. ": " .. macro:gsub("\n", " / "), nil,
				label .. ": macro holds /" .. cmd:lower())
		end
		if not cmd then
			return fail(W, "macro", label .. ": a macro line is not a command: " .. line)
		end
		if line:find("[%c]") then
			return fail(W, "macro", label .. ": a macro line holds a control character: " .. ("%q"):format(line))
		end
	end
end

-- The rule for a spoken line, asked of the entry the macro was armed for.
local function lineAllowed(W, entry)
	local ns = W.ns
	-- Asked of a client that answers nothing now and then, the same question
	-- gets two answers; the world's own word (checkPress) still holds.
	if W.flaky then return true end
	local speech = ns.db.profile.speech
	if not speech.enabled then return false, "speech is switched off" end
	if not entry then return false, "no entry armed" end
	if entry.reason == "self" then return false, "a line to yourself" end
	if Mock.inCombat then return false, "in a fight" end
	if ns.Prompt.armedForFight == true then return false, "armed for a fight" end
	if entry.ranged ~= true then return false, "the scan did not measure them in reach" end
	local speaker = ns.LineSpeaker(entry)
	if speech.onlyWhenReturning and speaker.reason ~= "owed" then
		return false, "only when returning, and this is not a return"
	end
	if not ns.ChannelOpen(speaker) then return false, "the channel reaches nobody" end
	return true
end

function X.checkMacro(W)
	local ns = W.ns
	local button = ns.Prompt and ns.Prompt:GetButton()
	if not button then return end
	local macro = button:GetAttribute("macrotext1")
	local kind = button:GetAttribute("type1")
	if macro == nil then
		if kind == "macro" then return fail(W, "macro", "type1 is macro with no macrotext1") end
		return
	end
	checkMacroText(W, macro, "armed")
	if W.failure then return end
	if #macro > (W.stats.maxMacro or 0) then W.stats.maxMacro = #macro end
	-- The modes that must never arm the button.
	if not Mock.inCombat then
		local db = ns.db.profile
		local S0 = ns.Prompt.state
		local why
		if not db.enabled then why = "the addon is switched off"
		elseif db.prompt.locked == false then why = "the prompt is unlocked"
		elseif S0.testMode then why = "the preview is showing"
		elseif ns.SnoozeLeft and ns.SnoozeLeft(Mock.now) then why = "it is snoozed"
		elseif not ns.CanCastAnything() then why = "nothing is learned to cast" end
		if why then
			return fail(W, "disarm", ("the button is armed (%s) but %s"):format((macro:gsub("\n", " / ")), why))
		end
	end
	if kind ~= "macro" then return fail(W, "macro", "macrotext1 is set and type1 is " .. tostring(kind)) end
	if button:GetAttribute("macrotext") ~= macro or button:GetAttribute("type") ~= "macro" then
		return fail(W, "macro", "the unsuffixed macro attributes disagree with the button-1 ones")
	end
	local S = ns.Prompt.state
	local spoken = spokenOf(macro)
	if #spoken > 0 then W.stats.lines = (W.stats.lines or 0) + 1 end
	if #spoken > 0 and not ns.tryMacro then
		-- Out of a fight the macro on the button was armed by the last repaint.
		if Mock.inCombat then
			return fail(W, "speech", "a spoken line is in the macro in a fight: " .. spoken[1], nil,
				"a spoken line is in the macro in a fight")
		end
		local ok, why = lineAllowed(W, S.current)
		if not ok then
			return fail(W, "speech", ("a spoken line is armed (%s) but %s"):format(spoken[1], why))
		end
		-- The line goes out on the channel the setting names.
		local want = CHANNEL_COMMAND[ns.db.profile.speech.channel]
		local cmd = spoken[1]:match("^/(%S+)")
		if want and cmd ~= want then
			return fail(W, "speech", ("the line speaks on /%s and the setting says /%s"):format(tostring(cmd), want))
		end
		-- A whisper goes to the person the line thanks, by the name they are filed under.
		if cmd == "w" then
			local who = ns.LineSpeaker(S.current).name
			if spoken[1]:sub(1, 4 + #who) ~= "/w " .. who .. " " then
				return fail(W, "speech", ("a whisper for %s reads: %s"):format(who, spoken[1]), nil,
					"a whisper is not addressed to the person it thanks")
			end
		end
	end
	-- Armed means somebody is on the prompt.
	if not Mock.inCombat and not S.current and not ns.tryMacro then
		return fail(W, "macro", "the button is armed with nobody on the prompt: " .. macro:gsub("\n", " / "), nil,
			"the button is armed with nobody on the prompt")
	end
	if S.current and S.current.buff and not ns.tryMacro and not Mock.inCombat then
		local entry = S.current
		local aim = entry.targetName or entry.name
		local first = lines(macro)[1]
		if entry.buff.item then
			if not (first and first:find("/use item:", 1, true)) then
				return fail(W, "macro", "a scroll is armed without /use item: " .. macro:gsub("\n", " / "), nil,
					"a scroll is armed without /use item:")
			end
		elseif not entry.buff.selfCast then
			if first ~= "/target " .. aim then
				return fail(W, "macro", ("the macro targets %q and the entry is %q"):format(tostring(first), aim))
			end
		end
		local cast = macro:match("/cast ([^\n]*)")
		if cast and not entry.buff.item and cast ~= ns.EntrySpellName(entry) then
			return fail(W, "macro", ("the macro casts %q and the entry's spell is %q"):format(cast, ns.EntrySpellName(entry)))
		end
	end
end

-- The macro a press is about to run, after PreClick has aimed it: the line
-- may be in it only for a press that can land.
function X.checkPress(W, macro, rowEntry)
	local ns = W.ns
	checkMacroText(W, macro, "pressed")
	if W.failure then return end
	local spoken = spokenOf(macro)
	if #spoken == 0 or ns.tryMacro then return end
	local S = ns.Prompt.state
	-- A name in the list is armed for its own press: the entry it holds, not the prompt's.
	local entry = rowEntry or S.current
	if Mock.inCombat then
		return fail(W, "speech", "a press in a fight carries a spoken line: " .. spoken[1], nil,
			"a press in a fight carries a spoken line")
	end
	local ok, why = lineAllowed(W, entry)
	if not ok then
		return fail(W, "speech", ("a press carries a line (%s) but %s"):format(spoken[1], why))
	end
	-- The world's own word on whether the cast can land.
	local p = personNamed(W, entry.name)
	local now = Mock.now
	local function bad(reason)
		fail(W, "speech", ("a press speaks (%s) over a cast that cannot land: %s"):format(spoken[1], reason))
	end
	if not p then return bad("nobody of that name") end
	local held = X.tokensOf(W, p)
	if p ~= W.me and #held == 0 then return bad("no token names " .. entry.name) end
	if p.dead or p.ghost or p.feign then return bad("they are dead") end
	if W.me.dead then return bad("the player is dead") end
	if not p.visible then return bad("they are out of sight") end
	if entry.buff.selfCast then
		if p.yards > 20 then return bad(("the shout does not surely reach %d yards"):format(p.yards)) end
	elseif p ~= W.me and p.yards > 30 then
		return bad(("they are %d yards away"):format(p.yards))
	end
	if W.gcdEnds > now then return bad("the global cooldown is running") end
	if W.casting and W.casting.endsAt > now then return bad("the player is casting") end
	if W.flying and W.cvars.autoDismountFlying ~= "1" then return bad("the player is flying") end
	if p ~= W.me and not p.assist then return bad("they cannot be assisted") end
end

-- The first member of the group a party-wide cast would land on who is
-- flagged for PvP and within the cast's reach, by the world's own record.
local function flaggedLander(W)
	local ns = W.ns
	for _, member in ipairs(W.raid or W.party or {}) do
		local reachable = member ~= W.me and member.visible and (not member.dead or member.feign)
		local inside = true
		if W.raid and ns.PARTY_IS_SUBGROUP then inside = member.subgroup == W.me.subgroup end
		if reachable and inside and (member.pvp or member.ffa) and not member.pvpRead then return member end
	end
	return nil
end

-- Whether the never-offer list names this person: exactly, regardless of
-- case, or by the name without a realm (Queue.lua, ListedAs says so).
local function listed(db, name)
	local short = name:match("^([^%-]+)") or name
	local lower, lowerShort = name:lower(), short:lower()
	for key in pairs(db.never or {}) do
		if type(key) == "string" then
			local k = key:lower()
			if k == lower or k == lowerShort then return true end
		end
	end
	return false
end

-- ----------------------------------------------------------- completeness
--
-- The other way round: somebody the world says is plainly worth a buff, and
-- nothing explains the queue leaving them out. Judged only where the answer
-- is simple -- one kind of single-target buff, nothing withheld, nothing
-- folded into a group cast, no rule of the settings about where or how
-- many -- so that what is left is a silent drop and not a rule.

-- Every token the walk meets, in its order.
local function walkTokens(W)
	local out = { "target", "focus", "mouseover" }
	if W.raid then
		for i = 1, #W.raid do out[#out + 1] = "raid" .. i end
	elseif W.party then
		for i = 1, #W.party do out[#out + 1] = "party" .. i end
	end
	for _, token in ipairs(W.plates) do out[#out + 1] = token end
	return out
end

local MANA = { PRIEST = true, MAGE = true, DRUID = true, PALADIN = true, HUNTER = true, WARLOCK = true,
	SHAMAN = true, MONK = true, EVOKER = true }

function X.checkComplete(W, queue, standing)
	local ns = W.ns
	local db = ns.db.profile
	local f, src = db.filters, db.sources
	MANA.HUNTER = (W.flavour ~= "mainline") or nil
	local sec = W.secret
	if W.flaky then return end
	if sec.all or sec.identity then return end
	-- With the auras of others withheld nobody can be told to lack a buff; a
	-- request still stands (below).
	local auraOpen = not (sec.auras or sec.aura ~= "open" or next(sec.ids))
	if W.readThrows and next(W.readThrows) then return end
	if W.mana0 or W.me.mana <= 0.02 or W.me.dead or W.me.ghost then return end
	if W.charmed or W.inVehicle or W.onTaxi or (W.mounted and f.hideMounted) then return end
	if f.manaFloor ~= 0 or f.restingOnly or (W.raid and next(f.skipRaidGroups or {})) then return end
	if not ns.CanCastAnything() or ns.EXCLUSIVE_BUFFS[ns.PlayerClass()] then return end
	if ns.SnoozeLeft and ns.SnoozeLeft(Mock.now) then return end
	for _, e in ipairs(queue) do if e.groupCast then return end end
	local candidates = ns.CastableBuffs()
	local pinned = ns.PinnedBuff()
	if pinned then
		if not ns.IsBuffKnown(pinned) then return end
		candidates = { pinned }
	end
	if #candidates == 0 then return end
	-- Where the auras of others are withheld, or one of the spells is a shout,
	-- a group-only or party-only cast or a scroll, who is plainly worth a buff
	-- is not a simple answer, and the walk below is left out; what somebody who
	-- asked for a single-target buff is offered still is one.
	local simple = auraOpen
	for _, buff in ipairs(candidates) do
		if buff.selfCast or buff.groupOnly or buff.partyOnly or buff.item then simple = false end
	end
	if simple then W.stats.cmpRuns = (W.stats.cmpRuns or 0) + 1 end
	local inQueue, entryOf = {}, {}
	for _, e in ipairs(queue) do inQueue[e.name] = true entryOf[e.name] = e end
	local now = Mock.now
	local seen = {}
	for _, token in ipairs(simple and walkTokens(W) or {}) do
		local p = W.tok[token]
		if p and p ~= W.me and not p.npc then
			local name = X.filedName(W, p)
			local pointed = token == "target" or token == "focus"
			if not seen[name] then
				seen[name] = true
				local skip = ns.owed[name] ~= nil
					or (W.askedAt and W.askedAt[name] and now - W.askedAt[name] < 75)
					or not p.connected or p.dead or p.ghost or not p.assist
					or (p.unknownName and p.unknownName >= (W.stepNo or 0))
					or (f.minLevel > 1 and p.level < f.minLevel)
					or listed(db, name)
					or (not p.grouped and p.ignored)
					or (standing and (p.pvp or p.ffa))
					or ns.IsBlocked(name, nil, now)
				if p.grouped then
					skip = skip or not src.group
				else
					skip = skip or not src.strangers or (f.proximity ~= "cast" and not pointed)
				end
				if f.requireInRange and not (p.visible and p.yards <= 30) then skip = true end
				if not skip then
					local missed
					for _, buff in ipairs(candidates) do
						local fine = not ns.IsBlocked(name, buff.key, now)
						-- A cast that lands on the whole party waits while one
						-- of them is flagged and you are not.
						if fine and standing and p.grouped and ns.WIDE_CASTS == true and not buff.alone
							and not buff.own and flaggedLander(W) then
							fine = false
						end
						if fine and f.relevantOnly and buff.manaOnly and not MANA[p.class] then fine = false end
						if fine and f.skipSameClass and not pointed and p.class == W.me.class
							and not buff.talent then
							local info = ns.BuffInfo(buff)
							local need = ns.RankLevel(info and info.topRank) or 1
							if p.level >= need then fine = false end
						end
						if fine then
							for _, id in ipairs(buff.auraIds) do
								if p.buffs[id] then fine = false break end
							end
						end
						if fine and (now - (p.auraAt or -100)) < 3.6 then fine = false end
						if fine then missed = buff break end
					end
					if missed then W.stats.cmpExpected = (W.stats.cmpExpected or 0) + 1 end
					if missed and not inQueue[name] then
						local verdict = W.lastVerdicts
						local said = type(verdict) == "table" and verdict[name] or (type(verdict) ~= "table" and verdict) or "none"
						return fail(W, "missing", ("%s (%s, %d yards, %s) is plainly worth %s and is not on the queue (verdict %s)"):format(
							name, token, p.yards, p.grouped and "grouped" or "a stranger", missed.key, tostring(said)))
					end
					-- Back from the dead in the group: first in line while
					-- they lack the buff (Queue.lua, WatchGroupDeaths).
					local back = W.revived and W.revived[p]
					local e = entryOf[name]
					if missed and e and back and p.grouped and db.priority.revived == true
						and f.whenBuffed ~= "always" and e.inGroup and e.known == false
						and now - back.at < 110 then
						W.stats.cmpRevived = (W.stats.cmpRevived or 0) + 1
						if e.sweep == nil then
							return fail(W, "revived", ("%s was raised %d seconds ago in the group and is not put first"):format(
								name, now - back.at))
						end
						-- ...and first means ahead of every plain group member and
						-- passer-by, which the sweep reason alone does not do.
						for _, ahead in ipairs(queue) do
							if ahead == e then break end
							if ahead.sweep == nil and (ahead.reason == "group" or ahead.reason == "nearby") then
								return fail(W, "revived", ("%s was raised %d seconds ago in the group and is queued behind %s"):format(
									name, now - back.at, ahead.name))
							end
						end
					end
				end
			end
		end
	end
	-- Somebody who asked, in so many words, for a buff they lack is offered it
	-- as asked for, for a minute, whatever the passer-by and group switches say.
	if src.asked then
		local names = {}
		for name in pairs(W.reqs or {}) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			local req = W.reqs[name]
			local p, buff = req.person, req.buff
			local token
			for _, t in ipairs(walkTokens(W)) do
				if W.tok[t] == p then token = t break end
			end
			local skip = not token or req["until"] <= now + 2
				or not p.connected or p.dead or p.ghost or not p.assist
				or (p.unknownName and p.unknownName >= (W.stepNo or 0))
				or (f.minLevel > 1 and p.level < f.minLevel)
				or listed(db, name)
				or (not p.grouped and p.ignored)
				or (standing and (p.pvp or p.ffa))
				or ns.IsBlocked(name, nil, now) or ns.IsBlocked(name, buff.key, now)
				or p.class == W.me.class
				or (f.requireInRange and not (p.visible and p.yards <= 30))
				or (now - (p.auraAt or -100)) < 3.6
				or db.buff.skip[buff.key] or (pinned and pinned.key ~= buff.key)
				-- A buff no longer learned (a respec, a spellbook change) cannot be cast.
				or not ns.IsBuffKnown(buff)
			if not skip then
				for _, id in ipairs(buff.auraIds) do
					if p.buffs[id] then skip = true end
				end
			end
			if not skip and standing and p.grouped and ns.WIDE_CASTS == true and not buff.alone
				and flaggedLander(W) then
				skip = true
			end
			if not skip then
				W.stats.cmpAsked = (W.stats.cmpAsked or 0) + 1
				local e = entryOf[name]
				if not e then
					return fail(W, "missing", ("%s asked for %s and is not on the queue"):format(name, buff.key))
				elseif e.reason ~= "asked" and e.reason ~= "owed" then
					return fail(W, "missing", ("%s asked for %s and is offered as %s"):format(name, buff.key, e.reason))
				end
			end
		end
	end
end

-- With nobody's auras readable the walk has nothing to go on but what it
-- gave last, and goes on to the next spell rather than back to the first
-- (Core.lua, PickBuffFor): a later spell nobody has tried lately is never
-- passed over for an earlier one.
function X.checkRotation(W, queue)
	local ns = W.ns
	if not W.secret.hideAll or W.secret.all or W.secret.identity or W.flaky then return end
	if not ns.RotatesBuffs() or ns.PinnedBuff() then return end
	local db = ns.db.profile
	local f = db.filters
	if f.skipSameClass then return end
	local candidates = ns.CastableBuffs()
	if #candidates < 3 then return end
	local index = {}
	for i, b in ipairs(candidates) do index[b.key] = i end
	for _, e in ipairs(queue) do
		local last = ns.lastGave[e.name]
		local li = last and index[last]
		local yi = index[e.buff.key]
		if li and yi and yi < li and e.reason ~= "self" and e.reason ~= "owed" and not e.groupCast
			and e.unit and e.unit ~= "player" then
			local p = W.resolve(e.unit)
			for z = li + 1, #candidates do
				local later = candidates[z]
				local fine = not ns.IsBlocked(e.name, later.key, Mock.now)
				if fine and f.relevantOnly and later.manaOnly and p and not MANA[p.class] then fine = false end
				if fine and (later.partyOnly or later.groupOnly) then fine = false end
				if fine then
					return fail(W, "rotation", ("%s was last given %s and is offered %s again, passing over %s"):format(
						e.name, last, e.buff.key, later.key))
				end
			end
		end
	end
end

-- ----------------------------------------------------------------- queue

local REASONS = { owed = true, group = true, nearby = true, asked = true, target = true, self = true }

local function standsPvP(W)
	local me = W.me
	local flagged = me.pvp or me.ffa
	if not flagged then return true end
	local battle = W.inInstance == "pvp" or W.inInstance == "arena"
	if battle then return false end
	return W.pvpTimer == true
end

-- Run by the BuildQueue wrapper (fuzz_world.lua) the moment a queue is
-- built, so the world it is judged against is the world it was built from:
-- a later press may block somebody the snapshot still holds.
function X.checkQueue(W, queue)
	local ns = W.ns
	if type(queue) == "table" and #queue > 0 then
		W.stats.queued = W.stats.queued + 1
		for _, e in ipairs(queue) do
			if e.groupCast then W.stats.group = W.stats.group + 1 end
			if e.reason == "owed" then W.stats.owed = W.stats.owed + 1 end
			W.stats["r_" .. tostring(e.reason)] = (W.stats["r_" .. tostring(e.reason)] or 0) + 1
		end
	end
	local db = ns.db.profile
	local f, src = db.filters, db.sources
	if type(queue) ~= "table" then return fail(W, "queue", "BuildQueue answered a " .. type(queue)) end

	-- Nothing is offered while the player cannot cast.
	if #queue > 0 then
		if W.me.dead or W.me.ghost then return fail(W, "queue", "offered " .. queue[1].name .. " while dead") end
		if W.charmed or W.inVehicle or W.onTaxi then
			return fail(W, "queue", "offered " .. queue[1].name .. " charmed, in a vehicle or on a taxi")
		end
		if f.hideMounted == true and W.mounted then
			return fail(W, "queue", "offered " .. queue[1].name .. " while mounted with Hide while mounted on")
		end
		if not ns.CanCastAnything() then
			return fail(W, "queue", "offered " .. queue[1].name .. " with nothing learned to cast")
		end
	end

	local names, memberOf = {}, {}
	local standing = f.skipPvP == true and standsPvP(W)
	for i, e in ipairs(queue) do
		if type(e) ~= "table" then return fail(W, "queue", "entry " .. i .. " is a " .. type(e)) end
		if type(e.name) ~= "string" or e.name == "" then return fail(W, "queue", "an entry has no name") end
		if type(e.buff) ~= "table" or type(e.buff.key) ~= "string" then
			return fail(W, "queue", e.name .. " has no buff")
		end
		if type(e.reason) ~= "string" or not REASONS[e.reason] then
			return fail(W, "queue", e.name .. " has the reason " .. tostring(e.reason))
		end
		if i > 1 and e.priority < queue[i - 1].priority then
			return fail(W, "queue", ("%s (priority %s) is queued after %s (priority %s)"):format(
				e.name, tostring(e.priority), queue[i - 1].name, tostring(queue[i - 1].priority)))
		end
		if names[e.name] then return fail(W, "queue", e.name .. " is queued twice") end
		names[e.name] = true
		if type(e.priority) ~= "number" or e.priority ~= e.priority then
			return fail(W, "queue", e.name .. " has priority " .. tostring(e.priority))
		end
		if not ns.SafeForMacro and false then return end
		if #e.name > 97 or e.name:find("[%[%]\n\r;|]") then
			return fail(W, "queue", ("%q is not safe for a macro"):format(e.name))
		end
		if e.targetName ~= nil and (type(e.targetName) ~= "string" or e.targetName == "") then
			return fail(W, "queue", e.name .. " has the target name " .. tostring(e.targetName))
		end
		if e.groupCast then
			for _, m in ipairs(e.groupCast.members or {}) do
				if memberOf[m] then return fail(W, "queue", m .. " is in two group casts") end
				memberOf[m] = true
			end
		end
	end
	for name in pairs(memberOf) do
		if names[name] then return fail(W, "queue", name .. " is queued and also covered by a group cast") end
	end

	-- What the settings forbid.
	local pinned = ns.PinnedBuff()
	for _, e in ipairs(queue) do
		local reason = e.reason
		if reason == "owed" and not src.owed then return fail(W, "forbidden", e.name .. " offered as owed with People who buff me off") end
		if reason == "asked" and not src.asked then return fail(W, "forbidden", e.name .. " offered as asked with requests off") end
		if reason == "self" and not src.self then return fail(W, "forbidden", "you are offered with Myself off") end
		if reason == "group" and not src.group then return fail(W, "forbidden", e.name .. " offered as group with Group off") end
		if reason == "nearby" and not src.strangers then return fail(W, "forbidden", e.name .. " offered as nearby with Passers-by off") end
		if reason == "target" then
			if e.inGroup and not src.group then return fail(W, "forbidden", e.name .. " offered as target, in the group, with Group off") end
			if not e.inGroup and not src.strangers then return fail(W, "forbidden", e.name .. " offered as target, a stranger, with Passers-by off") end
		end
		local buff = e.buff
		if not buff.own then
			if db.buff.skip[buff.key] and not (pinned and pinned.key == buff.key) then
				return fail(W, "forbidden", ("%s offered %s, which is switched off"):format(e.name, buff.key))
			end
			if pinned and pinned.key ~= buff.key and reason ~= "self" then
				return fail(W, "forbidden", ("%s offered %s with %s pinned"):format(e.name, buff.key, pinned.key))
			end
			if not ns.IsBuffKnown(buff) then
				return fail(W, "forbidden", ("%s offered %s, which is not learned"):format(e.name, buff.key))
			end
		else
			local pick = db.ownBuffs.pick[buff.family and buff.family.key]
			if pick == "off" then
				return fail(W, "forbidden", ("%s offered %s, whose family is off"):format(e.name, buff.key))
			end
		end
		if reason ~= "owed" and reason ~= "self" then
			if db.never and db.never[e.name] then
				return fail(W, "forbidden", e.name .. " is on the never-offer list and was offered as " .. reason)
			end
		end
		-- Your /ignore list, for everybody outside the group and a favour
		-- owed included (Queue.lua, ns.Ignored); a member of the group stays
		-- offered. Judged by the world's own record, where the client names
		-- the person plainly.
		if reason ~= "self" and not e.inGroup and not W.flaky and not W.secret.all and not W.secret.identity then
			local who = personNamed(W, e.name)
			if who and who ~= W.me and who.ignored == true and not who.grouped then
				return fail(W, "forbidden", e.name .. " is on your ignore list and was offered as " .. reason, nil,
					"somebody on your ignore list was offered")
			end
		end
		if ns.IsBlocked(e.name, buff.key, Mock.now) then
			return fail(W, "forbidden", e.name .. " offered while blocked")
		end
		if e.ranged == false and f.requireInRange then
			return fail(W, "forbidden", e.name .. " offered out of range with Only in range on")
		end

		-- The entry agrees with itself, with the debts and with the world
		-- (where nothing is withheld).
		if reason == "owed" and not (ns.owed[e.name] and ns.DebtExpiry(ns.owed[e.name]) > Mock.now) then
			return fail(W, "consistency", e.name .. " is offered as owed and no live debt stands")
		end
		if reason == "target" and e.unit ~= "target" then
			return fail(W, "consistency", e.name .. " is offered as the target through " .. tostring(e.unit))
		end
		if reason == "self" and e.unit ~= "player" then
			return fail(W, "consistency", "your own entry holds the token " .. tostring(e.unit))
		end
		local open = not (W.secret.all or W.secret.identity or W.flaky)
		local who = e.unit and e.unit ~= "player" and W.resolve(e.unit) or nil
		if who and open then
			if X.filedName(W, who) ~= e.name then
				return fail(W, "consistency", ("%s is filed under %s, whom %s names"):format(
					e.name, tostring(e.unit), X.filedName(W, who)))
			end
			if (reason == "group") ~= (who.grouped == true) and reason ~= "owed" and reason ~= "asked"
				and reason ~= "target" then
				return fail(W, "consistency", ("%s is offered as %s and %s in the group"):format(
					e.name, reason, who.grouped and "is" or "is not"))
			end
			if e.inGroup ~= (who.grouped == true) then
				return fail(W, "consistency", ("%s is %s in the group by the entry and %s by the world"):format(
					e.name, e.inGroup and "marked" or "not marked", who.grouped and "is" or "is not"))
			end
			-- How far they are, by the spell's own range.
			if e.ranged ~= nil and not buff.selfCast and not buff.item then
				local inReach = who.visible == true and who.yards <= 30
				if e.ranged ~= inReach then
					return fail(W, "consistency", ("%s is measured %s of reach at %d yards, visible %s"):format(
						e.name, e.ranged and "in" or "out", who.yards, tostring(who.visible)))
				end
			end
		end
		-- An aura the client keeps back just now is not a buff they lack.
		if e.known == false and not buff.own and e.unit and e.unit ~= "player" and not W.flaky
			and not W.secret.all and (Mock.now - (W.secretAt or -100)) > 3.6 then
			for _, id in ipairs(buff.auraIds) do
				if W.secret.ids[id] or W.secret.hideAll then
					return fail(W, "hidden", ("%s is read as lacking %s while its aura %d is hidden"):format(
						e.name, buff.key, id))
				end
			end
		end
		-- A shout, or a cast that lands on the whole party, is held back for
		-- a flagged member while the rule stands (Queue.lua, LandsOnParty).
		if standing then
			local lands = buff.selfCast
				or (ns.WIDE_CASTS == true and e.inGroup == true and not e.groupCast and not buff.alone and not buff.own)
			local flagged = lands and open and flaggedLander(W)
			if flagged then
				return fail(W, "forbidden", ("%s is offered %s, which lands on %s, flagged for PvP"):format(
					e.name, buff.key, X.filedName(W, flagged)))
			end
		end

		-- Against the world's own truth, for whoever a token still names.
		local p = e.unit and e.unit ~= "player" and W.resolve(e.unit) or nil
		if p and X.filedName(W, p) == e.name and not W.secret.all and not W.flaky then
			local pointed = e.unit == "target" or e.unit == "focus"
			if p.dead then return fail(W, "forbidden", e.name .. " is dead and was offered") end
			if not p.assist then return fail(W, "forbidden", e.name .. " cannot be assisted and was offered") end
			if standing and (p.pvp or p.ffa) and not p.pvpRead then
				return fail(W, "forbidden", e.name .. " is flagged for PvP and was offered while you are not flagged")
			end
			if f.minLevel and f.minLevel > 1 and type(p.level) == "number" and p.level > 0 and p.level < f.minLevel
				and not (W.secret.identity and not p.grouped) then
				return fail(W, "forbidden", ("%s is level %d, under the minimum %d"):format(e.name, p.level, f.minLevel))
			end
			if f.skipSameClass == true and not pointed and (reason == "group" or reason == "nearby")
				and p.class == W.me.class and not buff.selfCast and not buff.talent and not buff.own
				and not (W.secret.identity and not p.grouped) then
				local info = ns.BuffInfo(buff)
				local need = ns.RankLevel(info and info.topRank) or 1
				if p.level >= need then
					return fail(W, "forbidden", ("%s is your own class (level %d, rank needs %d) and was offered %s"):format(
						e.name, p.level, need, buff.key))
				end
			end
			if f.restingOnly == true and reason == "nearby" and not pointed and not W.resting then
				return fail(W, "forbidden", e.name .. " offered as a passer-by out of a city with Only in cities on")
			end
			if W.raid and f.skipRaidGroups and reason == "group" and not pointed and p.subgroup
				and f.skipRaidGroups[p.subgroup] then
				return fail(W, "forbidden", ("%s is in raid group %d, which is switched off"):format(e.name, p.subgroup))
			end
		end
	end
	if not W.failure then X.checkComplete(W, queue, standing) end
	if not W.failure then X.checkRotation(W, queue) end
end

-- ------------------------------------------------------------- the rest

local function deepcopy(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local out = {}
	seen[t] = out
	for k, v in pairs(t) do out[deepcopy(k, seen)] = deepcopy(v, seen) end
	return out
end

local function same(a, b, path, seen)
	if a ~= a and b ~= b then return true end
	if type(a) ~= type(b) then return false, path end
	if type(a) ~= "table" then
		if a == b then return true end
		return false, path
	end
	seen = seen or {}
	if seen[a] then return true end
	seen[a] = true
	for k, v in pairs(a) do
		local ok, where = same(v, b[k], path .. "." .. tostring(k), seen)
		if not ok then return false, where end
	end
	for k in pairs(b) do
		if a[k] == nil then return false, path .. "." .. tostring(k) end
	end
	return true
end

-- Clamping twice is clamping once, tried on a copy so the live profile is
-- left exactly as the addon holds it.
function X.checkClamp(W)
	local ns = W.ns
	local db = ns.db
	if not db or not db.profile then return end
	local live = db.profile
	local ok, err = pcall(function()
		local copy = deepcopy(live)
		db.profile = copy
		local savedLog = ns.repairLog
		ns.repairLog = {}
		ns.ClampSettings()
		local once = deepcopy(copy)
		ns.ClampSettings()
		ns.repairLog = savedLog
		local equal, where = same(once, copy, "profile")
		if not equal then
			error("clamp twice differs from clamp once at " .. tostring(where), 0)
		end
	end)
	db.profile = live
	if not ok then fail(W, "clamp", err) end
end

-- Right after a load: what the clamp made of the file is a fixed point of it
-- (clamp(clamp(x)) = clamp(x), seen from the file the player had).
function X.checkFixedPoint(W)
	local ns = W.ns
	local db = ns and ns.db
	if not db or not db.profile then return end
	local live = db.profile
	local ok, err = pcall(function()
		local copy = deepcopy(live)
		db.profile = copy
		local savedLog = ns.repairLog
		ns.repairLog = {}
		ns.ClampSettings()
		ns.repairLog = savedLog
		local equal, where = same(live, copy, "profile")
		if not equal then
			error("a clamped profile is changed by clamping it again at " .. tostring(where), 0)
		end
	end)
	db.profile = live
	if not ok then fail(W, "clamp", err) end
end

function X.checkTables(W)
	local ns = W.ns
	local now = Mock.now
	-- The tick lets go of a block that has run out.
	for _, expiry in pairs(ns.tried or {}) do
		if expiry <= now - 1 then
			return fail(W, "state", "a block that ran out is still held")
		end
	end
	local passing = 0
	for _ in pairs(ns.passersBy or {}) do passing = passing + 1 end
	if passing > 40 then return fail(W, "state", ("%d passers-by are remembered"):format(passing)) end
	-- The nameplates the addon tracks are the ones the world has up.
	for token in pairs(ns.nameplateUnits or {}) do
		if not W.tok[token] then
			return fail(W, "state", "a nameplate that is gone is still tracked")
		end
	end
	for _, token in ipairs(W.plates) do
		if not ns.nameplateUnits[token] then
			return fail(W, "state", "a nameplate that is up is not tracked")
		end
	end
	local mine = X.filedName(W, W.me)
	for name in pairs(ns.owed or {}) do
		if name == mine then return fail(W, "state", "the player is owed a favour by themselves") end
		if name == "Scarlet Zealot" then return fail(W, "state", "a creature is owed a favour") end
	end
	for name, entry in pairs(ns.owed or {}) do
		if type(name) ~= "string" or type(entry) ~= "table"
			or type(entry.expires) ~= "number" or entry.expires ~= entry.expires
			or type(entry.at) ~= "number" or entry.at ~= entry.at then
			return fail(W, "state", "a debt is malformed: " .. tostring(name))
		end
	end
	if #(ns.errors or {}) > 30 then return fail(W, "state", "the error list is unbounded") end
	-- A parked click is answered, abandoned or swept within moments.
	local pending = ns.pendingClick
	if pending and type(pending.at) == "number" and now - pending.at > 6 then
		return fail(W, "state", ("a click parked %d seconds ago was never settled"):format(now - pending.at))
	end
	-- The tick lets go of a debt that has run out.
	for name, entry in pairs(ns.owed or {}) do
		if ns.DebtExpiry(entry) <= now - 1 then
			return fail(W, "state", "a debt that ran out is still owed: " .. tostring(name))
		end
	end
end

function X.checkAll(W, step)
	local ns = W.ns
	if not ns then return end
	-- An In character box nobody has touched is still In character.
	local speech = ns.db and ns.db.profile and ns.db.profile.speech
	if W.inCharText and speech and speech.presetChoice == "incharacter" and speech.phrases == W.inCharText
		and ns.InCharacter and not ns.InCharacter.Active(speech) then
		return fail(W, "incharacter", "an untouched In character box is no longer recognised as In character")
	end
	if #(ns.errors or {}) > 0 then
		local e = ns.errors[1]
		local first = tostring(e.err):gsub("\n.*", "")
		fail(W, "guarded", ("%s -> %s"):format(tostring(e.where), tostring(e.err)))
		if W.failure then W.failure.sig = signature(W, "guarded", tostring(e.where) .. "|" .. first, true) end
		return
	end
	if Mock.inCombat and #Mock.protectedCalls > 0 then
		return fail(W, "combat", "a protected call in a fight: " .. table.concat(Mock.protectedCalls, ","))
	end
	X.checkMacro(W)
	if W.failure then return end
	if W.failure then return end
	X.checkClamp(W)
	if W.failure then return end
	X.checkTables(W)
end

-- The options window builds, and every control reads and writes.
function X.finalChecks(W)
	local ns = W.ns
	if Mock.inCombat then
		Mock.inCombat = false
		X.fire(W, "PLAYER_REGEN_ENABLED")
	end
	local B, UI = ns.WindowBind, ns.WindowUI
	if not B or not UI then return end
	local function errors(label)
		if #(ns.errors or {}) > 0 then
			local e = ns.errors[1]
			local first = tostring(e.err):gsub("\n.*", "")
			fail(W, "options", ("%s: %s -> %s"):format(label, tostring(e.where), tostring(e.err)))
			if W.failure then W.failure.sig = signature(W, "options", tostring(e.where) .. "|" .. first, true) end
			return true
		end
		return false
	end
	ns.OpenOptions(nil, true)
	if errors("opening the window") then return end
	if ns.OptionsFallback() then return fail(W, "options", "the options window failed to build and fell back") end
	local layout = ns.WindowLayout
	if type(layout) == "table" and type(layout.pages) == "table" then
		local ids = {}
		for id in pairs(layout.pages) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			ns.OpenOptions(id, true)
			if errors("page " .. id) then return end
		end
	end
	for _, path in ipairs(X.controlPaths(W)) do
		local item = B.Item(path, nil, UI.ctx)
		if item then
			local t = item.def.type
			local okAll, err = pcall(function()
				B.Hidden(item) B.Disabled(item) B.Text(item, "name") B.Text(item, "desc")
				if t == "multiselect" then
					for _, pair in ipairs(B.Values(item)) do B.Value(item, pair[1]) end
				elseif t == "select" then
					B.Values(item)
					B.Value(item)
				elseif t ~= "execute" and t ~= "header" and t ~= "description" then
					B.Value(item)
				end
			end)
			if not okAll then return fail(W, "options", path .. " reads with an error: " .. tostring(err)) end
			if not B.Hidden(item) and not B.Disabled(item) and item.def.confirm == nil and item.group.confirm == nil then
				if t == "toggle" or t == "range" or t == "select" or t == "input" then
					local v = B.Value(item)
					if v ~= nil then B.Commit(item, v) end
				elseif t == "color" then
					local r, g, b, a = B.Value(item)
					if r ~= nil then B.Commit(item, r, g, b, a) end
				elseif t == "multiselect" then
					for _, pair in ipairs(B.Values(item)) do
						local v = B.Value(item, pair[1])
						if v ~= nil then B.Commit(item, pair[1], v) end
					end
				end
				if errors("writing " .. path) then return end
			end
		end
	end
	X.checkClamp(W)
end

end
