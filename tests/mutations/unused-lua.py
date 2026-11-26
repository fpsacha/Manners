# New unreferenced shipped Lua locals fail rather than silently accumulating.

mutate("tools/unused_lua.py",
       "    return [(name, line, kind) for name, line, kind in declarations if counts.get(name, 0) == 1]\n",
       "    return [(name, line, kind) for name, line, kind in declarations if counts.get(name, 0) > 1]\n",
       "unused-lua: unreferenced locals are not detected",
       expect="unused-lua:",
       script="validate.py")

mutate("tools/unused_lua.py",
       '            if "%s:%s:%s" % (relative, kind, name) not in known:\n'
       '                bad.append((path, line, name, kind))\n',
       '            bad.append((path, line, name, kind))\n',
       "unused-lua: the reviewed existing locals stop the gate",
       expect="Hints.lua:12: unused local local addonName",
       script="validate.py")
