# Mutations for validate.py's Lua 5.1 limits: a function over 55 upvalues and
# one over 190 active locals, each still under the compiler's own limit so the
# file compiles and it is the early warning that has to object, not a syntax
# error. The functions are written in whole rather than grown from one already
# in the addon, so trimming Prompt:Create() or Core.lua's file-level locals
# cannot quietly move either back under the line.

# 56 upvalues: the closure reads 56 locals of the function around it.
_names = ["m%d" % i for i in range(56)]
mutate("Flavour.lua",
       "local _, ns = ...\n",
       "local _, ns = ...\n"
       "local function tooManyUpvalues()\n"
       "\tlocal " + ", ".join(_names) + "\n"
       "\treturn function() return { " + ", ".join(_names) + " } end\n"
       "end\n",
       "a closure over 55 upvalues",
       expect="-- 56 upvalues (want at most 55)",
       script="validate.py")

# 191 locals active at once in one function.
mutate("Flavour.lua",
       "local _, ns = ...\n",
       "local _, ns = ...\n"
       "local function tooManyLocals()\n"
       + "".join("\tlocal l%d = %d\n" % (i, i) for i in range(191)) +
       "end\n",
       "a function over 190 active locals",
       expect="191 active locals (want at most 190)",
       script="validate.py")
