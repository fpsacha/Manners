# Mutations for the longer snoozes: the options window's Snooze menu and the
# minimap menu offer an hour, two hours and four (Commands.lua's
# SNOOZE_CHOICES, the header list in Options/Window/Layout.lua). The minimap
# list is re-aimed in tests/mutations/minimap.py.
# Each is caught by the scenario in tests/scenarios/snooze-long.lua that names it.

S = "runscenarios.py"

mutate("Commands.lua",
       "ns.SNOOZE_CHOICES = { 5, 15, 30, 60, 120, 240 }\n",
       "ns.SNOOZE_CHOICES = { 5, 15, 30 }\n",
       "snooze-long: the window's lengths stop at half an hour",
       expect="snooze-long: the window's snooze offers an hour, two and four", script=S)

mutate("Options/Window/Layout.lua",
       "\"general.snooze120\", \"general.snooze240\", \"general.snoozeSession\"",
       "\"general.snooze120\", \"general.snoozeSession\"",
       "snooze-long: the header's Snooze menu drops four hours",
       expect="snooze-long: the window's snooze offers an hour, two and four", script=S)
