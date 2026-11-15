-- Manners -- the hall of fame, "Gentlefolk of Good Manners".
--
-- A player who has earned every milestone their character can earn
-- (Milestones.lua: a class is not shown one it has no spell for, so "every"
-- is ten to twelve of the thirteen, the hidden ones included) is shown a code
-- on Start here, under the favour ledger, and may post it on the addon's
-- GitHub page with the "Hall of fame" issue form. The author then lists them:
-- in the README, and in HallOfFame.lua, which ships and is drawn under the
-- code. Before that the section says how far along the character is. All of
-- it is hidden while milestones are switched off.
--
-- An invitation and nothing else: nothing is asked for a place, and nothing
-- here sends anything anywhere. The code is text the player copies by hand.
--
-- The code, upper-case letters, digits and dashes only:
--
--   MANNERS1-<CLIENT>-<CLASS>-<YYYYMMDD>-<NAME>-<REALM>-<CHECK>
--
-- the client's flavour key and the class token in capitals, the day the last
-- milestone was earned, the character's name and realm as the hex of their
-- UTF-8 bytes (so a Forever name of two words and an accented one survive any
-- web form; a realm of "0" is no realm, which is WoW Forever), and eight hex
-- digits of checksum over everything before the last dash.
--
-- The checksum is NOT proof. It catches a typo, a paste cut short and a casual
-- edit; the arithmetic is in the open here and in tools/hall.py, and anybody
-- can make a code that passes. The author decides who is listed.
--
-- tools/hall.py holds the same arithmetic in Python (its VECTORS are checked
-- on both sides: tests/scenarios/hall.lua reads them out of that file).

local _, ns = ...
local L = ns.L

local M = ns.Milestones
if not M then return end

local Hall = {}
ns.Hall = Hall

local plain = ns.plain

local PREFIX = "MANNERS1"
local SALT = "Manners"
-- The longest name or realm a code carries, in bytes (tools/hall.py, MAX_BYTES).
local MAX_BYTES = 48
-- How many names the options window lists; the README has them all.
local MAX_ROWS = 40
Hall.MAX_ROWS = MAX_ROWS

-- Each client as a player calls it, by flavour key.
local CLIENTS = {
	camelot = L["WoW Forever"],
	vanilla = L["Classic Era"],
	tbc = L["Burning Crusade Classic"],
	mists = L["Mists of Pandaria Classic"],
	mainline = L["Retail"],
}

local TEXT = {
	TITLE = L["Gentlefolk of Good Manners"],
	-- Before every milestone is earned: how many, of how many.
	PROGRESS = L["%d of %d milestones earned. The hall of fame opens when you have earned them all: your name can then be listed among the Gentlefolk of Good Manners, here and on the addon's GitHub page."],
	-- Once they all are. An invitation: nothing is asked for a place.
	INVITE = L["Every milestone is yours. If you would like your name listed among the Gentlefolk of Good Manners, here and on the addon's GitHub page, copy the code below and post it there with the \"Hall of fame\" form: |cffffd100github.com/fpsacha/Manners|r. It is an invitation and nothing more: nothing is asked for it."],
	-- Every milestone, and no code could be made for this name.
	NOCODE = L["Every milestone is yours. Manners could not make a code for this character's name, so there is none to copy. If you would like your name listed among the Gentlefolk of Good Manners, say so on the addon's GitHub page: |cffffd100github.com/fpsacha/Manners|r."],
	LISTED = L["You are listed among the Gentlefolk of Good Manners. Thank you for your manners."],
	-- The one chat line when the last milestone is earned.
	OPEN = L["Every milestone earned. A place among the Gentlefolk of Good Manners is open to you: your code is on Start here (|cffffd100/manners|r)."],
	-- The list under the code.
	HEAD = L["Listed so far:"],
	EMPTY = L["Nobody is listed yet. The first place is open."],
	-- One row: the name in its class colour, then the client and the date.
	ROW = L["%s  |cff808080%s, %s|r"],
	YOU = L["%s  |cffffd100(you)|r"],
	MORE = L["And %d more on the GitHub page."],
}
Hall.TEXT = TEXT

