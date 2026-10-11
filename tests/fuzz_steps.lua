-- What a fuzz step does (see fuzz_world.lua): each op changes the World and
-- fires the events the client would fire for it. An op reads its random
-- numbers from the step (a, b, c in [0,1), d an integer) and the state as it
-- finds it, never from anything an earlier step chose, so any subset of a
-- step list is itself a valid run.
--
-- Loaded by fuzz_world.lua: `dofile(this)(X)`.

return function(X)
local fire, pick = X.fire, X.pick
local OPS, ITEMS = {}, {}

local function def(op, weight, fn, only)
	OPS[op] = fn
	ITEMS[#ITEMS + 1] = { op = op, weight = weight, only = only }
end

function X.menuFor(flavour)
	local items, total = {}, 0
	for _, item in ipairs(ITEMS) do
		if not item.only or item.only(flavour) then
			items[#items + 1] = item
			total = total + item.weight
		end
	end
	return { items = items, total = total }
end

-- Whether a step can name this op (a step is ops joined by +).
function X.isOp(name) return OPS[name] ~= nil end

local function modern(flavour) return flavour == "camelot" or flavour == "mainline" end
local function classic(flavour) return flavour == "vanilla" or flavour == "tbc" or flavour == "mists" end

local function choose(list, r)
	if #list == 0 then return nil end
	return list[math.floor(r * #list) % #list + 1]
end

-- ----------------------------------------------------------------- scene

local function ungrouped(W)
	local out = {}
	for _, p in ipairs(W.people) do
		if not p.grouped then out[#out + 1] = p end
	end
	return out
end

local function aroundPeople(W)
	local out = {}
	for _, p in ipairs(W.people) do
		if p.around then out[#out + 1] = p end
	end
	return out
end

local function members(W)
	local out = {}
	for _, p in ipairs(W.raid or W.party or {}) do
		if p ~= W.me then out[#out + 1] = p end
	end
	return out
end

-- Everyone a token can name, the player aside.
local function others(W)
	local out = {}
	for _, p in ipairs(X.sceneOf(W)) do
		if p ~= W.me then out[#out + 1] = p end
	end
	return out
end

local function tokensOf(W, p)
	local out = {}
	for _, token in ipairs({ "target", "focus", "mouseover" }) do
		if W.tok[token] == p then out[#out + 1] = token end
	end
	for _, token in ipairs(W.plates) do
		if W.tok[token] == p then out[#out + 1] = token end
	end
	for i, q in ipairs(W.party or {}) do
		if q == p then out[#out + 1] = "party" .. i end
	end
	local index = W.raidIndex(p)
	if index then out[#out + 1] = "raid" .. index end
	return out
end
X.tokensOf = tokensOf

local function newAuraId(W)
	W.auraSerial = W.auraSerial + 1
	return W.auraSerial
end

-- ---------------------------------------------------------------- auras

local function addBuff(W, p, spellId, caster, duration)
	duration = duration or 3600
	local entry = { id = newAuraId(W), spellId = spellId, expires = Mock.now + duration,
		duration = duration, caster = caster }
	p.auraAt = Mock.now
	if p == W.me then
		for i, e in ipairs(p.auras) do
			if e.spellId == spellId then table.remove(p.auras, i) break end
		end
		p.auras[#p.auras + 1] = entry
	else
		p.buffOrder = p.buffOrder or {}
		if not p.buffs[spellId] then p.buffOrder[#p.buffOrder + 1] = spellId end
		p.buffs[spellId] = entry
	end
	return entry
end
X.addBuff = addBuff

local function removeBuff(W, p, spellId)
	p.auraAt = Mock.now
	if p == W.me then
		for i, e in ipairs(p.auras) do
			if e.spellId == spellId then table.remove(p.auras, i) return true end
		end
		return false
	end
	if not p.buffs[spellId] then return false end
	p.buffs[spellId] = nil
	for i, id in ipairs(p.buffOrder or {}) do
		if id == spellId then table.remove(p.buffOrder, i) break end
	end
	return true
end

local function clearBuffs(p)
	p.auraAt = Mock.now
	if p.me then
		for i = #p.auras, 1, -1 do p.auras[i] = nil end
	else
		p.buffs, p.buffOrder = {}, {}
	end
end

-- UNIT_AURA for whoever the player can name: a token that holds them, or none.
local function auraEvent(W, p, r)
	if p == W.me then
		fire(W, "UNIT_AURA", W.secret.all and Mock.SECRET or "player")
		return
	end
	local tokens = tokensOf(W, p)
	local token = choose(tokens, r)
	if token then
		-- A restricted payload makes the whole event secret.
		if W.secret.auras and W.secretOK and (math.floor(r * 100) % 3 == 0) then
			fire(W, "UNIT_AURA", Mock.SECRET)
		else
			fire(W, "UNIT_AURA", token)
		end
	end
end

local function allBuffIds(W)
	if W.allIds and W.allIdsNs == W.ns then return W.allIds end
	local ids = {}
	for id in pairs(W.ns.ALL_BUFF_IDS or {}) do ids[#ids + 1] = id end
	table.sort(ids)
	W.allIds, W.allIdsNs = ids, W.ns
	return ids
end

-- Ids that are nobody's buff here, and ids that belong to the other
-- clients' sets (Mists' Legacy of the Emperor, retail's Skyfury, vanilla's
-- ranks and group versions ...).
local JUNK = { 774, 139, 12345, 99999, 1, 8936, 2825,
	115921, 116781, 109773, 57330, 61316, 462854, 364342, 369459, 21562, 1459, 1126, 6673, 2048, 469,
	20217, 25289, 10157, 27126, 27127, 23028, 21564, 25392, 20914, 25918, 27841, 25312 }

-- Some aura id: mostly a class buff of any class, now and then the player's
-- own family, a favour-only one, or a stranger's proc.
local function someSpell(W, r1, r2)
	local ids = allBuffIds(W)
	if r1 < 0.62 and #ids > 0 then return choose(ids, r2) end
	if r1 < 0.78 then
		local own = {}
		for _, entry in ipairs(W.ownSpells or {}) do
			if entry.class == W.me.class and not entry.spell.item then own[#own + 1] = entry end
		end
		local e = choose(own, r2)
		if e then return e.spell.ranks[1] end
	end
	if r1 < 0.86 and type(W.ns.FAVOUR_ONLY_IDS) == "table" then
		local id = choose(W.ns.FAVOUR_ONLY_IDS, r2)
		if id then return id end
	end
	return choose(JUNK, r2)
end

-- The player's own buffs expire on the clock, the others' too; the client
-- tells the player's side of it with UNIT_AURA.
local function expireAuras(W)
	local now = Mock.now
	local changedMe = false
	for i = #W.me.auras, 1, -1 do
		if W.me.auras[i].expires <= now then
			table.remove(W.me.auras, i)
			changedMe = true
		end
	end
	if changedMe then fire(W, "UNIT_AURA", W.secret.all and Mock.SECRET or "player") end
	for _, p in ipairs(W.people) do
		if p.buffOrder and #p.buffOrder > 0 then
			for _, id in ipairs({ unpack(p.buffOrder) }) do
				local b = p.buffs[id]
				if b and b.expires <= now then removeBuff(W, p, id) end
			end
		end
	end
end
X.expireAuras = expireAuras

-- ----------------------------------------------------------------- roster

local function subgroupCount(W, g)
	local n = 0
	for _, p in ipairs(W.raid or {}) do if p.subgroup == g then n = n + 1 end end
	return n
end

local function sortRaid(W)
	if not W.raid then return end
	for i, p in ipairs(W.raid) do p.order = p.order or i end
	table.sort(W.raid, function(a, b)
		if a.subgroup ~= b.subgroup then return a.subgroup < b.subgroup end
		return (a.order or 0) < (b.order or 0)
	end)
end

local function toRaid(W)
	if W.raid then return end
	local list = { W.me }
	W.me.order = 0
	for _, p in ipairs(W.party or {}) do list[#list + 1] = p end
	W.raid = list
	W.party = nil
	for i, p in ipairs(list) do
		p.order = p.order or i
		p.subgroup = 1
	end
	W.me.subgroup = 1
	sortRaid(W)
end

local function arrive(W, p)
	p.around = true
	p.visible = true
end

local function joinGroup(W, p)
	if p.grouped or p.npc then return end
	p.joinedStep = W.stepNo or 0
	arrive(W, p)
	if W.raid then
		if #W.raid >= 40 then return end
		local g = 1
		while g <= 8 and subgroupCount(W, g) >= 5 do g = g + 1 end
		p.subgroup = g > 8 and 8 or g
		p.order = (W.joinSeq or 100) + 1
		W.joinSeq = p.order
		W.raid[#W.raid + 1] = p
		sortRaid(W)
	else
		W.party = W.party or {}
		if #W.party >= 4 then
			toRaid(W)
			joinGroup(W, p)
			return
		end
		W.party[#W.party + 1] = p
	end
	X.retoken(W)
end

local function leaveGroup(W, p)
	for _, list in ipairs({ W.party or {}, W.raid or {} }) do
		for i, q in ipairs(list) do
			if q == p then table.remove(list, i) break end
		end
	end
	if W.party and #W.party == 0 then W.party = nil end
	p.subgroup = nil
	X.retoken(W)
end

-- The client's nameplate comes and goes with an event each way.
local function plateFree(W)
	for k = 1, 40 do
		local token = "nameplate" .. k
		if not W.tok[token] then return token end
	end
	return nil
end

local function plateAdd(W, p, token)
	token = token or plateFree(W)
	if not token or W.tok[token] then return end
	for _, t in ipairs(W.plates) do if W.tok[t] == p then return end end
	W.tok[token] = p
	W.plates[#W.plates + 1] = token
	fire(W, "NAME_PLATE_UNIT_ADDED", token)
end

local function plateRemove(W, token)
	for i, t in ipairs(W.plates) do
		if t == token then table.remove(W.plates, i) break end
	end
	fire(W, "NAME_PLATE_UNIT_REMOVED", token)
	W.tok[token] = nil
end

local function setTarget(W, p)
	if W.tok.target == p then return end
	W.lastTarget = W.tok.target
	W.tok.target = p
	fire(W, "PLAYER_TARGET_CHANGED")
end

-- Somebody leaves the area: nameplates, target and the rest let go of them.
local function depart(W, p)
	p.around = false
	for _, token in ipairs({ unpack(W.plates) }) do
		if W.tok[token] == p then plateRemove(W, token) end
	end
	if W.tok.target == p then
		W.lastTarget = p
		W.tok.target = nil
		fire(W, "PLAYER_TARGET_CHANGED")
	end
	if W.tok.focus == p then W.tok.focus = nil end
	if W.tok.mouseover == p then W.tok.mouseover = nil end
end

-- The people the client would draw, nearest first, for /target <name>.
local function findByName(W, text)
	if type(text) ~= "string" then return nil end
	text = text:lower()
	local best
	for _, p in ipairs(X.sceneOf(W)) do
		if p ~= W.me then
			local full = X.filedName(W, p):lower()
			local first = p.first:lower()
			local short = full:match("^([^%-]+)") or full
			if full == text or short == text or full:sub(1, #text) == text or first == text then
				if p.around or p.grouped then
					if not best or p.yards < best.yards then best = p end
				end
			end
		end
	end
	for _, p in ipairs(W.people) do
		if p.around and not p.grouped then
			local full = X.filedName(W, p):lower()
			local short = full:match("^([^%-]+)") or full
			if full == text or short == text or full:sub(1, #text) == text then
				if not best or p.yards < best.yards then best = p end
			end
		end
	end
	return best
end
X.findByName = findByName

-- ----------------------------------------------------------------- casts

-- A cast of a spell by name at the current target. Returns the outcome: the
-- record of what happened (events to fire after the click, and the effect).
local function castGuid(W)
	W.castSerial = (W.castSerial or 0) + 1
	return ("Cast-3-1-1-1-%d-%08X"):format(W.castSerial, W.castSerial * 2654435761 % 4294967291)
end

local function spellFor(W, name)
	local ns = W.ns
	for _, entry in ipairs(W.classBuffs or {}) do
		if entry.class == W.me.class then
			if entry.name == name then return { kind = "rank", entry = entry } end
			if "Group " .. entry.name == name then return { kind = "group", entry = entry } end
		end
	end
	for _, entry in ipairs(W.ownSpells or {}) do
		if entry.class == W.me.class and not entry.spell.item and entry.name == name then
			return { kind = "own", entry = entry }
		end
	end
	return nil
end

local function topKnown(W, ids)
	for _, id in ipairs(ids) do
		if W.known[id] then return id end
	end
	return nil
end

-- Who a cast lands on besides its target.
local function reach(W, spell, target)
	local ns = W.ns
	local out = { target }
	if spell.kind == "rank" and spell.entry.buff.selfCast then
		out = { W.me }
		local yards = ns.SHOUT_YARDS or 20
		for _, p in ipairs(W.raid or W.party or {}) do
			if p ~= W.me and p.yards <= yards and p.visible and not p.dead then
				local same = true
				if W.raid and ns.PARTY_IS_SUBGROUP then same = p.subgroup == W.me.subgroup end
				if same then out[#out + 1] = p end
			end
		end
		return out
	end
	if spell.kind == "group" then
		out = {}
		local byClass = ns.GROUP_BY_CLASS and ns.GROUP_BY_CLASS[W.me.class]
		for _, p in ipairs(W.raid or W.party or {}) do
			if p ~= W.me and not p.dead and p.visible then
				local inside = true
				if byClass then inside = p.class == target.class
				elseif W.raid and not ns.GROUP_IS_RAID then inside = p.subgroup == target.subgroup end
				if inside then out[#out + 1] = p end
			end
		end
		out[#out + 1] = W.me
		return out
	end
	if spell.kind == "rank" and ns.WIDE_CASTS and target.grouped and not spell.entry.buff.alone then
		out = {}
		for _, p in ipairs(W.raid or W.party or {}) do
			if not p.dead and p.visible then out[#out + 1] = p end
		end
		out[#out + 1] = W.me
	end
	return out
end

-- One /cast as the secure handler does it: the outcome, with the events the
-- client sends for it appended to `events`.
local function castSpell(W, name, events)
	local ns = W.ns
	local spell = spellFor(W, name)
	if not spell then
		events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "That spell is not available." }
		return "unknown"
	end
	local id
	if spell.kind == "rank" then id = topKnown(W, spell.entry.buff.ranks)
	elseif spell.kind == "group" then
		for _, rank in ipairs(spell.entry.buff.groupCast or {}) do
			if W.known[rank.id] then id = rank.id break end
		end
	else id = topKnown(W, spell.entry.spell.ranks) end
	if not id then
		events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "Spell not learned." }
		return "unlearned"
	end
	local now = Mock.now
	local target = W.tok.target
	local self_ = spell.kind == "own" or (spell.kind == "rank" and spell.entry.buff.selfCast)
	if self_ then
		target = W.me
	elseif not target or target.npc or not target.assist then
		-- A buff cast at nobody friendly lands on yourself.
		target = W.me
	end
	if W.me.dead then
		events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "You can't do that while dead." }
		return "dead"
	end
	-- A cast made in the last stretch of the global cooldown (the spell queue
	-- window) is held by the client and sent when the cooldown ends.
	local window = (tonumber(W.cvars.SpellQueueWindow) or 400) / 1000
	local left = W.gcdEnds - now
	if left > window then
		events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "Spell is not ready yet." }
		return "cooldown"
	end
	local queued = left > 0 and left or nil
	if W.flying then
		events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "You are mounted." }
		return "mounted"
	end
	if W.me.mana <= 0.02 and not self_ then
		events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "Not enough mana." }
		return "mana"
	end
	if not self_ and target ~= W.me then
		if target.dead then
			events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "Target is dead." }
			return "dead target"
		end
		if not target.visible or target.yards > 30 then
			events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "Out of range." }
			return "range"
		end
	end
	if spell.kind == "group" then
		local reagent = W.reagentFor and W.reagentFor[id]
		if reagent and (W.bags[reagent] or 0) <= 0 and not (W.ns.ReagentWaived and false) then
			events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "Missing reagent." }
			return "reagent"
		end
	end
	-- A stronger rank already there (the ranks are listed highest first).
	if spell.kind == "rank" then
		local ranks = spell.entry.buff.ranks
		local mine
		for j, r in ipairs(ranks) do if r == id then mine = j end end
		for i = 1, (mine or 1) - 1 do
			for _, entry in ipairs(W.listFor(target)) do
				if entry.spellId == ranks[i] then
					events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "A more powerful spell is already active." }
					return "stronger"
				end
			end
		end
	end
	local guid = castGuid(W)
	local aimed = target
	local aimedName = "Mort"
	if aimed ~= W.me then
		-- The name as /target spells it: the surname on Forever, the bare
		-- name elsewhere.
		aimedName = aimed.first
		if W.surnames and aimed.surname then aimedName = aimed.first .. " " .. aimed.surname end
	end
	events.aimed = aimed
	events[#events + 1] = { "UNIT_SPELLCAST_SENT", "player", aimedName, guid, id }
	-- The client has sent it: whatever was asked for in chat is answered (a
	-- refusal after that does not put it back, Requests.lua, ServeRequest).
	if W.reqs and spell.kind ~= "own" and spell.entry.buff then
		for _, p in ipairs(reach(W, spell, aimed)) do
			local name = X.filedName(W, p)
			local req = W.reqs[name]
			if req and req.key == spell.entry.buff.key then W.reqs[name] = nil end
		end
		-- The game names the target by the name alone, so a cast at somebody
		-- answers the request of anyone who goes by it (two realms, one name).
		local sent = {}
		for name, req in pairs(W.reqs) do
			local asker = req.person
			local askerSent = W.surnames and asker.surname and (asker.first .. " " .. asker.surname) or asker.first
			if req.key == spell.entry.buff.key and askerSent == aimedName then sent[#sent + 1] = name end
		end
		for _, name in ipairs(sent) do W.reqs[name] = nil end
	end
	-- A late refusal by the server after the client sent it.
	local roll = (W.stepNo or 0) * 0.6180339 % 1
	if roll < 0.06 and W.lateRefusals then
		events[#events + 1] = { "UNIT_SPELLCAST_FAILED", "player", guid, id }
		events.late = true
		return "late refusal"
	end
	events[#events + 1] = { "UNIT_SPELLCAST_SUCCEEDED", "player", guid, id }
	events.ok = true
	events.delay = queued
	W.gcdStart, W.gcdEnds = now + (queued or 0), now + (queued or 0) + 1.5
	-- The effect, applied after the events (the aura lands a moment later).
	events.landing = function()
		if spell.kind == "group" then
			for _, rank in ipairs(spell.entry.buff.groupCast or {}) do
				if rank.id == id and W.reagentFor and not (W.ns.ReagentWaived and false) then
					W.bags[rank.reagent] = math.max(0, (W.bags[rank.reagent] or 0) - 1)
				end
			end
		end
		local auraId = id
		for _, p in ipairs(reach(W, spell, aimed)) do
			addBuff(W, p, auraId, W.me, 3600)
			auraEvent(W, p, 0.1)
			-- The request they made for it is answered.
			local req = W.reqs and W.reqs[X.filedName(W, p)]
			if req and spell.kind ~= "own" and spell.entry.buff and spell.entry.buff.key == req.key then
				W.reqs[X.filedName(W, p)] = nil
			end
		end
	end
	if W.me.mana then W.me.mana = math.max(0, W.me.mana - 0.04) end
	return "ok"
end
X.castSpell = castSpell

-- The secure handler running a macro: /target, /cast, /use, the hand-back,
-- and whatever else is a spoken line.
local function runMacro(W, text, events)
	local spoken = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local cmd, rest = line:match("^/(%S+)%s*(.*)$")
		cmd = cmd and cmd:lower() or nil
		if cmd == "target" then
			local p = findByName(W, rest)
			if p then setTarget(W, p) end
		elseif cmd == "targetlasttarget" then
			if W.lastTarget and (W.lastTarget.around or W.lastTarget.grouped) then
				local was = W.tok.target
				W.tok.target = W.lastTarget
				W.lastTarget = was
				fire(W, "PLAYER_TARGET_CHANGED")
			end
		elseif cmd == "cast" then
			castSpell(W, rest, events)
		elseif cmd == "use" then
			local item = rest:match("^item:(%d+)$")
			if item then
				item = tonumber(item)
				if (W.bags[item] or 0) > 0 then
					W.bags[item] = W.bags[item] - 1
					for _, entry in ipairs(W.ownSpells or {}) do
						if entry.spell.item == item then
							local guid = castGuid(W)
							local id = entry.spell.ranks[1]
							events[#events + 1] = { "UNIT_SPELLCAST_SENT", "player", "Mort", guid, id }
							events[#events + 1] = { "UNIT_SPELLCAST_SUCCEEDED", "player", guid, id }
							events.landing = function()
								addBuff(W, W.me, id, W.me, 3600)
								auraEvent(W, W.me, 0.1)
							end
						end
					end
				else
					events[#events + 1] = { "UI_ERROR_MESSAGE", 0, "Item is gone." }
				end
			end
		elseif cmd then
			spoken[#spoken + 1] = line
		end
	end
	for _, line in ipairs(spoken) do W.spoken[#W.spoken + 1] = { step = W.stepNo, line = line } end
	return spoken
end
X.runMacro = runMacro

local function deliver(W, events)
	for _, e in ipairs(events) do fire(W, e[1], unpack(e, 2)) end
	if events.landing then events.landing() end
end

-- ------------------------------------------------------------------- ops

def("tick", 24, function() end)
def("wait", 3, function() end)

-- Roster.
def("join_party", 5, function(W, s)
	local p = choose(ungrouped(W), s.a)
	if p then joinGroup(W, p) end
end)
def("join_raid", 3, function(W, s)
	toRaid(W)
	for k = 1, 1 + math.floor(s.b * 8) do
		local p = choose(ungrouped(W), (s.a + k * 0.37) % 1)
		if p then joinGroup(W, p) end
	end
end)
def("leave_group", 4, function(W, s)
	local p = choose(members(W), s.a)
	if p then leaveGroup(W, p) end
end)
def("disband", 1, function(W)
	W.party, W.raid = nil, nil
	W.me.subgroup = nil
	X.retoken(W)
end)
def("shuffle_group", 2, function(W, s)
	local list = W.raid or W.party
	if not list or #list < 2 then return end
	local i = 1 + math.floor(s.a * #list)
	local j = 1 + math.floor(s.b * #list)
	if W.raid then
		-- Swap two raiders' places (subgroups), keeping the player in the raid.
		local x, y = list[i], list[j]
		if x ~= y then x.subgroup, y.subgroup = y.subgroup, x.subgroup x.order, y.order = y.order, x.order end
		sortRaid(W)
	else
		list[i], list[j] = list[j], list[i]
	end
	X.retoken(W)
end)
def("move_subgroup", 2, function(W, s)
	if not W.raid then return end
	local p = choose(W.raid, s.a)
	local g = 1 + math.floor(s.b * 8)
	if p and subgroupCount(W, g) < 5 then
		p.subgroup = g
		sortRaid(W)
		X.retoken(W)
	end
end)
def("party_to_raid", 1, function(W) toRaid(W) X.retoken(W) end)
def("raid_to_party", 1, function(W)
	if not W.raid or #W.raid > 5 then return end
	local list = {}
	for _, p in ipairs(W.raid) do if p ~= W.me then list[#list + 1] = p end end
	W.raid = nil
	W.party = #list > 0 and list or nil
	X.retoken(W)
end)
def("member_far", 3, function(W, s)
	local p = choose(members(W), s.a)
	if not p then return end
	if s.b < 0.4 then p.visible = false
	elseif s.b < 0.7 then p.visible = true p.yards = 3 + math.floor(s.c * 25)
	else p.visible = true p.yards = 35 + math.floor(s.c * 120) end
end)

-- People in the area.
def("arrive", 5, function(W, s)
	local p = choose(ungrouped(W), s.a)
	if p then
		arrive(W, p)
		p.yards = 2 + math.floor(s.b * 45)
		p.pvp = s.c < 0.12
	end
end)
def("depart", 4, function(W, s)
	local p = choose(aroundPeople(W), s.a)
	if p and not p.grouped then depart(W, p) end
end)
def("walk", 6, function(W, s)
	local list = aroundPeople(W)
	local p = choose(list, s.a)
	if p then p.yards = math.max(1, math.floor(s.b * 70)) end
end)
def("level_change", 1, function(W, s)
	local p = choose(aroundPeople(W), s.a)
	if p then p.level = 1 + math.floor(s.b * W.cap) end
end)

-- Nameplates.
def("plate_add", 6, function(W, s)
	local pool = {}
	for _, p in ipairs(aroundPeople(W)) do pool[#pool + 1] = p end
	for _, p in ipairs(W.mobs) do pool[#pool + 1] = p end
	local p = choose(pool, s.a)
	if p then
		if p.npc then p.around = true end
		plateAdd(W, p)
	end
end)
def("plate_remove", 5, function(W, s)
	local token = choose(W.plates, s.a)
	if token then plateRemove(W, token) end
end)
def("plate_recycle", 3, function(W, s)
	local token = choose(W.plates, s.a)
	if not token then return end
	local pool = aroundPeople(W)
	local p = choose(pool, s.b)
	plateRemove(W, token)
	if p then
		W.tok[token] = nil
		for _, t in ipairs(W.plates) do if W.tok[t] == p then return end end
		W.tok[token] = p
		W.plates[#W.plates + 1] = token
		fire(W, "NAME_PLATE_UNIT_ADDED", token)
	end
end)
def("plate_swap", 2, function(W, s)
	if #W.plates < 2 then return end
	local t1 = choose(W.plates, s.a)
	local t2 = choose(W.plates, s.b)
	if t1 == t2 then return end
	local p1, p2 = W.tok[t1], W.tok[t2]
	plateRemove(W, t1)
	plateRemove(W, t2)
	W.tok[t1], W.tok[t2] = p2, p1
	W.plates[#W.plates + 1] = t1
	W.plates[#W.plates + 1] = t2
	fire(W, "NAME_PLATE_UNIT_ADDED", t1)
	fire(W, "NAME_PLATE_UNIT_ADDED", t2)
end)

-- Target, mouseover, focus.
def("target_set", 6, function(W, s)
	local pool = others(W)
	for _, p in ipairs(aroundPeople(W)) do pool[#pool + 1] = p end
	local p = choose(pool, s.a)
	if p then setTarget(W, p) end
end)
def("target_clear", 3, function(W)
	if W.tok.target then
		W.lastTarget = W.tok.target
		W.tok.target = nil
		fire(W, "PLAYER_TARGET_CHANGED")
	end
end)
def("target_self", 1, function(W) setTarget(W, W.me) end)
def("mouseover_set", 5, function(W, s)
	local pool = others(W)
	for _, p in ipairs(aroundPeople(W)) do pool[#pool + 1] = p end
	W.tok.mouseover = choose(pool, s.a)
end)
def("mouseover_clear", 3, function(W) W.tok.mouseover = nil end)
def("focus_set", 2, function(W, s)
	W.tok.focus = choose(others(W), s.a)
end)
def("focus_clear", 1, function(W) W.tok.focus = nil end)

-- The player's own auras.
def("aura_me_add", 8, function(W, s)
	local id = someSpell(W, s.a, s.b)
	if not id then return end
	local casters = others(W)
	local caster
	if s.c < 0.55 then caster = choose(casters, s.b)
	elseif s.c < 0.7 then caster = W.me
	elseif s.c < 0.85 then caster = choose(aroundPeople(W), s.a) end
	addBuff(W, W.me, id, caster, s.d % 3 == 0 and 120 or 3600)
	fire(W, "UNIT_AURA", W.secret.all and Mock.SECRET or "player")
end)
def("aura_me_remove", 5, function(W, s)
	local e = choose(W.me.auras, s.a)
	if e then
		removeBuff(W, W.me, e.spellId)
		fire(W, "UNIT_AURA", "player")
	end
end)
def("aura_me_refresh", 3, function(W, s)
	local e = choose(W.me.auras, s.a)
	if not e then return end
	if s.b < 0.5 then
		-- Recast: a new number for the same spell.
		addBuff(W, W.me, e.spellId, e.caster, 3600)
	else
		e.expires = Mock.now + 3600
	end
	fire(W, "UNIT_AURA", "player")
end)
def("aura_renumber", 1, function(W)
	for _, e in ipairs(W.me.auras) do e.id = newAuraId(W) end
	fire(W, "UNIT_AURA", "player")
end)
def("aura_other_add", 8, function(W, s)
	local p = choose(others(W), s.a)
	if not p then return end
	local id = someSpell(W, s.b, s.c)
	if not id then return end
	local caster = choose(others(W), (s.a + s.b) % 1)
	if s.d % 5 == 0 then caster = nil end
	addBuff(W, p, id, caster, 3600)
	auraEvent(W, p, s.c)
end)
def("aura_other_remove", 4, function(W, s)
	local p = choose(others(W), s.a)
	if p and p.buffOrder and #p.buffOrder > 0 then
		removeBuff(W, p, choose(p.buffOrder, s.b))
		auraEvent(W, p, s.c)
	end
end)
def("aura_noise", 4, function(W, s)
	local tokens = { "player", "target", "focus", "mouseover", "nameplate1", "nameplate7", "party1",
		"party4", "raid3", "raid40", "boss1", "arena1", "pet", "vehicle", "" }
	local token = choose(tokens, s.a)
	if W.secretOK and s.b < 0.25 then token = Mock.SECRET end
	if s.b > 0.9 then token = nil end
	fire(W, "UNIT_AURA", token)
end)

-- Death.
def("die_me", 2, function(W, s)
	W.decay.die = W.stepNo + 6
	W.me.dead = true
	clearBuffs(W.me)
	fire(W, "PLAYER_DEAD")
	fire(W, "UNIT_AURA", "player")
end)
def("release", 1, function(W)
	if W.me.dead then W.me.ghost = true end
end)
def("revive_me", 2, function(W)
	if not (W.me.dead or W.me.ghost) then return end
	local ghost = W.me.ghost
	W.me.dead, W.me.ghost = false, false
	fire(W, ghost and "PLAYER_UNGHOST" or "PLAYER_ALIVE")
	fire(W, "PLAYER_ALIVE")
end)
def("die_other", 3, function(W, s)
	local p = choose(others(W), s.a)
	if p and not p.npc then
		if not p.dead then p.deadStep, p.deadFeign = W.stepNo, p.feign end
		p.dead = true
		clearBuffs(p)
		auraEvent(W, p, s.b)
	end
end)
def("revive_other", 3, function(W, s)
	local list = {}
	for _, p in ipairs(others(W)) do if p.dead then list[#list + 1] = p end end
	local p = choose(list, s.a)
	if p then
		p.dead, p.feign, p.ghost = false, false, false
		auraEvent(W, p, s.b)
	end
end)
-- Somebody in the group dies and is raised again where they stand, a scan
-- apart: the one way the group's death watch sees a raise.
def("raise_member", 3, function(W, s)
	local list, near = {}, {}
	for _, p in ipairs(members(W)) do
		if not p.dead and not p.ghost and not p.npc then
			list[#list + 1] = p
			if p.visible and p.yards <= 28 then near[#near + 1] = p end
		end
	end
	-- With nobody to raise, somebody joins first; and the one raised is
	-- mostly one the raise can matter for, in reach, not a stranger to it.
	if #list == 0 then
		local walkers = {}
		for _, q in ipairs(ungrouped(W)) do
			if not q.npc and not q.dead and not q.ghost and q.connected then walkers[#walkers + 1] = q end
		end
		local q = choose(walkers, s.c)
		if not q then return end
		joinGroup(W, q)
		q.yards = 3 + math.floor(s.b * 22)
		list, near = { q }, { q }
	end
	local p = choose((#near > 0 and s.d % 4 ~= 0) and near or list, s.a)
	if not p then return end
	p.deadStep, p.deadFeign = W.stepNo, p.feign
	p.dead = true
	clearBuffs(p)
	auraEvent(W, p, s.b)
	if not X.tick(W, 0.5) then return end
	p.dead, p.feign, p.ghost = false, false, false
	auraEvent(W, p, s.b)
end)
def("feign", 2, function(W, s)
	local list = {}
	for _, p in ipairs(others(W)) do
		if p.class == "HUNTER" and not p.npc and not p.dead then list[#list + 1] = p end
	end
	local p = choose(list, s.a)
	if p then p.feign, p.dead = true, true end
end)

-- What the client withholds, by the roll r: nothing, everything, the
-- identity of strangers, the auras in one of several shapes. A fight turns
-- it on and the fight's end off on the clients that do (W.secretCombat).
local function applySecrets(W, r, b)
	local sec = W.secret
	W.secretAt = Mock.now
	sec.all, sec.identity, sec.auras, sec.aura, sec.fields = false, false, false, "open", false
	sec.ids = {}
	sec.hideAll = false
	if r < 0.2 then return end -- restrictions off
	if r < 0.35 then sec.all = true sec.auras = true
	elseif r < 0.5 then sec.identity = true
	elseif r < 0.62 then sec.auras = true sec.aura = "whole"
	elseif r < 0.72 then sec.auras = true sec.aura = "throw"
	elseif r < 0.8 then sec.auras = true sec.fields = true
	elseif r < 0.9 then sec.auras = true sec.aura = "hidden"
	elseif r >= 0.88 then
		-- Every aura of anybody else kept back: nothing about them can be read.
		sec.auras, sec.hideAll = true, true
	else
		sec.identity, sec.auras = true, true
		for k = 1, 3 do
			local id = choose(allBuffIds(W), (b + k * 0.31) % 1)
			if id then sec.ids[id] = true end
		end
	end
end

-- Combat: the event arrives before the lockdown, as in the client.
def("combat_start", 3, function(W, s)
	if Mock.inCombat then return end
	if W.me.dead then return end
	fire(W, "PLAYER_REGEN_DISABLED")
	Mock.inCombat = true
	W.reqs = {}
	if W.secretCombat then applySecrets(W, 0.2 + s.a * 0.8, s.b) end
	Mock.runTimers(0)
end)
def("combat_end", 4, function(W)
	if not Mock.inCombat then return end
	Mock.inCombat = false
	if W.secretCombat then applySecrets(W, 0, 0) end
	fire(W, "PLAYER_REGEN_ENABLED")
end)

-- A fight's worth of aura events in one go: the player's and everybody's, with
-- the player's own list changing between them.
def("aura_storm", 3, function(W, s)
	local scene = X.sceneOf(W)
	local n = 15 + math.floor(s.a * 45)
	for k = 1, n do
		local r = (s.b + k * 0.137) % 1
		if r < 0.35 then
			if k % 7 == 0 then
				local id = someSpell(W, r, (s.c + k * 0.071) % 1)
				if id then addBuff(W, W.me, id, choose(others(W), r), 3600) end
			end
			fire(W, "UNIT_AURA", "player")
		else
			local p = choose(scene, r)
			if p then auraEvent(W, p, (s.c + k * 0.19) % 1) end
		end
	end
end)

-- PvP flags.
def("pvp_other", 4, function(W, s)
	local p = choose(others(W), s.a)
	if p and not p.npc then p.pvp = not p.pvp end
end)
def("pvp_me", 3, function(W, s)
	if s.a < 0.4 then
		W.me.pvp = not W.me.pvp
		W.pvpTimer = not W.me.pvp and s.b < 0.5
	elseif s.a < 0.6 then W.me.ffa = not W.me.ffa
	else W.pvpTimer = not W.pvpTimer end
end)
def("pvp_unreadable", 1, function(W, s)
	local p = choose(others(W), s.a)
	if p then
		-- A flag the game will not show. (A read that throws is a client
		-- fault the addon names by design: tests/scenarios/pvp.lua.)
		p.pvpRead = s.b < 0.5 and "secret" or nil
	end
end)

-- Chat.
local ASKS = {
	"int pls", "fort?", "can I get motw", "buffs please", "any mage for int?", "bitte int", "kings pls",
	"need buff", "buff", "stam", "bok pls", "gotw", "pwf pls", "thorns plz", "who has int?", "mark pls",
	"int", "no buff pls", "thanks for the int", "arcane intellect please", "battle shout pls",
	"sal pls", "might pls", "wisdom?", "any priest for fort", "s'il vous pla\195\174t int",
	"por favor int", "\232\175\183\231\187\153\230\136\145\230\153\186\230\133\167", "buff \237\150\136\236\163\188\236\132\184\236\232\148",
	"legacy pls", "skyfury pls", "bronze pls", "dark intent pls", "horn pls", "source of magic pls",
}
-- The one request per class that is plainly a request: the nickname of the
-- buff and a please.
local KNOWN_ASK = {
	MAGE = { text = "int pls", key = "intellect" },
	PRIEST = { text = "fort pls", key = "fortitude" },
	DRUID = { text = "motw pls", key = "motw" },
}
local CLASS_ASKS = {
	MAGE = { "int pls", "intellect please", "can i get int", "brilliance?", "ai pls", "int" },
	PRIEST = { "fort pls", "stam?", "pwf please", "spirit pls", "shadow prot pls", "prayer of fortitude" },
	DRUID = { "motw pls", "gotw?", "mark of the wild please", "thorns pls" },
	PALADIN = { "kings pls", "bok", "bom pls", "wisdom please", "salv pls", "sanc pls", "might?" },
	WARRIOR = { "battle shout pls", "shout pls" },
	WARLOCK = { "ub pls", "breath please", "dark intent pls" },
	SHAMAN = { "skyfury pls" }, EVOKER = { "bronze pls", "source of magic pls" },
	MONK = { "legacy pls", "white tiger pls" }, DEATHKNIGHT = { "horn pls" },
}
-- A line said in a channel by somebody, and the world's note of what the addon
-- ought to make of it. `clean` keeps the line as it is, with the sender's guid.
local function sayAsk(W, p, channel, text, s, clean)
	local second = W.surnames and p.surname or (p.crossRealm and p.realm or nil)
	local forms = { p.first }
	if second then
		forms[2] = p.first .. (W.surnames and " " or "-") .. second
		forms[3] = p.first .. "-" .. (p.crossRealm and p.realm or "Ravencrest")
	end
	local sender = choose(forms, s.d / 1000000)
	W.askedAt = W.askedAt or {}
	W.askedAt[X.filedName(W, p)] = Mock.now
	-- A sender spelled with the first name alone may be taken for anyone who
	-- shares it.
	for _, other in ipairs(W.people) do
		if other.first == p.first then W.askedAt[X.filedName(W, other)] = Mock.now end
	end
	local guid = (s.d % 11 == 0 and not clean) and "" or p.guid
	local line = (s.d % 13 == 0) and 0 or 1
	if W.secretOK and W.secret.all and s.d % 3 == 0 and not clean then text = Mock.SECRET end
	if W.secretOK and W.secret.all and s.d % 3 == 1 and not clean then sender = Mock.SECRET end
	fire(W, "CHAT_MSG_" .. channel, text, sender, "", "", sender, "", 0, 0, "", 0, 1, guid)
	-- A request nobody could misread: the buff's nickname and a please, from
	-- somebody the addon can tell by their guid, out of a fight.
	local plain_ask = KNOWN_ASK[W.me.class]
	if plain_ask and text == plain_ask.text then W.stats.reqTried = (W.stats.reqTried or 0) + 1 end
	if plain_ask and text == plain_ask.text and guid ~= "" and not Mock.inCombat
		and sender ~= Mock.SECRET and p.class ~= W.me.class and not p.npc then
		local db = W.ns.db.profile
		local buff
		for _, e in ipairs(W.classBuffs or {}) do
			if e.class == W.me.class and e.buff.key == plain_ask.key then buff = e.buff end
		end
		local known = false
		for _, id in ipairs(buff and buff.ranks or {}) do if W.known[id] then known = true end end
		local pin = W.ns.PinnedBuff()
		if buff and known and db.enabled and db.sources.asked and not db.buff.skip[buff.key]
			and (not pin or pin.key == buff.key) then
			W.stats.reqRecorded = (W.stats.reqRecorded or 0) + 1
			W.reqs = W.reqs or {}
			W.reqs[X.filedName(W, p)] = { person = p, key = buff.key, buff = buff, at = Mock.now,
				["until"] = Mock.now + 60 }
		end
	end
end

def("chat", 10, function(W, s)
	local channels = { "SAY", "YELL", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "INSTANCE_CHAT",
		"INSTANCE_CHAT_LEADER", "WHISPER" }
	local channel = choose(channels, s.a)
	local pool = others(W)
	-- Mostly somebody the addon can see; now and then anyone about.
	if s.d % 10 < 3 then
		for _, p in ipairs(aroundPeople(W)) do pool[#pool + 1] = p end
	end
	local p = choose(pool, s.b)
	if s.d % 7 == 0 and W.flavour ~= "camelot" then
		local twins = {}
		for k = 1, 4 do twins[#twins + 1] = W.people[k] twins[#twins + 1] = W.people[40 + k] end
		p = choose(twins, s.b)
	end
	if not p or p.npc then return end
	local text = choose(ASKS, s.c)
	if s.d % 10 < 5 and KNOWN_ASK[W.me.class] then text = KNOWN_ASK[W.me.class].text end
	-- Mostly what somebody would ask this class for.
	if s.d % 3 ~= 0 and s.d % 10 >= 5 then
		local mine = CLASS_ASKS[W.me.class]
		if mine then text = choose(mine, s.c) end
	end
	-- Now and then the spell's own name as this client has it.
	if s.d % 7 == 0 then
		local names = {}
		for _, e in ipairs(W.classBuffs or {}) do
			if e.class == W.me.class then names[#names + 1] = e.name end
		end
		local n = choose(names, s.a)
		if n then text = n .. " pls" end
	end
	sayAsk(W, p, channel, text, s)
end)
-- A request nobody could misread ("int pls") from somebody standing in reach,
-- the line as it is and the guid with it: what the asked-for check judges, and
-- all it needs together is too rare to be left to a chance meeting of the
-- chat step and a person in reach. With nobody near, somebody walks up first.
def("ask_plain", 6, function(W, s)
	if not KNOWN_ASK[W.me.class] or Mock.inCombat or W.me.dead or W.me.ghost then return end
	-- Reading chat is off until a player turns it on, which a fresh profile
	-- has not: the player switches it on in the options window first.
	local ns = W.ns
	local B, UI = ns.WindowBind, ns.WindowUI
	if ns.db.profile.sources.asked ~= true and B and UI then
		if not UI.Shown() then ns.OpenOptions(nil, true) end
		local item = B.Item("who.asked", nil, UI.ctx)
		if item and not B.Hidden(item) and not B.Disabled(item) then B.Commit(item, true) end
	end
	local ask = KNOWN_ASK[W.me.class]
	local buff
	for _, e in ipairs(W.classBuffs or {}) do
		if e.class == W.me.class and e.buff.key == ask.key then buff = e.buff end
	end
	-- Somebody who asks for a buff lacks it.
	local function lacks(p)
		for _, id in ipairs(buff and buff.auraIds or {}) do
			if p.buffs[id] then return false end
		end
		return true
	end
	local function fit(p)
		return not p.npc and not p.dead and not p.ghost and p.connected and p.assist ~= false
			and p.class ~= W.me.class and (p.grouped or not p.ignored) and lacks(p)
	end
	local pool = {}
	for _, p in ipairs(others(W)) do
		if fit(p) and p.visible and p.yards <= 28 then pool[#pool + 1] = p end
	end
	local p = choose(pool, s.a)
	if not p then
		local walkers = {}
		for _, q in ipairs(ungrouped(W)) do
			if fit(q) then walkers[#walkers + 1] = q end
		end
		p = choose(walkers, s.a)
		if not p then return end
		arrive(W, p)
		p.yards = 3 + math.floor(s.b * 22)
		plateAdd(W, p)
	end
	local channels = p.grouped and { "PARTY", "RAID", "WHISPER" } or { "SAY", "YELL", "WHISPER" }
	sayAsk(W, p, choose(channels, s.c), ask.text, s, true)
end)
-- The player puts somebody about on the ignore list, or takes them off it.
def("ignore", 2, function(W, s)
	local pool = others(W)
	for _, p in ipairs(aroundPeople(W)) do pool[#pool + 1] = p end
	local p = choose(pool, s.a)
	if not p or p.npc then return end
	p.ignored = s.b < 0.7 or nil
end)
def("chat_me", 1, function(W, s)
	local text = choose(ASKS, s.a)
	fire(W, "CHAT_MSG_SAY", text, "Mort", "", "", "Mort", "", 0, 0, "", 0, 1, W.me.guid)
end)
-- A message from the combat log, on the clients that have one.
def("cleu", 5, function(W, s)
	if not Mock.combatLog then return end
	local p = choose(others(W), s.a)
	if not p then return end
	local id = someSpell(W, s.b, s.c)
	Mock.cleu = {
		subevent = (s.d % 6 == 0) and "SPELL_AURA_REFRESH" or "SPELL_AURA_APPLIED",
		sourceGUID = p.guid, sourceName = p.first, destGUID = W.me.guid, destName = "Mort",
		spellId = id, spellName = W.names[id] or "x",
		auraType = (s.d % 9 == 0) and "DEBUFF" or "BUFF",
	}
	if s.d % 4 == 0 then
		-- The aura the log line describes is on the player a moment later.
		addBuff(W, W.me, id, p, 3600)
		fire(W, "COMBAT_LOG_EVENT_UNFILTERED")
		fire(W, "UNIT_AURA", "player")
	else
		fire(W, "COMBAT_LOG_EVENT_UNFILTERED")
		addBuff(W, W.me, id, p, 3600)
		fire(W, "UNIT_AURA", "player")
	end
end, classic)

-- Environment.
def("mount", 2, function(W, s)
	W.mounted = not W.mounted
	if not W.mounted then W.flying = false end
	if W.mounted and s.a < 0.3 then W.flying = true end
end)
def("fly", 1, function(W) W.flying = W.mounted and not W.flying end)
def("stealth", 1, function(W) W.stealthed = not W.stealthed end)
def("taxi", 1, function(W) W.onTaxi = not W.onTaxi W.decay.taxi = W.stepNo + 3 end)
def("vehicle", 1, function(W) W.inVehicle = not W.inVehicle W.decay.vehicle = W.stepNo + 3 end)
def("charm", 1, function(W) W.charmed = not W.charmed W.decay.charm = W.stepNo + 3 end)
def("rest", 2, function(W) W.resting = not W.resting end)
def("instance", 2, function(W, s)
	local kinds = { false, "party", "raid", "pvp", "arena" }
	local k = kinds[1 + math.floor(s.a * 5) % 5]
	W.inInstance = k or nil
end)
def("shapeshift", 2, function(W, s)
	if W.forms <= 0 then return end
	-- The aura the form is: one at a time, none for form zero.
	for _, id in ipairs(W.formSpells) do removeBuff(W, W.me, id) end
	W.form = math.floor(s.a * (W.forms + 1))
	if W.form > 0 then addBuff(W, W.me, W.formSpells[W.form], W.me, 3600) end
	fire(W, "UNIT_AURA", "player")
end)
def("role", 1, function(W, s)
	W.roles.player = choose({ "TANK", "HEALER", "DAMAGER", "NONE" }, s.a)
end)
def("mana", 3, function(W, s)
	local r = s.a
	if r < 0.2 then W.me.mana = 0 elseif r < 0.5 then W.me.mana = 0.1 + s.b * 0.5 else W.me.mana = 0.5 + s.b * 0.5 end
	for _, p in ipairs(W.people) do p.mana = s.c end
end)
def("shift_key", 1, function(W) W.shift = not W.shift end)
def("friendly_plates", 1, function(W, s)
	local v = s.a < 0.5 and "0" or "1"
	W.cvars.nameplateShowFriendlyPlayers, W.cvars.nameplateShowFriends = v, v
end)
def("zone", 2, function(W, s)
	-- A loading screen: numbers renumbered, nameplates cleared and drawn again.
	for _, e in ipairs(W.me.auras) do e.id = newAuraId(W) end
	for _, token in ipairs({ unpack(W.plates) }) do W.tok[token] = nil end
	W.plates = {}
	for _, p in ipairs(W.people) do
		if not p.grouped and p.around and s.b < 0.7 then p.around = false end
	end
	if W.tok.target and not (W.tok.target.around or W.tok.target.grouped) then W.tok.target = nil end
	if W.tok.focus and not (W.tok.focus.around or W.tok.focus.grouped) then W.tok.focus = nil end
	if W.tok.mouseover and not (W.tok.mouseover.around or W.tok.mouseover.grouped) then W.tok.mouseover = nil end
	fire(W, "PLAYER_ENTERING_WORLD", false, false)
	for k = 1, 1 + math.floor(s.c * 4) do
		local p = choose(aroundPeople(W), (s.a + k * 0.29) % 1)
		if p then plateAdd(W, p) end
	end
end)

-- Secrets (modern clients).
def("secrets", 8, function(W, s) applySecrets(W, s.a, s.b) end, modern)
def("refuse_shape", 1, function(W, s)
	Mock.refuseWith = s.a < 0.5 and "nil" or "secret"
end, modern)
def("hide_slot", 1, function(W, s)
	if s.a < 0.5 then W.hiddenSlot = nil else W.hiddenSlot = { [1 + math.floor(s.b * 6)] = true } end
end)
def("read_throws", 1, function(W, s)
	if s.a < 0.5 then W.readThrows = nil else
		W.readThrows = {}
		local id = choose(allBuffIds(W), s.b)
		if id then W.readThrows[id] = true end
	end
end, modern)

-- What the player knows.
def("relearn", 2, function(W, s)
	local rng = X.newRng(s.d + 17)
	X.learn(W, W.ns, rng)
	fire(W, "SPELLS_CHANGED")
	fire(W, "BAG_UPDATE_DELAYED")
	fire(W, "PLAYER_EQUIPMENT_CHANGED")
end)
def("bags", 2, function(W, s)
	for item in pairs(W.bags) do
		if s.a < 0.5 then W.bags[item] = math.floor(s.b * 5) end
	end
	W.weapon = s.c < 0.6
	fire(W, "BAG_UPDATE_DELAYED")
	fire(W, "PLAYER_EQUIPMENT_CHANGED")
end)
def("tracking", 1, function(W) fire(W, "MINIMAP_UPDATE_TRACKING") end)
def("ready_check", 2, function(W, s)
	fire(W, "READY_CHECK", "Raider", s.a < 0.5 and 30 or Mock.SECRET)
end)
def("ready_finished", 1, function(W) fire(W, "READY_CHECK_FINISHED") end)

-- The player's own hands: a cast from the bar, and events nobody asked for.
def("manual_cast", 4, function(W, s)
	local pool = {}
	for _, e in ipairs(W.classBuffs or {}) do
		if e.class == W.me.class then pool[#pool + 1] = e.name end
	end
	local name = choose(pool, s.a)
	if not name then return end
	local events = {}
	castSpell(W, name, events)
	deliver(W, events)
end)
def("cast_event", 5, function(W, s)
	local ids = allBuffIds(W)
	local id = choose(ids, s.a) or 1459
	local guid = castGuid(W)
	local kinds = { "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "SPELL_UPDATE_COOLDOWN",
		"UI_ERROR_MESSAGE" }
	local kind = choose(kinds, s.b)
	local unit = s.c < 0.8 and "player" or "target"
	if kind == "UI_ERROR_MESSAGE" then
		local messages = { "Out of range.", "Target is dead.", "You are mounted.", "Not enough mana.",
			"Spell is not ready yet.", "Invalid target", "You can't do that yet.", "Target is hostile" }
		local msg = choose(messages, s.c)
		if W.secretOK and s.d % 5 == 0 then msg = Mock.SECRET end
		fire(W, kind, 0, msg)
	elseif kind == "UNIT_SPELLCAST_SENT" then
		local who = choose(others(W), s.c)
		fire(W, kind, unit, who and who.first or "Nobody", guid, id)
	elseif kind == "SPELL_UPDATE_COOLDOWN" then
		fire(W, kind)
	else
		fire(W, kind, unit, guid, id)
	end
end)
def("casting", 1, function(W, s)
	if s.a < 0.5 then W.casting = nil else
		W.casting = { spellId = 5504, startsAt = Mock.now, endsAt = Mock.now + 1 + s.b * 3 }
		fire(W, "UNIT_SPELLCAST_START", "player")
	end
end)

-- The press.
-- How the game answers a press, in the orders and shapes it is known to take:
-- the events after PostClick, before it, twice, late, refused, with the guid
-- or the spell withheld.
local function reshape(W, events, variant)
	local sent, ok, failed
	for i, e in ipairs(events) do
		if e[1] == "UNIT_SPELLCAST_SENT" then sent = i
		elseif e[1] == "UNIT_SPELLCAST_SUCCEEDED" then ok = i
		elseif e[1] == "UNIT_SPELLCAST_FAILED" then failed = i end
	end
	if variant == 2 and sent then
		-- The server refuses what the client sent, a moment after it landed.
		local e = events[sent]
		events[#events + 1] = { "UNIT_SPELLCAST_FAILED", "player", e[4], e[5], delay = 0.8 }
	elseif variant == 3 and sent then
		-- Refused with a line and no cast at all.
		for i = #events, 1, -1 do table.remove(events, i) end
		events.landing = nil
		events[1] = { "UI_ERROR_MESSAGE", 0, "Out of range." }
	elseif variant == 4 and sent then
		-- A client that does not fill the cast guid in.
		for _, e in ipairs(events) do
			if e[1]:find("^UNIT_SPELLCAST") and e[1] ~= "UNIT_SPELLCAST_SENT" then e[3] = nil end
			if e[1] == "UNIT_SPELLCAST_SENT" then e[4] = nil end
		end
	elseif variant == 5 and sent and W.secretOK then
		for _, e in ipairs(events) do
			if e[1] == "UNIT_SPELLCAST_SENT" then e[4], e[5] = Mock.SECRET, Mock.SECRET
			elseif e[1]:find("^UNIT_SPELLCAST") then e[3], e[4] = Mock.SECRET, Mock.SECRET end
		end
	elseif variant == 6 and sent then
		local copy = {}
		for i, e in ipairs(events) do copy[i] = e end
		for _, e in ipairs(copy) do events[#events + 1] = e end
	elseif variant == 7 and sent then
		events.delay = 2.5
	end
end

local function pressOnce(W, s, mouseButton)
	local ns = W.ns
	local button = ns.Prompt:GetButton()
	local pre = button.scripts.PreClick
	local post = button.scripts.PostClick
	if pre then pre(button, mouseButton, true) end
	local macro = button:GetAttribute("macrotext1")
	local isMacro = button:GetAttribute("type1") == "macro" or button:GetAttribute("type") == "macro"
	W.pressMacro = macro
	W.stats.presses = W.stats.presses + 1
	if type(macro) == "string" and macro ~= "" then W.stats.armed = W.stats.armed + 1 end
	local events = {}
	if mouseButton == "LeftButton" and isMacro and type(macro) == "string" and macro ~= "" then
		X.checkPress(W, macro)
		if W.failure then return end
		runMacro(W, macro, events)
	end
	-- Most presses are answered the plain way; the rest in the other shapes.
	local variant = (s.d % 5 < 3) and 0 or (s.d % 8)
	local before = variant == 1
	reshape(W, events, variant)
	if before then deliver(W, events) end
	if post then post(button, mouseButton, true) end
	-- What PostClick parked for the game's answer, and whether it was owed.
	local pending = ns.pendingClick
	local owedBefore = pending and ns.owed[pending.name]
	if not before then
		if events.delay then Mock.advance(events.delay) end
		local late = {}
		for i = #events, 1, -1 do
			if events[i].delay then late[#late + 1] = table.remove(events, i) end
		end
		deliver(W, events)
		for _, e in ipairs(late) do
			Mock.advance(e.delay)
			fire(W, e[1], unpack(e, 2))
		end
	end
	-- A single cast that landed on the person the press was aimed at returns
	-- their favour: the settle runs on the cast event (Clicks.lua).
	if (variant == 0 or variant == 4 or variant == 6) and pending and owedBefore and events.ok
		and not events.late and events.aimed and X.filedName(W, events.aimed) == pending.name
		and not pending.selfCast and not pending.onSelf and not pending.group
		and ns.owed[pending.name] ~= nil then
		X.fail(W, "settle", ("%s was owed, a cast landed on them and they are still owed"):format(pending.name))
	end
end

def("press", 14, function(W, s)
	if W.ns.Prompt:InTest() and s.a < 0.5 then W.ns.Prompt:ExitTest() end
	pressOnce(W, s, "LeftButton")
	-- Down and up both: a key binding delivers each.
	if s.d % 4 == 0 and not W.failure then
		Mock.advance(0.05)
		local button = W.ns.Prompt:GetButton()
		local pre, post = button.scripts.PreClick, button.scripts.PostClick
		if pre then pre(button, "LeftButton", false) end
		if post then post(button, "LeftButton", false) end
	end
end)
def("press_right", 3, function(W, s)
	W.shift = s.a < 0.3
	pressOnce(W, s, "RightButton")
	W.shift = false
end)
def("double_press", 2, function(W, s)
	pressOnce(W, s, "LeftButton")
	if W.failure then return end
	Mock.advance(0.3 + s.a * 2)
	pressOnce(W, s, "LeftButton")
end)
def("hover", 3, function(W, s)
	local button = W.ns.Prompt:GetButton()
	local fn = button.scripts[s.a < 0.5 and "OnEnter" or "OnLeave"]
	if fn then fn(button) end
end)
-- A press with the global cooldown over and the scan settled first: the one
-- that lands, so its line goes out and its debt is settled.
def("press_ready", 10, function(W, s)
	Mock.advance(1.7)
	Mock.runTimers(0)
	local live = W.ns.addon
	X.xcall(live.Tick, live)
	pressOnce(W, s, "LeftButton")
end)

-- A name the client has not loaded yet reads "Unknown" for a moment.
def("name_unknown", 2, function(W, s)
	local p = choose(others(W), s.a)
	if p and not p.npc then p.unknownName = W.stepNo + 2 end
end)
def("level_up", 1, function(W, s)
	W.me.level = math.min(W.cap, W.me.level + 1 + math.floor(s.a * 5))
	fire(W, "SPELLS_CHANGED")
end)
def("mana_empty", 1, function(W, s)
	W.mana0 = not W.mana0
	W.me.mana = W.mana0 and 0 or 0.6
end)
-- The minimap button and the launcher.
def("launcher", 3, function(W, s)
	local broker = Mock.broker
	if not broker then return end
	if s.a < 0.5 and broker.OnClick then
		broker.OnClick(UIParent, s.b < 0.5 and "LeftButton" or "RightButton")
	elseif broker.OnTooltipShow then
		broker.OnTooltipShow(GameTooltip)
	end
end)
-- /manners selftest: a check that throws is a fault (the rest is its report).
def("selftest", 1, function(W, s)
	if Mock.inCombat then return end
	local selftest = W.ns.Selftest
	if not (selftest and selftest.Run) then return end
	for _, r in ipairs(selftest.Run()) do
		-- A check that throws because the client refused it (the stubs here
		-- do, on purpose) is a FAIL line in the report, which is its job;
		-- a Lua error inside the addon's code is the fault.
		local text = tostring(r.value)
		if text:find("^threw:") and text:find("attempt to", 1, true) and not text:find("fuzz_world.lua", 1, true) then
			X.fail(W, "selftest", ("check %s threw: %s"):format(tostring(r.id), tostring(r.value)))
			return
		end
	end
end)
-- The client around the addon changing under it.
def("drift", 2, function(W, s)
	local k = math.floor(s.a * 4)
	if k == 0 and W.secretOK then
		local mode = ({ "on", "restricted", "secret", "gone" })[1 + math.floor(s.b * 4) % 4]
		Mock.setInteract(mode)
	elseif k == 1 then
		if s.b < 0.5 then Mock.rangeCheck = nil else Mock.rangeCheck = {} end
		fire(W, "SPELLS_CHANGED")
	elseif k == 2 then
		local id = choose(allBuffIds(W), s.c)
		Mock.unknownSpells = (s.b < 0.5 or not id) and nil or { [id] = true }
		fire(W, "SPELLS_CHANGED")
	else
		Mock.refuseWith = (W.secretOK and s.b >= 0.5) and "secret" or "nil"
	end
end)

-- Settings.
local function controlPaths(W)
	if W.controlPaths and W.controlNs == W.ns then return W.controlPaths end
	local out, seen = {}, {}
	local layout = W.ns.WindowLayout
	if type(layout) == "table" and type(layout.pages) == "table" then
		local ids = {}
		for id in pairs(layout.pages) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			for _, section in ipairs(layout.pages[id].sections or {}) do
				for _, item in ipairs(section.items or {}) do
					local list = type(item) == "table" and (item.ids or { item[1] }) or { item }
					for _, path in ipairs(list) do
						if type(path) == "string" and not seen[path] then
							seen[path] = true
							out[#out + 1] = path
						end
					end
				end
			end
		end
	end
	W.controlPaths, W.controlNs = out, W.ns
	return out
end
X.controlPaths = controlPaths

local TEXTS = { "", " ", "x", "Hello {name}", "{buff} for {name}", "|cffff0000red|r", "100% sure",
	string.rep("long ", 60), "\195\169t\195\169", "a\nb", "%s %d", "[@player]", "/script x=1", "{unit}" }

local function ask(def, field, info)
	local v = def[field]
	if type(v) == "function" then
		local ok, r = pcall(v, info)
		if ok then return r end
		return nil
	end
	return v
end

-- A value for a control from its own definition; nil when none applies.
function X.valueFor(item, B, s)
	local d = item.def
	local t = d.type
	if t == "toggle" then return s.b < 0.5 end
	if t == "range" then
		local lo = tonumber(ask(d, "min", item.info)) or 0
		local hi = tonumber(ask(d, "max", item.info)) or lo + 100
		local step = tonumber(ask(d, "step", item.info)) or 0
		local v
		if s.b < 0.25 then v = lo elseif s.b < 0.5 then v = hi
		else v = lo + (hi - lo) * s.c end
		if step > 0 then v = lo + math.floor((v - lo) / step + 0.5) * step end
		if v < lo then v = lo end
		if v > hi then v = hi end
		return v
	end
	if t == "select" then
		local values = B.Values(item)
		local pair = choose(values, s.b)
		return pair and pair[1]
	end
	if t == "input" then return choose(TEXTS, s.b) end
	if t == "color" then return s.b, s.c, (s.d % 100) / 100, 1 end
	return nil
end

def("setting", 14, function(W, s)
	local ns = W.ns
	local paths = controlPaths(W)
	local B, UI = ns.WindowBind, ns.WindowUI
	if #paths == 0 or not B or not UI then return end
	if not UI.Shown() then ns.OpenOptions(nil, true) end
	local path = choose(paths, s.a)
	local item = B.Item(path, nil, UI.ctx)
	if not item then return end
	local d = item.def
	if B.Hidden(item) or B.Disabled(item) then return end
	if d.confirm ~= nil or item.group.confirm ~= nil then return end
	local t = d.type
	if t == "toggle" or t == "range" or t == "select" or t == "input" then
		local v = X.valueFor(item, B, s)
		if v ~= nil then B.Commit(item, v) end
	elseif t == "color" then
		B.Commit(item, X.valueFor(item, B, s))
	elseif t == "multiselect" then
		local pair = choose(B.Values(item), s.b)
		if pair then B.Commit(item, pair[1], s.c < 0.5) end
	elseif t == "execute" then
		if s.c < 0.5 then B.Run(item) end
	end
end)

-- A profile switch, and the saved file flushed and read again.
def("profile", 2, function(W, s)
	local names = { "Default", "Alt", "Raid", "Pvp" }
	W.ns.db:SetProfile(choose(names, s.a))
end)

local GARBAGE = { "banana", -1, 0, 1e308, -1e308, 0 / 0, math.huge, true, false, "", "  ", 2.5, 99999, -99999 }

local function leaves(t, path, out, depth)
	if depth > 4 then return end
	local keys = {}
	for k in pairs(t) do if type(k) == "string" then keys[#keys + 1] = k end end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = t[k]
		if type(v) == "table" then leaves(v, path .. "." .. k, out, depth + 1)
		else out[#out + 1] = { t, k } end
	end
end

-- Every moment the world keeps moves with the clock when it is set back.
local function shiftClock(W, delta)
	for _, e in ipairs(W.me.auras) do e.expires = e.expires + delta end
	for _, p in ipairs(W.people) do
		for _, b in pairs(p.buffs) do b.expires = b.expires + delta end
	end
	W.gcdStart, W.gcdEnds = W.gcdStart + delta, W.gcdEnds + delta
	if W.casting then
		W.casting.startsAt, W.casting.endsAt = W.casting.startsAt + delta, W.casting.endsAt + delta
	end
end

-- /reload keeps the clock; a restart of the machine does not (GetTime is the
-- uptime), and the wall clock goes on.
local function reload(W, garbage, s, reboot)
	if Mock.inCombat then return end
	local shutdown = Mock.dbCallbacks and Mock.dbCallbacks["OnDatabaseShutdown"]
	if shutdown then pcall(shutdown.target[shutdown.method], shutdown.target) end
	if garbage and Mock.sv.profile then
		local list = {}
		leaves(Mock.sv.profile, "profile", list, 0)
		for k = 1, 1 + math.floor(s.b * 6) do
			local at = choose(list, (s.a + k * 0.173) % 1)
			if at then at[1][at[2]] = choose(GARBAGE, (s.c + k * 0.31) % 1) end
		end
		-- And a whole section replaced by a non-table.
		if s.d % 5 == 0 then
			local keys = {}
			for k, v in pairs(Mock.sv.profile) do if type(v) == "table" then keys[#keys + 1] = k end end
			table.sort(keys)
			local k = choose(keys, s.b)
			if k then Mock.sv.profile[k] = choose({ "x", 7, true }, s.c) end
		end
	end
	if reboot then
		local now = 3 + s.a * 200
		shiftClock(W, now - Mock.now)
		Mock.epoch = Mock.epoch + 30 + math.floor(s.b * 900)
		Mock.now = now
	end
	-- The old addon's timers die with it.
	Mock.timers = {}
	W.ns = nil
	W.ns = X.boot(W, not reboot)
	X.afterReload(W)
end
def("reload", 2, function(W, s) reload(W, false, s) end)
def("reload_garbage", 2, function(W, s) reload(W, true, s) end)
def("reboot", 1, function(W, s) reload(W, s.c < 0.3, s, true) end)

-- The prompt dragged to a new place, as the client reports the move.
def("drag", 2, function(W, s)
	local button = W.ns.Prompt:GetButton()
	local start, stop = button.scripts.OnDragStart, button.scripts.OnDragStop
	if not (start and stop) then return end
	if s.d % 2 == 0 then W.ns.addon:HandleSlash("unlock") end
	start(button)
	local points = { "BOTTOM", "CENTER", "TOPLEFT", "RIGHT" }
	local x, y = math.floor((s.b - 0.5) * 3000), math.floor((s.c - 0.5) * 2000)
	local was = rawget(button, "GetPoint")
	button.GetPoint = function() return choose(points, s.a), UIParent, choose(points, s.b), x, y end
	stop(button)
	button.GetPoint = was
end)

-- Another character on the same account: the saved profile is shared, what
-- is kept per character (the debts, the last own buff) is not, and the class,
-- the spells and the bags are another's.
def("alt", 1, function(W, s)
	if Mock.inCombat then return end
	local shutdown = Mock.dbCallbacks and Mock.dbCallbacks["OnDatabaseShutdown"]
	if shutdown then pcall(shutdown.target[shutdown.method], shutdown.target) end
	W.me.class = choose(X.CLASSES[W.flavour], s.a)
	W.me.level = 1 + math.floor(s.b * W.cap)
	Mock.character = "Alt " .. tostring(s.d % 5)
	W.needLearn = s.d
	clearBuffs(W.me)
	Mock.timers = {}
	W.ns = nil
	W.ns = X.boot(W, false)
	X.afterReload(W)
end)
def("chat_lockdown", 1, function(W, s) W.chatLockdown = s.a < 0.5 end, modern)

local SLASH = { "on", "off", "snooze 1", "snooze 1", "snooze 3", "snooze off", "test", "ledger", "welcome",
	"macro", "unlock", "lock", "never", "restore", "verbose", "debug", "errors", "clicks", "export", "forms",
	"try /cast {spell}", "try", "look target", "look", "options", "", "bogus", "help", "selftest" }
-- Names a player might type after /manners never, whatever they mean.
local NASTY = { "%", "%s %d", "a|b", "[x]", "  ", string.rep("x", 300), "Zoë", "ａｂｃ", "a-b-c", "Mort", "mort",
	"MORT", "Al'Ar", "x\ty", "(", "%b()", ".-", "^$" }
def("slash", 6, function(W, s)
	local text = choose(SLASH, s.a)
	if s.b < 0.25 then
		-- A name on the never-offer list, or taken off it.
		local p = choose(aroundPeople(W), s.c)
		local name = p and X.filedName(W, p) or "Nobody Atall"
		if s.d % 5 == 0 then name = choose(NASTY, s.c) end
		text = (s.d % 2 == 0 and "never " or "allow ") .. name
	end
	local ns = W.ns
	if text == "selftest" then return end
	-- An unlocked prompt is locked again, an addon switched off switched on.
	if text == "unlock" then W.decay.unlock = W.stepNo + 4 end
	if text == "off" then W.decay.off = W.stepNo + 5 end
	if text == "snooze 3" then W.decay.snooze = W.stepNo + 30 end
	ns.addon:HandleSlash(text)
end)
def("options_page", 3, function(W, s)
	local ns = W.ns
	local layout = ns.WindowLayout
	if s.a < 0.2 then ns.CloseOptions() return end
	local ids = {}
	if type(layout) == "table" and type(layout.pages) == "table" then
		for id in pairs(layout.pages) do ids[#ids + 1] = id end
		table.sort(ids)
	end
	ns.OpenOptions(choose(ids, s.b), true)
end)
def("preview", 2, function(W) W.ns.Prompt:ToggleTest() end)
def("never_list", 2, function(W, s)
	local ns = W.ns
	local pool = aroundPeople(W)
	local p = choose(pool, s.a)
	if not p then return end
	local name = X.filedName(W, p)
	if s.b < 0.7 then ns.NeverOffer(name) W.never = W.never or {} W.never[name] = true
	else ns.AllowAgain(name) if W.never then W.never[name] = nil end end
end)
def("debt", 5, function(W, s)
	-- Somebody buffed the player: the aura lands and the event fires, as the
	-- ordinary route to a favour owed.
	local p = choose(others(W), s.a)
	if not p or p.npc then return end
	local ids = allBuffIds(W)
	local id = choose(ids, s.b)
	if not id then return end
	addBuff(W, W.me, id, p, 3600)
	fire(W, "UNIT_AURA", "player")
end)

-- Settings handed over as one line of text. A pasted line carries a taste and
-- never a state: it must not switch the addon off, unlock the prompt, start
-- the player speaking or thanking, or move the prompt (Commands.lua,
-- SHARE_SKIP), however it was written and however mangled it arrives.
local STATE_FIELDS = {
	{ "enabled" }, { "verbose" }, { "debugClicks" },
	{ "prompt", "locked" }, { "prompt", "x" }, { "prompt", "y" }, { "prompt", "point" }, { "prompt", "relPoint" },
	{ "minimap", "hide" },
}
local function readPath(t, path)
	for _, key in ipairs(path) do
		if type(t) ~= "table" then return nil end
		t = t[key]
	end
	return t
end
local function writePath(t, path, value)
	for i = 1, #path - 1 do t = t[path[i]] end
	t[path[#path]] = value
end

def("import", 3, function(W, s)
	local ns = W.ns
	if not ns.ExportSettings or not ns.ImportSettings then return end
	local db = ns.db.profile
	-- Write a foreign profile: every state the paste must not carry flipped,
	-- exported, then the player's own put back.
	local mine = {}
	for _, path in ipairs(STATE_FIELDS) do mine[#mine + 1] = { path, readPath(db, path) } end
	local mySpeech, myThank = db.speech.enabled, db.prompt.thankEmote
	db.enabled, db.verbose, db.debugClicks = not db.enabled, not db.verbose, not db.debugClicks
	db.prompt.locked = false
	db.prompt.x, db.prompt.y = 123, -234
	db.speech.enabled, db.prompt.thankEmote = true, true
	db.filters.skipPvP = not db.filters.skipPvP
	local text = ns.ExportSettings()
	for _, entry in ipairs(mine) do writePath(db, entry[1], entry[2]) end
	db.speech.enabled, db.prompt.thankEmote = mySpeech, myThank
	if type(text) ~= "string" then return end
	-- Mangled on the way, now and then.
	local mode = math.floor(s.a * 8)
	if mode == 1 then text = text:sub(1, math.max(1, math.floor(#text * s.b)))
	elseif mode == 2 then
		local at = 1 + math.floor(s.b * #text)
		text = text:sub(1, at - 1) .. string.char(33 + math.floor(s.c * 90)) .. text:sub(at + 1)
	elseif mode == 3 then text = text .. text:sub(1, 20)
	elseif mode == 4 then text = "garbage " .. text
	elseif mode == 5 then text = ""
	end
	local before = {}
	for _, path in ipairs(STATE_FIELDS) do before[#before + 1] = readPath(db, path) end
	local beforeSpeech, beforeThank = db.speech.enabled, db.prompt.thankEmote
	if mode == 6 then
		ns.UndoImport()
	else
		ns.ImportSettings(text)
	end
	db = ns.db.profile
	for i, path in ipairs(STATE_FIELDS) do
		local now = readPath(db, path)
		if now ~= before[i] and not (now ~= now and before[i] ~= before[i]) and mode ~= 6 then
			X.fail(W, "import", ("a pasted line changed %s from %s to %s"):format(
				table.concat(path, "."), tostring(before[i]), tostring(readPath(db, path))))
			return
		end
	end
	if beforeSpeech == false and db.speech.enabled == true and mode ~= 6 then
		X.fail(W, "import", "a pasted line switched speaking on")
		return
	end
	if beforeThank == false and db.prompt.thankEmote == true and mode ~= 6 then
		X.fail(W, "import", "a pasted line switched the thank emote on")
		return
	end
end)

-- ------------------------------------------------------------- the driver

-- Populate the area at the start, so the first steps have somebody to act on.
-- The settings a player of this seed has chosen: valid values, written as the
-- profile holds them, so that every seed exercises another corner of the
-- addon (speech on in a channel, a pinned spell, Skip PvP off ...).
local function personality(W, rng)
	local ns = W.ns
	local db = ns.db.profile
	local function chance(p) return rng() < p end
	local s, f, pr = db.sources, db.filters, db.priority
	s.owed, s.group, s.strangers = chance(0.9), chance(0.8), chance(0.85)
	s.asked, s.self, s.owedClassBuffsOnly = chance(0.65), chance(0.7), chance(0.8)
	f.whenBuffed = pick({ "skip", "skip", "refresh", "always" }, rng())
	f.proximity = pick({ "cast", "near", "beside" }, rng())
	f.requireInRange, f.relevantOnly = chance(0.85), chance(0.8)
	f.skipPvP, f.skipSameClass, f.hideMounted = chance(0.7), chance(0.3), chance(0.15)
	f.restingOnly, f.reachableOnly, f.restoreTarget = chance(0.2), chance(0.8), chance(0.8)
	f.minLevel = pick({ 1, 1, 1, 10, 30 }, rng())
	f.manaFloor = pick({ 0, 0, 0, 30, 80 }, rng())
	pr.target, pr.friends, pr.readyCheck, pr.revived = chance(0.8), chance(0.8), chance(0.8), chance(0.8)
	-- One seed in four starts from the settings most players keep -- every
	-- source on, nobody held back for their level or the mana, nothing pinned
	-- or switched off, nobody on the never-offer list -- the ground the checks
	-- that only judge a plain answer (somebody asked, somebody was raised,
	-- somebody lacks the buff) stand on. The draws are made all the same, so
	-- the rest of the seed is what it was, and the first settings step moves
	-- away from it as it does from any start.
	local plain = W.seed % 4 == 1
	if plain then
		s.owed, s.group, s.strangers, s.asked, s.self = true, true, true, true, true
		f.whenBuffed, f.proximity, f.requireInRange = "skip", "cast", true
		f.skipPvP, f.skipSameClass, f.hideMounted, f.restingOnly = false, false, false, false
		f.minLevel, f.manaFloor = 1, 0
		pr.target, pr.friends, pr.readyCheck, pr.revived = true, true, true, true
	end
	db.groupBuffs.use, db.groupBuffs.atLeast = chance(0.85), pick({ 2, 3, 3, 4 }, rng())
	db.timing.graceSeconds = pick({ 10, 45, 120 }, rng())
	db.timing.reciprocateWindow = pick({ 30, 120, 600 }, rng())
	db.timing.retryCooldown = pick({ 3, 12, 30 }, rng())
	db.verbose = chance(0.8)
	db.prompt.thankEmote = chance(0.3)
	db.prompt.showQueue = chance(0.4)
	local looks = {}
	for key in pairs(ns.Looks.Allowed()) do looks[#looks + 1] = key end
	table.sort(looks)
	db.prompt.style = pick(looks, rng())
	-- Speech: half the seeds talk, in one of the channels, in one of the sets.
	local sp = db.speech
	sp.enabled = chance(0.75)
	local channels = {}
	for key in pairs(ns.CHANNEL_COMMANDS) do channels[#channels + 1] = key end
	table.sort(channels)
	sp.channel = pick(channels, rng())
	sp.onlyWhenReturning = chance(0.4)
	local set = pick({ "roleplay", "polite", "cheeky", "quiet", "incharacter", "incharacter" }, rng())
	sp.presetChoice = set
	sp.phrases = ns.PhraseSetText(set) or sp.phrases
	W.inCharText = nil
	-- A quarter of the players wrote their own lines, some of them long.
	if chance(0.25) then
		local own = {}
		for k = 1, 1 + math.floor(rng() * 4) do
			local line = "Thanks {name}, here is some {buff}"
			local want = 80 + math.floor(rng() * 150)
			while #line < want do line = line .. " and more good wishes" end
			own[k] = line:sub(1, want)
		end
		sp.phrases = table.concat(own, "\n")
	end
	-- Spells: a pin now and then, a few switched off.
	local keys = {}
	for _, entry in ipairs(W.classBuffs or {}) do
		if entry.class == W.me.class then keys[#keys + 1] = entry.buff.key end
	end
	if #keys > 0 and chance(0.2) then
		local choice = pick(keys, rng())
		if not plain then db.buff.choice = choice end
	end
	for _, key in ipairs(keys) do
		if chance(0.12) and not plain then db.buff.skip[key] = true end
	end
	ns.Guard("clamp", ns.ClampSettings)
	ns.Prompt:InvalidateMacro()
	ns.Guard("style", ns.Prompt.ApplyStyle, ns.Prompt)
	if set == "incharacter" and sp.phrases == ns.PhraseSetText("incharacter") then W.inCharText = sp.phrases end
	-- A name or two on the never-offer list, for people who will be about.
	W.never = {}
	for i = 1, 3 do
		local p = W.people[1 + math.floor(rng() * 20)]
		if chance(0.5) and not plain then
			local name = X.filedName(W, p)
			ns.NeverOffer(name)
			W.never[name] = true
		end
	end
end

-- Populate the area at the start, so the first steps have somebody to act on.
function X.afterBoot(W)
	local rng = X.newRng(W.seed * 977 + 3)
	local n = 6 + math.floor(rng() * 14)
	for i = 1, n do
		local p = W.people[1 + math.floor(rng() * #W.people)]
		arrive(W, p)
		p.yards = 2 + math.floor(rng() * 40)
	end
	for i = 1, math.floor(rng() * 6) do
		local p = W.people[1 + math.floor(rng() * 30)]
		if p.around then plateAdd(W, p) end
	end
	if rng() < 0.5 then
		for i = 1, 1 + math.floor(rng() * 4) do
			local p = W.people[1 + math.floor(rng() * #W.people)]
			if p.around then joinGroup(W, p) end
		end
	end
	-- Two players of one name from different realms, about and on plates.
	if W.flavour ~= "camelot" and rng() < 0.6 then
		local k = 1 + math.floor(rng() * 4)
		for _, p in ipairs({ W.people[k], W.people[40 + k] }) do
			arrive(W, p)
			p.yards = 3 + math.floor(rng() * 20)
			plateAdd(W, p)
		end
	end
	personality(W, rng)
	-- Now and then somebody close by is on the player's ignore list from the
	-- start, on a nameplate: the one case where the ignore list decides who is
	-- offered, which a stranger at random is seldom (dice of their own).
	local dice = X.newRng(W.seed * 389 + 17)
	if dice() < 0.6 then
		local near = {}
		for _, p in ipairs(aroundPeople(W)) do
			if not p.grouped and not p.npc then near[#near + 1] = p end
		end
		local p = choose(near, dice())
		if p then
			p.ignored = true
			p.yards = 3 + math.floor(dice() * 22)
			plateAdd(W, p)
		end
	end
	Mock.advance(1)
	W.ns.addon:Tick()
end

function X.afterReload(W)
	-- The client redraws the nameplates it had up (X.boot fires the events).
	local button = W.ns.Prompt and W.ns.Prompt:GetButton()
	if button then Mock.protect(button) end
end

-- What the addon's watch of the group (Queue.lua, WatchGroupDeaths) can have
-- seen by now: somebody lying dead under a group token on a tick, and alive
-- under the very same token on a later one. Dead and raised between two ticks
-- is not seen, nor is a roster shuffled in between that hands the token to
-- another: those are not "raised in the group" to it. It looks at nothing
-- while the setting is off, and a reload forgets it (X.boot).
local function groupToken(W, p)
	if W.raid then
		local index = W.raidIndex(p)
		return index and ("raid" .. index) or nil
	end
	for i, q in ipairs(W.party or {}) do
		if q == p then return "party" .. i end
	end
	return nil
end

function X.watchDeaths(W)
	local db = W.ns.db and W.ns.db.profile
	local seen = W.seenDown
	if not (db and db.priority.revived == true) or not (W.raid or W.party) then
		if next(seen) then W.seenDown = {} end
		if next(W.revived) then W.revived = {} end
		return
	end
	-- A client that withholds whether they are dead says nothing, and a tick
	-- answered so changes nothing.
	if W.secret.all then return end
	local members = {}
	for _, q in ipairs(W.raid or W.party) do
		if q ~= W.me then members[#members + 1] = q end
	end
	local now = {}
	for _, q in ipairs(members) do now[q] = groupToken(W, q) end
	for q in pairs(seen) do
		if not now[q] then seen[q] = nil end
	end
	for q, token in pairs(now) do
		-- A name the client has not loaded yet is "Unknown" under the token,
		-- not the one they are filed under.
		local unloaded = q.unknownName and q.unknownName >= (W.stepNo or 0)
		if unloaded then
			seen[q] = nil
		elseif q.dead or q.ghost then
			-- Feign Death reads as dead and is taken as no answer.
			if not q.feign then seen[q] = token end
		else
			if seen[q] == token then
				W.revived[q] = { at = Mock.now, tick = W.tickCount }
			end
			seen[q] = nil
		end
	end
end

-- The clock moves by `seconds`, the timers fall due and the addon's scan and
-- the prompt's own update run once. False when an error got out of either.
function X.tick(W, seconds)
	Mock.runTimers(seconds)
	expireAuras(W)
	local live = W.ns.addon
	local fine, err = X.xcall(live.Tick, live)
	if not fine then X.escaped(W, "Tick", err) return false end
	W.tickCount = (W.tickCount or 0) + 1
	X.watchDeaths(W)
	-- The frame's own update, a few times a second.
	local button = W.ns.Prompt and W.ns.Prompt:GetButton()
	local update = button and button.scripts.OnUpdate
	if update then
		fine, err = X.xcall(update, button, seconds)
		if not fine then X.escaped(W, "OnUpdate", err) return false end
	end
	return true
end

-- One step: the op, the clock moving, the timers falling due, the scans.
function X.runStep(W, s)
	local names = {}
	for name in s.op:gmatch("[^+]+") do names[#names + 1] = name end
	if #names == 0 then return end
	Mock.protectedCalls = {}
	-- Short-lived states let go: a taxi ride ends, the dead are raised.
	for key, at in pairs(W.decay) do
		if W.stepNo >= at then
			W.decay[key] = nil
			if key == "taxi" then W.onTaxi = false
			elseif key == "vehicle" then W.inVehicle = false
			elseif key == "charm" then W.charmed = false
			elseif key == "unlock" and not Mock.inCombat then W.ns.addon:HandleSlash("lock")
			elseif key == "off" and not Mock.inCombat then W.ns.addon:HandleSlash("on")
			elseif key == "snooze" and not Mock.inCombat then W.ns.addon:HandleSlash("snooze off")
			elseif key == "die" and (W.me.dead or W.me.ghost) then
				local ghost = W.me.ghost
				W.me.dead, W.me.ghost = false, false
				fire(W, ghost and "PLAYER_UNGHOST" or "PLAYER_ALIVE")
				fire(W, "PLAYER_ALIVE")
			end
		end
	end
	for i, name in ipairs(names) do
		local op = OPS[name]
		if op then
			-- A second thing in the same step takes the numbers round.
			local sub = s
			if i > 1 then
				sub = { op = name, a = s.b, b = s.c, c = s.a, d = (s.d * 7 + 13) % 1000000, dt = s.dt }
			end
			local ok, err = X.xcall(op, W, sub)
			if not ok then X.escaped(W, "step " .. name, err) return end
			if W.failure then return end
		end
	end
	-- The clock moves on; the scan runs every 0.4 s over it.
	local dt = s.dt
	if s.op:find("wait", 1, true) then dt = dt + 20 + s.a * 280 end
	local ticks = math.min(6, math.max(1, math.floor(dt / 0.4)))
	for _ = 1, ticks do
		if not X.tick(W, dt / ticks) then return end
	end
end

end
