# Mutations for tests/scenarios/model-fixes.lua: the fuzzer's model and the
# layout scenario's class list, each put back as it read before round 37.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# The model forgets that Never inside an instance holds everybody back.
mutate("tests/fuzz_check.lua",
       "(f.quietInInstances == true and W.inInstance ~= nil)",
       "false",
       "model-fix: quiet in instances unknown to the model",
       expect="model-fix: the model knows Never inside an instance",
       script=S)

# The model calls the wearer's top-up a buff for the tank.
mutate("tests/fuzz_check.lua",
       "reason ~= \"asked\" and not wearsYours(W, e.name, buff) then",
       "reason ~= \"asked\" then",
       "model-fix: wearer of yours not allowed the top-up",
       expect="model-fix: the model lets the wearer of yours be offered the top-up",
       script=S)

# The layout scenario's classes lose the shaman and the evoker.
mutate("tests/scenarios/layout.lua",
       "\"WARLOCK\", \"SHAMAN\", \"EVOKER\" }",
       "\"WARLOCK\" }",
       "model-fix: layout classes without shaman and evoker",
       expect="model-fix: the layout scenario's classes include a shaman and an evoker",
       script=S)
