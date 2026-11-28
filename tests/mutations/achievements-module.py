mutate(
    "Modules/Achievements/Achievements.lua",
    "if st.capped[day][key] then return false end",
    "if false and st.capped[day][key] then return false end",
    "achievements-module: the daily per-person cap is required",
    expect="achievements-module: daily per-person caps stop spam",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    "if api:GetDB() then Initialize() end",
    "",
    "achievements-module: a late module never seeds after CoreReady",
    expect="achievements-module: a late module seeds after CoreReady",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    'Credit("returns", name, 1, false, at)',
    'Credit("returns", name, 1, false)',
    "achievements-module: historical rows cap today",
    expect="achievements-module: seed rows keep their historical days",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    'if notification ~= "toast" and notification ~= "chat" then notification = "none" end',
    'if notification ~= "chat" then notification = notification == "toast" or "none" end',
    "achievements-module: toast sanitizes to boolean true",
    expect="achievements-module: toast and chat stay literal notification choices",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    "for id in pairs(st.earned) do st.earned[id] = nil end",
    "",
    "achievements-module: an old save keeps medals earned against the old goals",
    expect="an old save keeps its counts and earns medals by the new goals",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    'if db.filter == "earned" then keep = keep and tier > 0',
    'if db.filter == "earned" then keep = keep',
    "achievements-module: Earned lists achievements not earned",
    expect="Earned lists",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    'api:RegisterCallback("Favour.Refused", OnRefused, A)',
    "",
    "achievements-module: a refused buff is never counted",
    expect="a refused buff did not reveal No Hard Feelings",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    "db.characters[CharacterKey()] = Fresh()",
    "local _ = Fresh()",
    "achievements-module: Start this character over keeps the progress",
    expect="Start this character over kept its progress",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    "Collect(st, st.givers, seen.name, \"givers\")",
    "local _ = 0",
    "achievements-module: people who buffed you are not counted",
    expect="two people who buffed you read",
    script="runscenarios.py",
)
mutate(
    "Modules/Achievements/Achievements.lua",
    'db.theme = (value == "all" or THEME[value]) and value or "all"',
    "db.theme = value",
    "achievements-module: an unknown kind is kept for the board",
    expect="an unknown kind was kept",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Board.lua",
    "local cols = math.max(1, math.min(CARD_MAX_COLS, math.floor((width + GAP) / (CARD_MIN + GAP))))",
    "local cols = 1",
    "achievements-module: the board keeps one column however wide",
    expect="columns, not two",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Board.lua",
    "for i = #list + 1, #row.cards do row.cards[i]:Hide() end",
    "local _ = list",
    "achievements-module: a filtered board keeps the cards it no longer lists",
    expect="Earned shows",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Board.lua",
    "A.SetView(b.field, b.value)",
    "local _ = b.field",
    "achievements-module: a tab on the board does nothing",
    expect="the Earned tab did not show what was earned",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Board.lua",
    "local CARD_MIN, CARD_MAX_COLS = 290, 2",
    "local CARD_MIN, CARD_MAX_COLS = 290, 3",
    "achievements-module: a wide board cramps three columns",
    expect="names get cut off past two",
    script="runscenarios.py",
)
mutate(
    "Modules/Achievements/Board.lua",
    "and L[\"Goal %d of %d\"]:format(tier + 1, #def.goals) or \"\")",
    "and \"\" or \"\")",
    "achievements-module: a card no longer says which goal it works toward",
    expect="does not say which goal it works toward",
    script="runscenarios.py",
)
mutate(
    "Modules/Achievements/Achievements.lua",
    "\tif tier < 1 or #def.goals < 2 then return nil end",
    "\tif tier < 1 then return nil end",
    "achievements-module: a single-goal achievement is named goal 1 of 1",
    expect="the goal reached is not named as a count",
    script="runscenarios.py",
)
