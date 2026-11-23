# Mutations for the wards by the school of the target's own cast:
# tests/scenarios/moments-cast-school.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"
DATA = "Prompt/MomentsData.lua"

# --- the table and where it is read

mutate(DATA,
       "ns.CAST_SCHOOLS_BY_CLIENT = nil\n",
       "",
       "moments-cast-school: the other clients' tables are kept",
       expect="moments-cast-school: CastSchools.lua: each client's table is whole", script=S)

mutate(SENSE,
       "\t\treturn \"exact\", known[id] or 0\n",
       "\t\treturn \"exact\", 0\n",
       "moments-cast-school: the table is not read",
       expect="moments-cast-school: exact, Classic Era: a Fireball lights Fire Ward", script=S)

# --- where the id is, per client

mutate(SENSE,
       "\telseif type(rawEighth) == \"number\" then\n\t\trawId = rawEighth\n\tend\n",
       "\tend\n",
       "moments-cast-school: Classic Era's eighth return is not read as the id",
       expect="moments-cast-school: exact, Classic Era: a Fireball lights Fire Ward", script=S)

mutate(SENSE,
       "\t\telseif type(rawSeventh) == \"number\" then\n\t\t\trawId = rawSeventh\n\t\tend\n",
       "\t\tend\n",
       "moments-cast-school: Classic Era's channel id is not read",
       expect="moments-cast-school: exact, Classic Era: a channel", script=S)

mutate(SENSE,
       "\telseif type(rawNinth) == \"number\" then\n\t\trawId = rawNinth\n",
       "\telseif false then\n\t\trawId = rawNinth\n",
       "moments-cast-school: the ninth return is not read as the id",
       expect="moments-cast-school: exact, Burning Crusade (the id ninth)", script=S)

mutate(SENSE,
       "\t\tif type(rawEighth) == \"number\" then\n\t\t\trawId = rawEighth\n\t\telseif",
       "\t\tif false then\n\t\t\trawId = rawEighth\n\t\telseif",
       "moments-cast-school: a channel's eighth return is not read as the id",
       expect="moments-cast-school: exact, Burning Crusade (the id ninth)", script=S)

# --- the verdicts

mutate(SENSE,
       "\tif route == \"exact\" and HasSchool(mask, bit) then return \"yes\" end\n",
       "\tif route == \"exact\" then return \"yes\" end\n",
       "moments-cast-school: any named cast lights both wards",
       expect="moments-cast-school: exact, Classic Era: a Fireball lights Fire Ward", script=S)

mutate(SENSE,
       "\tlocal verdict, why = ByHit(slot, now, route == \"unknown\")\n",
       "\tlocal verdict, why = ByHit(slot, now, route ~= \"none\")\n",
       "moments-cast-school: a cast of a named school is guessed at from an earlier hit",
       expect="moments-cast-school: exact: a cast of another school is not guessed at", script=S)

mutate(SENSE,
       "\tif route == \"exact\" then return \"no\", \"your target is casting something that is not of that kind\" end\n",
       "",
       "moments-cast-school: the reason under another school's cast is the hit rule's",
       expect="moments-cast-school: exact, Classic Era: a Fireball lights Fire Ward", script=S)

mutate(SENSE,
       "\tif type(id) ~= \"number\" or not known or castRoute.size == 0 then return \"unknown\" end\n",
       "\tif type(id) ~= \"number\" or not known then return \"unknown\" end\n",
       "moments-cast-school: a client with no table names every cast as no school",
       expect="moments-cast-school: a client with no table of spells falls back at once", script=S)

# --- from the game

mutate(SENSE,
       "\tif not Hidden(rawId) then\n",
       "\tif true then\n",
       "moments-cast-school: a hidden id is read as plain",
       expect="moments-cast-school: from the game: a hidden Fireball lights Fire Ward", script=S)

mutate(SENSE,
       "\t\tcurve:AddPoint(id, 1)\n",
       "\t\tcurve:AddPoint(id, 0)\n",
       "moments-cast-school: the curve answers 0 at every spell",
       expect="moments-cast-school: from the game: a hidden Fireball lights Fire Ward", script=S)

mutate(SENSE,
       "\t\tif HasSchool(mask, bit) then ids[#ids + 1] = id end\n",
       "\t\tids[#ids + 1] = id\n",
       "moments-cast-school: one curve for both schools",
       expect="moments-cast-school: from the game: a hidden Fireball lights Fire Ward", script=S)

mutate(SENSE,
       "\tif route == \"game\" then\n\t\tslot.game = slot.castLit\n",
       "\tif false then\n\t\tslot.game = slot.castLit\n",
       "moments-cast-school: the game's answer is never handed to the paint",
       expect="moments-cast-school: from the game: a hidden Fireball lights Fire Ward", script=S)

