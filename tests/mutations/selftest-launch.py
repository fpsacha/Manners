# Mutations for tests/scenarios/selftest-launch.lua: /manners selftest launch
# (SelftestLaunch.lua), the checks that ask the real client about what has only
# run on the mock. Each is a rule of that file undone; the scenario named has to
# go red.
#
# Run by tests/selftest.py with mutate() in scope.

S = "runscenarios.py"
F = "SelftestLaunch.lua"
NOTHING = "selftest-launch: nothing is left changed (the prompt in glass)"
OWN = "selftest-launch: the slot is set, read, cleared and put back on the player's own macro"
TEMP = "selftest-launch: with no macro, a temporary one is made when asked, said so, and deleted"
CMD = "selftest-launch: the command"

# ---- what is put back

# The prompt is left in the last look the run put on it.
mutate(F,
       "\tp.style = saved\n\tlocal okBack, errBack = pcall(Prompt.ApplyStyle, Prompt)\n",
       "\tlocal okBack, errBack = pcall(Prompt.ApplyStyle, Prompt)\n",
       "selftest-launch: the style is not put back",
       expect=NOTHING, script=S)

# The macro's slot is left empty after the test.
mutate(F,
       "\tif before.spell ~= nil and type(setSpell) == \"function\" then\n",
       "\tif false and before.spell ~= nil and type(setSpell) == \"function\" then\n",
       "selftest-launch: the slot's spell is not given back",
       expect=OWN, script=S)

# The temporary macro stays in the player's list.
mutate(F,
       "\t\tif okN ~= true or name == TEMP_MACRO then pcall(_G.DeleteMacro, index) end\n",
       "\t\tif false then pcall(_G.DeleteMacro, index) end\n",
       "selftest-launch: the temporary macro is not deleted",
       expect=TEMP, script=S)

# A macro that could not be deleted is not named.
mutate(F,
       "\tif macro.left then\n\t\tadd(FAIL, TEMP_MACRO",
       "\tif false then\n\t\tadd(FAIL, TEMP_MACRO",
       "selftest-launch: a macro left behind is not reported",
       expect="selftest-launch: a temporary macro that cannot be deleted is a FAIL naming it", script=S)

# A macro is made without being asked.
mutate(F,
       "\tif not ctx.opts.createMacro then\n",
       "\tif false then\n",
       "selftest-launch: a macro is made unasked",
       expect="selftest-launch: with no macro and not asked, none is made and the macro checks say why", script=S)

# A full macro list is not met with a reason.
mutate(F,
       "\tif not made or type(Plain(made1)) ~= \"number\" or made1 <= 0 then\n",
       "\tif false then\n",
       "selftest-launch: a macro that could not be made is used all the same",
       expect="selftest-launch: a full macro list is a CHECK, not a fault, and nothing is left", script=S)

# The cursor is left holding the macro.
mutate(F,
       "\tpcall(clear)\n\tlocal _, kindAfter = Ask(info)\n",
       "\tlocal _, kindAfter = Ask(info)\n",
       "selftest-launch: the cursor is not emptied",
       expect=OWN, script=S)

# Whatever the player carries is emptied for the test.
mutate(F,
       "\tif okHeld == true and heldKind ~= nil then\n",
       "\tif false then\n",
       "selftest-launch: a busy cursor is not left alone",
       expect="selftest-launch: a busy cursor is left alone", script=S)

# The game's own tooltip is the one anchored.
mutate(F,
       "\tlocal tip = CreateFrame(\"GameTooltip\", \"MannersSelftestTooltip\", UIParent, \"GameTooltipTemplate\")\n",
       "\tlocal tip = _G.GameTooltip\n",
       "selftest-launch: the game's tooltip is used",
       expect="selftest-launch: the game's tooltip is never the one tried", script=S)

# ---- a fight

# Run in a fight.
mutate(F,
       "\tif InCombatLockdown() then\n\t\tresults[1] = { id = \"launch.combat\"",
       "\tif false then\n\t\tresults[1] = { id = \"launch.combat\"",
       "selftest-launch: runs in a fight",
       expect="selftest-launch: refused in combat, no protected call", script=S)