---------------------------------------------------------------------------
-- the code
---------------------------------------------------------------------------

-- Eight hex digits over `body`. Kept under 2^53 at every step, so a double
-- holds it exactly, and written as two halves: "%X" of a number past 2^31 is
-- not the same on every build of Lua 5.1.
local function Checksum(body)
	local h = 5381
	local text = body .. SALT
	for i = 1, #text do
		h = (h * 33 + text:byte(i)) % 4294967296
	end
	return ("%04X%04X"):format(math.floor(h / 65536), h % 65536)
end

local function ToHex(text)
	return (text:gsub(".", function(c) return ("%02X"):format(c:byte()) end))
end

local function FromHex(hex)
	return (hex:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

-- The code for `who`: { name, realm (nil or "" for none), client (a flavour
-- key), class (a token), date ("YYYYMMDD") }. nil for anything a code cannot
-- carry.
function Hall.Encode(who)
	if type(who) ~= "table" then return nil end
	local name, realm = who.name, who.realm or ""
	if type(name) ~= "string" or name == "" or #name > MAX_BYTES then return nil end
	if type(realm) ~= "string" or #realm > MAX_BYTES then return nil end
	if type(who.client) ~= "string" or not who.client:find("^%a+$") then return nil end
	if type(who.class) ~= "string" or not who.class:find("^%a+$") then return nil end
	if type(who.date) ~= "string" or not who.date:find("^%d%d%d%d%d%d%d%d$") then return nil end
	local body = table.concat({ PREFIX, who.client:upper(), who.class:upper(), who.date,
		ToHex(name), realm ~= "" and ToHex(realm) or "0" }, "-")
	return body .. "-" .. Checksum(body)
end

-- What a code says, or nil and why: "shape" for text that is no code,
-- "checksum" for one that was mistyped or edited.
function Hall.Decode(code)
	if type(code) ~= "string" then return nil, "shape" end
	code = code:gsub("%s", ""):upper()
	local client, class, day, name, realm, check =
		code:match("^MANNERS1%-(%u+)%-(%u+)%-(%d%d%d%d%d%d%d%d)%-(%x+)%-(%x+)%-(%x%x%x%x%x%x%x%x)$")
	if not client or #name % 2 ~= 0 or (realm ~= "0" and #realm % 2 ~= 0) then return nil, "shape" end
	local body = code:sub(1, #code - 9)
	if Checksum(body) ~= check then return nil, "checksum" end
	return {
		name = FromHex(name),
		realm = realm ~= "0" and FromHex(realm) or "",
		client = client:lower(),
		class = class,
		date = day,
	}
end

---------------------------------------------------------------------------
-- this character
---------------------------------------------------------------------------

-- Who this character is, as a code and the list name them. The realm only
-- where the client has one: on WoW Forever a name is two words and its own.
local function Me()
	local name = ns.UnitFullName and ns.UnitFullName("player")
	local caps = ns.caps
	local class = caps and caps.class
	local client = ns.Flavour and ns.Flavour.flavour
	if type(name) ~= "string" or type(class) ~= "string" or type(client) ~= "string" then return nil end
	local realm = ""
	if not (caps and caps.unitNameIsSurname) and type(_G.GetRealmName) == "function" then
		local ok, value = pcall(_G.GetRealmName)
		value = ok and plain(value) or nil
		if type(value) == "string" then realm = value end
	end
	return { name = name, realm = realm, client = client, class = class }
end

-- Whether the section is there at all: only while milestones are on, and not
-- for a character with no milestone to earn (a class with no buff, cure,
-- resurrection or courtesy for anybody).
function Hall.Shown()
	if M.On() ~= true then return false end
	local _, of = M.Tally()
	return of > 0
end

-- How many milestones are earned, of how many this character can earn, and
-- whether that is all of them.
function Hall.Progress()
	local earned, of = M.Tally()
	return earned, of, of > 0 and earned >= of
end

-- This character's code, once every milestone is earned; nil before.
function Hall.Code()
	local _, _, done = Hall.Progress()
	if not done then return nil end
	local who = Me()
	local at = M.LastEarned()
	if not (who and at) then return nil end
	local ok, day = pcall(_G.date, "%Y%m%d", at)
	if not ok or type(day) ~= "string" then return nil end
	who.date = day
	local code = Hall.Encode(who)
	-- Never a code this file itself would not read back.
	if code and Hall.Decode(code) == nil then return nil end
	return code
end

local function Same(a, b)
	return type(a) == "string" and type(b) == "string" and a:lower() == b:lower()
end

-- Whether a row of the list is this character. The class as well, where the
-- row has one (every row tools/hall.py writes does): a name is not one
-- character for ever, and one made again under a freed name as another class
-- is somebody else. A namesake of the same class in another region cannot be
-- told apart: neither the code nor the row says the region.
local function IsMe(row, who)
	return who ~= nil and Same(row.name, who.name) and row.client == who.client
		and Same(row.realm or "", who.realm or "")
		and (type(row.class) ~= "string" or Same(row.class, who.class))
end

-- The list as shipped, newest first (HallOfFame.lua is written in that order;
-- sorted again here so a row out of place is not drawn out of place).
local function Rows()
	local out = {}
	for i, row in ipairs(type(ns.HALL_OF_FAME) == "table" and ns.HALL_OF_FAME or {}) do
		if type(row) == "table" and type(row.name) == "string" and row.name ~= "" then
			out[#out + 1] = { row = row, i = i, date = type(row.date) == "string" and row.date or "" }
		end
	end
	table.sort(out, function(a, b)
		if a.date ~= b.date then return a.date > b.date end
		return a.i < b.i
	end)
	return out
end

-- Whether this character is on the list.
function Hall.Listed()
	local who = Me()
	for _, r in ipairs(Rows()) do
		if IsMe(r.row, who) then return true end
	end
	return false
end

-- The line the section opens with: how far along, the invitation, or thanks.
function Hall.NoteText()
	local earned, of, done = Hall.Progress()
	if Hall.Listed() then return TEXT.LISTED end
	-- Every milestone, and no code to copy (a name a code cannot carry, or one
	-- the client would not give): said, where the invitation would point at a
	-- box that is not there.
	if done and Hall.Code() == nil then return TEXT.NOCODE end
	if done then return TEXT.INVITE end
	return TEXT.PROGRESS:format(earned, of)
end

local function Coloured(name, class)
	local colours = _G.RAID_CLASS_COLORS
	local c = type(class) == "string" and type(colours) == "table" and colours[class]
	local code = type(c) == "table" and plain(c.colorStr)
	if type(code) == "string" then return ("|c%s%s|r"):format(code, name) end
	return name
end

-- The list, one name a line: in its class colour, with the client and the
-- date, the player's own marked. Names never carry a colour code of their own.
function Hall.ListText()
	local rows, who = Rows(), Me()
	if #rows == 0 then return TEXT.EMPTY end
	local lines = { TEXT.HEAD }
	-- Past the cut only the player's own row is drawn, so somebody told they
	-- are listed finds their name; the rest are counted.
	local more = 0
	for i, r in ipairs(rows) do
		local row = r.row
		local cut = false
		if i > MAX_ROWS then
			cut = not IsMe(row, who)
		end
		if cut then
			more = more + 1
		else
			local name = row.name:gsub("|", "")
			if type(row.realm) == "string" and row.realm ~= "" then name = name .. "-" .. row.realm:gsub("|", "") end
			local line = TEXT.ROW:format(Coloured(name, row.class), CLIENTS[row.client] or tostring(row.client or ""), r.date)
			if IsMe(row, who) then line = TEXT.YOU:format(line) end
			lines[#lines + 1] = line
		end
	end
	if more > 0 then lines[#lines + 1] = TEXT.MORE:format(more) end
	return table.concat(lines, "\n")
end

-- The last milestone was just earned (Milestones.lua, Evaluate): one line in
-- chat saying where the code is. Said once, by the earning that completed it.
function Hall.Announce()
	local _, _, done = Hall.Progress()
	if not done or Hall.Listed() then return end
	-- Nothing about a code there is none of (NoteText says why on the page).
	if Hall.Code() == nil then return end
	if ns.addon and ns.addon.Print then ns.addon:Print(TEXT.OPEN) end
end
