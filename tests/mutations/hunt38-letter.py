# Mutations for hunt 38, the Letter look (tests/scenarios/hunt38-letter.lua).
#
# Run by tests/selftest.py with mutate() in scope. Each undoes one fix -- a key's
# slip that takes no notice of the room, a layout that puts the unroll's frames
# at rest under a run that goes on, a restyle that lets the run go on, a count's
# drop of wax that waits for the seal -- and names the check that has to object.

LETTER = "Looks/Letter.lua"
S = "runscenarios.py"

# The key's slip stands wherever the key is bound, over the seal and the reason
# on a prompt as narrow as the slider allows.
mutate(LETTER,
       "\t\tif keyUp and self.keyW + 4 > g.textRight - self.textX - 20 then keyUp = false end\n",
       "",
       "hunt38-letter: a key's slip taking no notice of the room the lines keep",
       expect="hunt38-letter: the bound key's slip never stands over the seal or the reason", script=S)

# A list laid again while the scroll unrolls puts its three frames at rest under
# a run that goes on.
mutate(LETTER,
       "\tif not self.unrollGroups[1]:IsPlaying() then return self:Rest() end\n",
       "\treturn self:Rest()\n",
       "hunt38-letter: a list laid again putting the unroll's frames at rest under the run",
       expect="hunt38-letter: a list that changes while the scroll unrolls", script=S)

# A restyle lets the run go on over frames laid for the old size.
mutate(LETTER,
       "\tfor _, group in ipairs(self.unrollGroups) do group:Stop() end\n\n\t-- Everything shown, then laid",
       "\n\t-- Everything shown, then laid",
       "hunt38-letter: a restyle that lets the unroll go on",
       expect="hunt38-letter: a restyle while the scroll unrolls", script=S)

# The count's drop of wax is placed only when its slip changes height, which a
# count first standing beside the lines never does.
mutate(LETTER,
       "\tself:PlacePin(self.countPin, self.countPinLight, self.countBox, chipH)\n",
       "",
       "hunt38-letter: a count's drop of wax left without a place",
       expect="hunt38-letter: the count's drop of wax is placed", script=S)
