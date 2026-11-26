# Mutations for Will of the Forsaken's need (Prompt/BreakFree.lua, GitHub issue
# 33): losing control of your character in a fight is the need where the game
# withholds the type or has no loss-of-control API. Caught by
# tests/scenarios/wotfneed.lua; each undoes one rule.

S = "runscenarios.py"
BF = "Modules/Combat/BreakFree.lua"
P = "wotfneed: "
GUESS = '\tif not hit and lostAt and (how == "secret" or how == "no API") then\n'
ENDS = '\t\tif full == false or (full == nil and GetTime() - lostAt <= UNSURE_SECONDS) then\n'

# --- 1. a fear by mechanic is a fear

mutate(BF,
       "\t\tbreaks = { FEAR = true, FEAR_MECHANIC = true, CHARM = true, SLEEP = true }, cooldown = 120 },\n",
       "\t\tbreaks = { FEAR = true, CHARM = true, SLEEP = true }, cooldown = 120 },\n",
       "wotfneed: a fear by mechanic dropped from the row",
       expect=P + "a fear by mechanic lights it", script=S)

# --- 2. a withheld read, control lost: the need

mutate(BF,
       GUESS,
       "\tif false then\n",
       "wotfneed: a withheld read never guessed",
       expect=P + "a secret loss of control lights it while you have lost control", script=S)

mutate(BF,
       "\t\tlostAt = GetTime()\n\t\tkind, how = Read()\n\tend\n",
       "\t\tlostAt = GetTime()\n\tend\n",
       "wotfneed: a secret loss of control not read again once it is noted",
       expect=P + "a secret loss of control lights it while you have lost control", script=S)

# --- 3. no API

mutate(BF,
       GUESS,
       '\tif not hit and lostAt and (how == "secret") then\n',
       "wotfneed: no API never guessed",
       expect=P + "no loss-of-control API, a fear lights it", script=S)

# --- 4. when the guess ends

mutate(BF,
       ENDS,
       "\t\tif full == false or full == nil then\n",
       "wotfneed: the ten seconds ignored",
       expect=P + "a withheld read with nothing to say it ended gives up after ten seconds", script=S)

mutate(BF,
       ENDS,
       "\t\tif full ~= true or (full == nil and GetTime() - lostAt <= UNSURE_SECONDS) then\n",
       "wotfneed: anything but a plain true taken for control lost",
       expect=P + "a withheld read with nothing to say it ended gives up after ten seconds", script=S)

mutate(BF,
       ENDS,
       "\t\tif full ~= nil or (full == nil and GetTime() - lostAt <= UNSURE_SECONDS) then\n",
       "wotfneed: a plain true taken for control lost",
       expect=P + "a secret report while you plainly have control is no reason", script=S)

mutate(BF,
       "\t\tlostAt = nil\n\tend\n\tlocal was = afflicted\n",
       "\tend\n\tlocal was = afflicted\n",
       "wotfneed: control gained does not end the guess",
       expect=P + "a secret count and a secret charm with control lost light it", script=S)

mutate(BF,
       "\tlostAt, guessed = nil, false\n\tRead()\n",
       "",
       "wotfneed: the guess outlives the fight",
       expect=P + "the guess ends with the fight", script=S)

# --- 5. a plain read stays the authority

mutate(BF,
       GUESS,
       "\tif not hit and lostAt then\n",
       "wotfneed: a plain read guesses too",
       expect=P + "a plain stun with control lost is no reason", script=S)

# --- 6. the words

mutate("Options/Look.lua",
       "It shows while you are feared, charmed or asleep, and whenever you lose control of your character in a fight where the game will not say what took it: lit",
       "It shows while you are feared, charmed or asleep: lit",
       "wotfneed: the switch's tooltip says nothing of it",
       expect=P + "the switch's tooltip says when it shows", script=S)

mutate(BF,
       'guessed and " (a loss of control the game would not name)" or "", tostring(Ready',
       '"", tostring(Ready',
       "wotfneed: debug does not say it was a guess",
       expect=P + "debug says it came up on a loss of control the game would not name", script=S)