# ---- one failure never stops the report

mutate(F,
       "\t\tlocal ok, err = pcall(check.run, add, ctx)\n",
       "\t\tlocal ok, err = true, check.run(add, ctx)\n",
       "selftest-launch: a throwing check stops the report",
       expect="selftest-launch: a check that errors outright is a FAIL with the error", script=S)

# ---- verdicts: the client answering something else

mutate(F,
       "\tif afterSet.spellKnown and afterClear.spell ~= nil then\n",
       "\tif false then\n",
       "selftest-launch: a spell left by an empty string passes",
       expect="selftest-launch: a client that does not clear the slot with an empty string is a CHECK", script=S)

mutate(F,
       "\tif type(setSpell) ~= \"function\" then\n\t\tadd(CHECK, \"SetMacroSpell is missing",
       "\tif type(setSpell) ~= \"function\" then\n\t\tadd(PASS, \"SetMacroSpell is missing",
       "selftest-launch: a missing SetMacroSpell passes",
       expect="selftest-launch: SetMacroSpell missing reads CHECK", script=S)

mutate(F,
       "\telseif face.accepted ~= true or face.textErr or type(face.width) ~= \"number\" or face.width <= 0 then\n",
       "\telseif false then\n",
       "selftest-launch: a refused font passes",
       expect="selftest-launch: a font file the client refuses reads CHECK, here and on the looks that use it", script=S)

mutate(F,
       "\t\t\t\telseif Lower(row.font) ~= Lower(MORPHEUS) then bad(",
       "\t\t\t\telseif false then bad(",
       "selftest-launch: a look not in Morpheus passes",
       expect="selftest-launch: a font file the client refuses reads CHECK, here and on the looks that use it", script=S)

mutate(F,
       "\telseif made == nil then\n\t\tadd(FAIL, \"CreateMaskTexture answered nothing",
       "\telseif false then\n\t\tadd(FAIL, \"CreateMaskTexture answered nothing",
       "selftest-launch: no mask made passes",
       expect="selftest-launch: a CreateMaskTexture that answers nothing reads FAIL", script=S)

mutate(F,
       "\t\t\t\telseif row.masks < 1 or (row.masksShown or row.masks) < 1 then bad(",
       "\t\t\t\telseif false then bad(",
       "selftest-launch: an icon with no mask passes",
       expect="selftest-launch: no mask on the icon of a look that cuts it reads CHECK", script=S)

# Masks that are all hidden count as masks.
mutate(F,
       "\t\t\t\telseif row.masks < 1 or (row.masksShown or row.masks) < 1 then bad(",
       "\t\t\t\telseif row.masks < 1 then bad(",
       "selftest-launch: hidden masks count as masks",
       expect="selftest-launch: masks on the icon that are all hidden read CHECK, and the count says how many are shown", script=S)

mutate(F,
       "\tif type(clip.SetClipsChildren) ~= \"function\" then\n\t\tadd(CHECK,",
       "\tif type(clip.SetClipsChildren) ~= \"function\" then\n\t\tadd(PASS,",
       "selftest-launch: no SetClipsChildren passes",
       expect="selftest-launch: no SetClipsChildren reads CHECK", script=S)

mutate(F,
       "\telseif does ~= true or (okOff2 == true and doesOff ~= false) then\n\t\tadd(CHECK,",
       "\telseif does ~= true or (okOff2 == true and doesOff ~= false) then\n\t\tadd(PASS,",
       "selftest-launch: a frame that does not clip passes",
       expect="selftest-launch: a frame that does not read back as clipping reads CHECK", script=S)

mutate(F,
       "\t\t\tif expect.clip and clipApi and tree.listed and tree.clips < 1 then bad(",
       "\t\t\tif false then bad(",
       "selftest-launch: a Letter that clips nothing passes",
       expect="selftest-launch: a Letter with nothing clipping reads CHECK", script=S)

