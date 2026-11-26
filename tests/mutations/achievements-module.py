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