mutate(SENSE,
       "\tif verdict == \"yes\" then return \"yes\" end\n\tif route == \"game\" then",
       "\tif route == \"game\" then",
       "moments-cast-school: the game's paint comes before a plain hit",
       expect="moments-cast-school: from the game: a fire hit still lights Fire Ward plainly", script=S)

mutate(SENSE,
       "\tif castRoute.evaluated then\n",
       "\tif false then\n",
       "moments-cast-school: the route is tried on every hidden id",
       expect="moments-cast-school: from the game: no pcall once the route is settled", script=S)

mutate(SENSE,
       "\t\tif type(rawA) ~= \"number\" then error(\"not a number\", 0) end\n\t\tinner:SetAlpha(rawA)\n\telseif kind == \"any\" then",
       "\t\tif type(rawA) ~= \"number\" then error(\"not a number\", 0) end\n\t\tinner:SetAlpha(1)\n\telseif kind == \"any\" then",
       "moments-cast-school: the answer of the curve is not what paints the ward",
       expect="moments-cast-school: from the game: a hidden Fireball lights Fire Ward", script=S)

# --- refused: the fallback

mutate(SENSE,
       "\tif not curve or castRoute.refused or refused.school then return \"unknown\" end\n",
       "\tif not curve then return \"unknown\" end\n",
       "moments-cast-school: a refused route is used all the same",
       expect="moments-cast-school: refused at setup: the game takes the number but will not paint", script=S)

mutate(SENSE,
       "\tif not (type(rawProbe) == \"number\" and Hidden(rawProbe)) then return end\n",
       "\tif type(rawProbe) ~= \"number\" then return end\n",
       "moments-cast-school: a plain number settles the route at setup",
       expect="moments-cast-school: not settled at setup (nothing hidden to try)", script=S)

mutate(SENSE,
       "\tif not Sense.Paint(scratch, \"school\", rawLit) then\n",
       "\tif false then\n",
       "moments-cast-school: setup does not try the paint",
       expect="moments-cast-school: refused at setup: the game takes the number but will not paint", script=S)

mutate(SENSE,
       "\tif not ok then\n\t\tcastRoute.refused = \"Curve:Evaluate refused a hidden number: \" .. tostring(rawLit)\n",
       "\tif false then\n\t\tcastRoute.refused = \"Curve:Evaluate refused a hidden number: \" .. tostring(rawLit)\n",
       "moments-cast-school: a refused hidden number at setup is not noted",
       expect="moments-cast-school: refused at setup: Curve:Evaluate throws", script=S)

mutate(SENSE,
       "\t\tif not ok then\n\t\t\tcastRoute.refused = \"Curve:Evaluate refused a hidden spell id: \" .. tostring(rawLit)\n",
       "\t\tif false then\n\t\t\tcastRoute.refused = \"Curve:Evaluate refused a hidden spell id: \" .. tostring(rawLit)\n",
       "moments-cast-school: a refused first hidden id is not noted",
       expect="moments-cast-school: not settled at setup: the first hidden id refused", script=S)

# --- setup and the words

mutate(SENSE,
       "\t\tcastRoute.exact = true\n",
       "",
       "moments-cast-school: an exact read is not remembered",
       expect="moments-cast-school: debug and the self-test name the route: exact", script=S)

mutate(M,
       "\t\t\t\tif entry.row.school and not Sense.castRoute.probed then Sense.ProbeSchool() end\n",
       "",
       "moments-cast-school: setup never tries the route",
       expect="moments-cast-school: from the game: setup tries a hidden number", script=S)

mutate(M,
       "(\"moments: cast school: %s (%s)\")",
       "(\"moments: school %s (%s)\")",
       "moments-cast-school: /manners debug does not name the route",
       expect="moments-cast-school: debug and the self-test name the route: from the game", script=S)

mutate("Selftest.lua",
       "(\"cast school: %s (%s)\")",
       "(\"school: %s (%s)\")",
       "moments-cast-school: the self-test does not name the route",
       expect="moments-cast-school: debug and the self-test name the route: from the game", script=S)

# --- the buttons

mutate(DATA,
       "ranks = { 10225, 10223, 8458, 8457, 543 }, school = 4, shares = \"frostward\",\n\t\t\tstop = true, guard = \"twice\", cooldown = 30,",
       "ranks = { 10225, 10223, 8458, 8457, 543 }, school = 4, shares = \"frostward\",\n\t\t\tstop = true, cooldown = 30,",
       "moments-cast-school: a ward only the game lights takes one click",
       expect="moments-cast-school: from the game: a hidden Fireball lights Fire Ward", script=S)