mutate(F,
       "\telseif type(Plain(urx)) ~= \"number\" or math.abs(urx - 6) > 0.01 then\n",
       "\telseif false then\n",
       "selftest-launch: a tiling span that is dropped passes",
       expect="selftest-launch: tiling: a span that is not kept reads CHECK", script=S)

mutate(F,
       "\telseif #missing > 0 or #made < 4 then\n",
       "\telseif false then\n",
       "selftest-launch: an animation setting that is missing passes",
       expect="selftest-launch: animations: a setting the client lacks reads CHECK", script=S)

mutate(F,
       "\t\t\tadd(FAIL, \"applying it threw: \" .. row.err, label, id)\n",
       "\t\t\tadd(PASS, \"applying it threw: \" .. row.err, label, id)\n",
       "selftest-launch: a look that throws passes",
       expect="selftest-launch: a look that throws is its own FAIL and the style still goes back", script=S)

mutate(F,
       "\t\t\tif not row.matches then\n\t\t\t\tst = FAIL\n",
       "\t\t\tif false then\n\t\t\t\tst = FAIL\n",
       "selftest-launch: a look that is not on the prompt passes",
       expect="selftest-launch: a look that does not end up on the prompt is a FAIL", script=S)

mutate(F,
       "\telseif #drift > 0 then\n",
       "\telseif false then\n",
       "selftest-launch: a card with its icon hidden passes",
       expect="selftest-launch: the picker's cards, drawn and not", script=S)

mutate(F,
       "\t\telseif type(Plain(short)) ~= \"string\" or short == \"\" then\n",
       "\t\telseif false then\n",
       "selftest-launch: an empty glyph passes",
       expect="selftest-launch: the key glyphs, answered and not", script=S)

mutate(F,
       "\t\tif name ~= \"GamePadEnable\" and (ok ~= true or Plain(value) == nil) then\n",
       "\t\tif false then\n",
       "selftest-launch: an unreadable pad CVar passes",
       expect="selftest-launch: the key glyphs, answered and not", script=S)

mutate(F,
       "\t{ \"MODIFIER_STATE_CHANGED\", FAIL,",
       "\t{ \"MODIFIER_STATE_CHANGED\", CHECK,",
       "selftest-launch: a refused Shift event is only a CHECK",
       expect="selftest-launch: an event the client refuses (MODIFIER_STATE_CHANGED) reads FAIL", script=S)

mutate(F,
       "\t\tif not known then worse(command .. \" is not a slash command here, so the macro's line would do nothing\")\n"
       "\t\telseif type(handler) ~= \"function\" then worse(command .. \" has no handler\") end\n",
       "\t\tlocal _ = known\n",
       "selftest-launch: a missing /cleartarget passes",
       expect="selftest-launch: slash commands the client does not have read CHECK", script=S)

mutate(F,
       "\telseif okX == true and Plain(exists) == false and Plain(guid) ~= nil then\n",
       "\telseif false then\n",
       "selftest-launch: a GUID with nothing targeted passes",
       expect="selftest-launch: a client with nothing targeted that still answers a GUID reads CHECK", script=S)

mutate(F,
       "\tif not ok or (ns.errorCount or #(ns.errors or {})) ~= errors then\n",
       "\tif false then\n",
       "selftest-launch: a restyle that errors passes",
       expect="selftest-launch: a restyle that errors reads FAIL", script=S)

mutate(F,
       "\tif not same then worse(CHECK,",
       "\tif false then worse(CHECK,",
       "selftest-launch: a restyle that moves the prompt passes",
       expect="selftest-launch: a restyle that moves the prompt reads CHECK", script=S)

# The listening never calls a loop a loop.
mutate(F,
       "\telseif late > 0 then\n",
       "\telseif false then\n",
       "selftest-launch: an endless UPDATE_MACROS passes",
       expect="selftest-launch: UPDATE_MACROS after the calls, ordinary and endless", script=S)

# The listening ends at once.
mutate(F,
       "local LISTEN, QUIET_AFTER = 0.5, 0.25\n",
       "local LISTEN, QUIET_AFTER = 0.1, 0.25\n",
       "selftest-launch: the listening is shorter than it says",
       expect=CMD, script=S)

