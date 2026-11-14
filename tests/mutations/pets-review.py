# Mutations for the pets review: the second before a putting away is judged
# (Companion.lua, Pet:Tick), pets of the group that share a name with one
# another or with your own (Queue.lua, ns.GroupNames) and a member's vehicle on
# their pet token (Core.lua, IsBuffableUnit). Each is caught by the scenario in
# tests/scenarios/pets-review.lua that names it.

S = "runscenarios.py"

# The scan brings a pet out while the player's own call is still to be judged.
mutate("Companion.lua",
       "\tif session.asked then return end\n",
       "",
       "pets-review: a pet summoned before the putting away is judged",
       expect="pets-review: a pet put away is not brought back in the second before it is judged", script=S)

# A name two pets carry is nobody's clash: the first Wolf stands for both.
mutate("Queue.lua",
       "if once[name] then names[name] = true else once[name] = true end",
       "once[name] = true",
       "pets-review: two pets of one name are one pet",
       expect="pets-review: two pets of the group that share a name are left out", script=S)

# Your own pet's name is not held against a pet of the group.
mutate("Queue.lua",
       "\t\tif own then once[own] = true end\n",
       "",
       "pets-review: your own pet's name is free for the group's",
       expect="pets-review: a pet of the group named as your own pet is left out", script=S)

# The owner is never asked whether they are in a vehicle, either way.
mutate("Core.lua",
       "if type(riding) == \"function\" and plain(riding(pet)) == true then return false end\n\t\triding = _G.UnitInVehicle",
       "riding = _G.UnitInVehicle",
       "pets-review: a vehicle with its own bar is a pet",
       expect="pets-review: a member's vehicle is no pet of theirs (UnitHasVehicleUI)", script=S)

mutate("Core.lua",
       "\t\triding = _G.UnitInVehicle\n\t\tif type(riding) == \"function\" and plain(riding(pet)) == true then return false end\n",
       "",
       "pets-review: a vehicle ridden is a pet",
       expect="pets-review: a member's vehicle is no pet of theirs (UnitInVehicle)", script=S)
