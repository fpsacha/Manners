# My own words for an ask (Ask.lua, ask.line "own"): tests/scenarios/askown.lua.

S = "runscenarios.py"

mutate("Ask.lua",
       "\tif db.ask.line == \"own\" then\n",
       "\tif false then\n",
       "askown: my own words never said",
       expect="askown: my own words are what the ask says", script=S)

mutate("Ask.lua",
       "\t-- My own words, ahead of the In character set: the player wrote them.\n"
       "\tif db.ask.line == \"own\" then\n"
       "\t\t-- Empty, Fill gives nil and the plain line below is said.\n"
       "\t\tlocal text = Fill(Ask.CleanOwn(db.ask.own))\n"
       "\t\tif text and #text <= room then return text end\n"
       "\tend\n"
       "\tlocal rp = ns.InCharacter\n"
       "\tif rp and rp.Active and rp.Active(db.speech) then\n",
       "\tlocal rp = ns.InCharacter\n"
       "\tif rp and rp.Active and rp.Active(db.speech) then\n"
       "\t\tlocal own = db.ask.line == \"own\" and Fill(Ask.CleanOwn(db.ask.own)) or nil\n"
       "\t\tif false and own then return own end\n"
       "\telseif db.ask.line == \"own\" then\n"
       "\t\tlocal text = Fill(Ask.CleanOwn(db.ask.own))\n"
       "\t\tif text and #text <= room then return text end\n"
       "\tend\n"
       "\tif rp and rp.Active and rp.Active(db.speech) then\n",
       "askown: In character talks over my own words",
       expect="with In character the ask is", script=S)

mutate("Ask.lua",
       "\tif Ask.LINES[ask.line] == nil and ask.line ~= \"own\" then ask.line = Ask.LINE_ORDER[1] end\n",
       "\tif Ask.LINES[ask.line] == nil then ask.line = Ask.LINE_ORDER[1] end\n",
       "askown: the repair forgets the choice",
       expect="the repair turned the choice into", script=S)

mutate("Ask.lua",
       "\ttext = text:gsub(\"|\", \"\"):gsub(",
       "\ttext = text:gsub(\"\", \"\"):gsub(",
       "askown: a | kept in the macro",
       expect="askown: the repair keeps my own words", script=S)

mutate("Ask.lua",
       "\tif #text > Ask.OWN_MAX then\n\t\ttext = text:sub(1, Ask.OWN_MAX)\n"
       "\t\t-- Back up to a whole character: a cut in the middle of one would\n"
       "\t\t-- go into the macro as bytes that are no letter.\n"
       "\t\tlocal i = #text\n"
       "\t\twhile i > 0 and text:byte(i) >= 0x80 and text:byte(i) < 0xC0 do i = i - 1 end\n"
       "\t\tif i > 0 and text:byte(i) >= 0xC0 then\n"
       "\t\t\tlocal need = text:byte(i) >= 0xF0 and 4 or text:byte(i) >= 0xE0 and 3 or 2\n"
       "\t\t\tif #text - i + 1 < need then text = text:sub(1, i - 1) end\n"
       "\t\tend\n"
       "\tend\n",
       "",
       "askown: no length limit",
       expect="letters kept", script=S)

mutate("Options/Who.lua",
       "\t\thidden = function() return off() or ns.db.profile.ask.line ~= \"own\" end,\n",
       "\t\thidden = off,\n",
       "askown: the box shown for a plain line",
       expect="the box shows with a plain line chosen", script=S)

mutate("Options/Who.lua",
       "\t\t\tns.db.profile.ask.own = ns.Ask.CleanOwn(v)\n",
       "\t\t\tns.db.profile.ask.own = v\n",
       "askown: the box saves what it is given",
       expect="the box saved", script=S)

mutate("Ask.lua",
       "\treturn { moment = Ask.LINES.moment, may = Ask.LINES.may, mind = Ask.LINES.mind, own = L[\"My own words\"] }\n",
       "\treturn Ask.LINES\n",
       "askown: no choice for my own words",
       expect="What the ask says has no My own words", script=S)
