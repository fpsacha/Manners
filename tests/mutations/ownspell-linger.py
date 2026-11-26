# Mutations for a spell of my own the verdict took off: the prompt's hold and
# the empty-queue fuse must let go of it, and the verdict forgets its last
# pick. Each is caught by the scenario in tests/scenarios/ownspell-linger.lua
# that names it.

S = "runscenarios.py"

HOLD = "ownspell-linger: the hold lets go of a spell the verdict took off"
FUSE = "ownspell-linger: the fuse does not re-arm a spell the verdict took off"
LAST = "ownspell-linger: the verdict forgets the last pick of the spell"

mutate("Prompt/Hold.lua",
       "\tif OwnSpellGone(S.heldEntry) then return false end\n",
       "",
       "ownspell-linger: the hold keeps a removed spell",
       expect=HOLD, script=S)

mutate("Prompt/Hold.lua",
       "\tif OwnSpellGone(entry) then return true end\n",
       "",
       "ownspell-linger: the fuse re-arms a removed spell",
       expect=FUSE, script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "\ttable.remove(Entries(), IndexOf(entry))\n\tlocal char = Char()\n\tif char and type(char.ownLast) == \"table\" then char.ownLast[PREFIX .. entry.id] = nil end\n",
       "\ttable.remove(Entries(), IndexOf(entry))\n",
       "ownspell-linger: the verdict leaves the last pick behind",
       expect=LAST, script=S)
