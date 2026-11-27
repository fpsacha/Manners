# Mutations for the fixes in the fight's buttons (Prompt/BreakFree.lua,
# Prompt/CureFight.lua). Caught by tests/scenarios/fight-fixes.lua; each undoes
# one fix.

S = "runscenarios.py"
BF = "Modules/Combat/BreakFree.lua"
CF = "Modules/Combat/CureFight.lua"
P = "fight-fix: "

# --- 1. a second secret loss of control inside the guess starts it again

mutate(BF,
       '\tif event == "LOSS_OF_CONTROL_ADDED" and (how == "secret" or how == "empty")\n\t\tand (not afflicted or guessed) then\n',
       '\tif event == "LOSS_OF_CONTROL_ADDED" and (how == "secret" or how == "empty")\n\t\tand not afflicted then\n',
       "fight-fix: a second secret fear inside the guess does not start it again",
       expect=P + "a second secret fear inside the guess keeps break free lit ten seconds from it", script=S)

# --- 2. somebody shown from the game's list alone stays until it is read again

mutate(CF,
       "\t\t\tif rec.spell ~= nil or not watched[unit] then needy[unit] = nil end\n",
       "\t\t\tneedy[unit] = nil\n",
       "fight-fix: somebody from the game's list dropped before the read",
       expect=P + "a curse seen only from the game's list keeps the cure button lit without a blink", script=S)

# --- 3. any of the command's keys with Shift in it

mutate(CF,
       "\tfor i = 1, #keys do\n",
       "\tfor i = 1, math.min(#keys, 1) do\n",
       "fight-fix: only the first key is asked for Shift",
       expect=P + "a second key bound with Shift arms the first cure alone", script=S)

# --- 4. a withheld name

mutate(CF,
       '\tif rec.name == nil then return L["Somebody"] end\n',
       "",
       "fight-fix: a withheld name reads as nil",
       expect=P + "a withheld name on the cure button never reads as nil", script=S)
