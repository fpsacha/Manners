-- One context result shape for buffs, cures, own items and services.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local scenario = "context: every decision has the same safe shape"

Mock.reset()
Mock.class = "HUNTER"
local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
local ns = load(scenario)
if not ns then return end
drive(scenario, ns)

for _, kind in ipairs({ "buff", "cure", "own", "service" }) do
	local decision = ns.ContextDecision(kind, kind, "Anna Aim", 1.5, "asked", true, 2)
	if decision.eligible ~= true or decision.action ~= kind or decision.target ~= "Anna Aim"
		or decision.priority ~= 1.5 or decision.reason ~= "asked" or decision.cacheAge ~= 2
		or type(decision.requirements) ~= "table" then
		fail(scenario, kind .. " did not return a complete context decision")
	end
end
local rejected = ns.ContextDecision("cure", "cure", "Anna Aim", 1.25, "cooldown", false, 0)
if rejected.eligible ~= false or rejected.reason ~= "cooldown" then
	fail(scenario, "a rejected decision was reported as eligible")
end

local ok, reason = ns.ContextTarget("buff", "nameplate1")
if not ok or reason ~= nil then fail(scenario, "a readable friendly player was not eligible") end
if ns.ContextTarget("own", "player", true) ~= true then fail(scenario, "the player was not eligible for an own item") end
if ns.ContextTarget("buff", "player") ~= false then fail(scenario, "the player was a buff target for somebody else") end

local savedDead, savedAssist, savedConnected = UnitIsDeadOrGhost, UnitCanAssist, UnitIsConnected
rawset(_G, "UnitIsDeadOrGhost", function(unit) return unit == "nameplate1" end)
ok, reason = ns.ContextTarget("cure", "nameplate1")
if ok or reason ~= "dead" then fail(scenario, "a dead cure target was not rejected") end
rawset(_G, "UnitIsDeadOrGhost", savedDead)
rawset(_G, "UnitCanAssist", function() return false end)
ok, reason = ns.ContextTarget("service", "nameplate1")
if ok or reason ~= "hostile" then fail(scenario, "a hostile service target was not rejected") end
rawset(_G, "UnitCanAssist", savedAssist)
rawset(_G, "UnitIsConnected", function(unit) return unit ~= "nameplate1" end)
ok, reason = ns.ContextTarget("buff", "nameplate1")
if ok or reason ~= "offline" then fail(scenario, "an offline buff target was not rejected") end
rawset(_G, "UnitIsConnected", savedConnected)

for i = 1, 25 do
	ns.ContextDecision("service", "target", Mock.SECRET, 9, "secret-" .. i, false, nil)
end
local rejectedLines = ns.ContextRejectionLines()
if #rejectedLines ~= 20 then
	fail(scenario, "the rejection history is not bounded at twenty")
end
for _, line in ipairs(rejectedLines) do
	if line:find(tostring(Mock.SECRET), 1, true) or not line:find("target=<withheld>", 1, true) then
		fail(scenario, "a secret target leaked into " .. line)
	end
end
Mock.printed = {}
local savedCanCast = ns.CanCastAnything
ns.CanCastAnything = function() return true end
ns.addon:HandleSlash("debug")
ns.CanCastAnything = savedCanCast
local debug = table.concat(Mock.printed or {}, "\n")
if not debug:find("context rejected:", 1, true) then fail(scenario, "/manners debug has no decision rejections") end

restore()
Mock.reset()