# ---- the command and the report

mutate("Selftest.lua",
       "arg:lower():match(\"^%s*launch%s*$\")",
       "arg:lower():match(\"^%s*launch\")",
       "selftest-launch: any word starting launch runs the launch checks",
       expect=CMD, script=S)

mutate("Commands.lua",
       "ns.Guard(\"selftest\", ns.Selftest.Command, rest)",
       "ns.Guard(\"selftest\", ns.Selftest.Command)",
       "selftest-launch: the command's word is not passed on",
       expect=CMD, script=S)

mutate("Selftest.lua",
       "\tif launch and Selftest.LaunchLines then\n",
       "\tif false and launch and Selftest.LaunchLines then\n",
       "selftest-launch: the report has no launch section",
       expect=CMD, script=S)

mutate(F,
       "\tif Selftest.launchPending then\n",
       "\tif false then\n",
       "selftest-launch: a second launch while the first listens",
       expect=CMD, script=S)

# The launch lines go missing from the chat.
mutate("Selftest.lua",
       "\tif launchCounts then\n",
       "\tif false then\n",
       "selftest-launch: no launch line in chat",
       expect=CMD, script=S)

# ---- the rest of the verdicts

# A style that could not be laid out again is not a FAIL.
mutate(F,
       "\tif sweep.restoreErr then worse(FAIL,",
       "\tif false then worse(FAIL,",
       "selftest-launch: a style that cannot be put back passes",
       expect="selftest-launch: SetFont refusing every face reads FAIL", script=S)

# A client that refuses even its own face is only a CHECK.
mutate(F,
       "\telseif control and (control.threw or control.accepted ~= true) then\n",
       "\telseif false then\n",
       "selftest-launch: SetFont refusing every face passes",
       expect="selftest-launch: SetFont refusing every face reads FAIL", script=S)

# No handler for a display change goes unnoticed.
mutate(F,
       "\t\tif type(handler) ~= \"function\" then worse(CHECK, name .. \" has no handler\") end\n",
       "\t\tlocal _ = handler\n",
       "selftest-launch: a missing display handler passes",
       expect="selftest-launch: no handler for a display change reads CHECK", script=S)

# A tooltip that cannot be anchored is only a CHECK.
mutate(F,
       "\t\t\tworse(FAIL, (\"the tooltip cannot be anchored %s the prompt\"):format(name))\n",
       "\t\t\tworse(CHECK, (\"the tooltip cannot be anchored %s the prompt\"):format(name))\n",
       "selftest-launch: a tooltip that cannot be anchored is only a CHECK",
       expect="selftest-launch: a tooltip that cannot be anchored reads FAIL", script=S)

# A Shift that cannot be read passes.
mutate(F,
       "\tif okS ~= true or type(Plain(held)) ~= \"boolean\" then\n",
       "\tif false then\n",
       "selftest-launch: an unreadable Shift passes",
       expect="selftest-launch: a Shift that cannot be read reads CHECK", script=S)

# A mask that does not attach passes.
mutate(F,
       "\telseif count ~= 1 or (okN2 == true and count2 ~= 0) then\n",
       "\telseif false then\n",
       "selftest-launch: a mask that does not attach passes",
       expect="selftest-launch: a mask that does not attach reads CHECK", script=S)

# A refused UPDATE_MACROS passes.
mutate(F,
       "\t{ \"UPDATE_MACROS\", CHECK,",
       "\t{ \"UPDATE_MACROS\", PASS,",
       "selftest-launch: a refused UPDATE_MACROS passes",
       expect="selftest-launch: an event the client refuses (UPDATE_MACROS) reads CHECK", script=S)

# The listening claims a result with no macro call made.
mutate(F,
       "\tif not ctx.macro then\n\t\tadd(CHECK, \"no macro call was made",
       "\tif not ctx.macro then\n\t\tadd(PASS, \"no macro call was made",
       "selftest-launch: a listening with nothing to hear passes",
       expect="selftest-launch: with no macro and not asked, none is made and the macro checks say why", script=S)
