# A delayed press may not clear a favour filed after the press.

mutate("Queue.lua",
       "\tif select(\"#\", ...) > 1 and owed[name] ~= expected then return false end\n",
       "",
       "old press clears a newer debt",
       expect="debt-race: anchor: a newer favour survives the old press",
       script="runscenarios.py")
