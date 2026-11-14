-- Two drawings of one texture alike (H.sameArt, tests/scenarios.lua): what the
-- "the generator draws the same bytes" scenarios hold a generator's output to
-- against the file that ships. The same bytes, or the same size and header
-- with no channel more than one step apart: a machine's maths library rounds
-- a sine's last bit its own way, and GitHub's Linux runners drew a handful of
-- pixels one step off the Windows-made files, which turned the nightly
-- mutation run's baseline red. A change to the art moves more than a step.
--
-- Every scenario name starts with "sameart:" so the mutations in
-- tests/mutations/sameart.py can name the one that has to catch them.

local dir, H = ...
local fail = H.fail

do
	local scenario = "sameart: one step off is the same art, two steps or another size is not"
	local header = string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 4, 0, 32, 8)
	local body = {}
	for i = 1, 64 do body[i] = string.char(100 + (i % 50)) end
	local art = header .. table.concat(body)
	local function with(at, value)
		return art:sub(1, at - 1) .. string.char(value) .. art:sub(at + 1)
	end
	local at = #header + 10
	local was = art:byte(at)
	if not H.sameArt(art, art) then fail(scenario, "a file is not the same art as itself") end
	if not H.sameArt(art, with(at, was + 1)) then fail(scenario, "one channel one step up is another art") end
	if not H.sameArt(art, with(at, was - 1)) then fail(scenario, "one channel one step down is another art") end
	if H.sameArt(art, with(at, was + 2)) then fail(scenario, "one channel two steps up is the same art") end
	if H.sameArt(art, with(at, was - 2)) then fail(scenario, "one channel two steps down is the same art") end
	if H.sameArt(art, art .. string.char(0)) then fail(scenario, "a longer file is the same art") end
	-- The header is the picture's size and depth: to the byte.
	if H.sameArt(art, with(13, 5)) then fail(scenario, "a file of another width is the same art") end
	if H.sameArt(art, nil) or H.sameArt(nil, art) then fail(scenario, "a file that is not there is the same art") end
	-- The last byte counts too, and one past a block's edge.
	if H.sameArt(art, with(#art, art:byte(#art) + 2)) then fail(scenario, "the last byte two steps off is the same art") end
end
