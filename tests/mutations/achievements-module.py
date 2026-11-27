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
    "\t\t\tdb.filter, db.page = SETTINGS.filter[value] and value or \"all\", 1",
    "\t\t\tdb.filter = SETTINGS.filter[value] and value or \"all\"",
    "achievements-module: a new filter keeps the page it was on",
    expect="changing what the list shows did not go back to its first page",
    script="runscenarios.py",
)

mutate(
    "Modules/Achievements/Achievements.lua",
    "\treturn List()[(Page() - 1) * PAGE_SIZE + i]",
    "\treturn List()[i]",
    "achievements-module: Next shows the same achievements",
    expect="Next did not show the ninth achievement first",
    script="runscenarios.py",
)