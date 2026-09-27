"""Per-function upvalue and local counts, read out of Lua 5.1 bytecode.

The game runs Lua 5.1, where a function may capture at most 60 upvalues and
have at most 200 locals active at once. Past either, the file does not compile,
and a file that does not compile is an addon that does not load: 1.0.0-beta.6
shipped that way with Prompt:Create() at 69 upvalues, which no suite noticed
because they then ran a newer Lua that allows 255.

Counting by compiling the file and waiting for the error says only that a limit
has been crossed, after it has. What is wanted is how close each function is,
so that the merge that takes one to 56 goes red rather than the one that takes
it to 61. Lua 5.1's compiler writes exactly those numbers into the chunk
string.dump produces: every function prototype carries its upvalue count and,
in its debug information, each local's name and the range of instructions over
which it is live. The most locals active at once is the deepest overlap of
those ranges.

    import lua51_limits
    for f in lua51_limits.functions(path):
        f.line, f.upvalues, f.locals, f.name

Run directly, it prints the tightest functions in the files it is given.
"""
import struct, sys

# Lua 5.1's own limits (luaconf.h LUAI_MAXUPVALUES and LUAI_MAXVARS).
MAX_UPVALUES = 60
MAX_LOCALS = 200


class Function:
    """One function prototype: where it starts, and how full it is."""

    def __init__(self, source, line, last, upvalues, params, locvars, children):
        self.source = source
        self.line = line          # 0 for a file's main chunk
        self.last = last
        self.upvalues = upvalues
        self.params = params
        # (name, startpc, endpc) -- live from startpc up to, not including, endpc
        self.locvars = locvars
        self.children = children
        self.locals = most_active(locvars)

    @property
    def name(self):
        return "main chunk" if self.line == 0 else "function at line %d" % self.line


def most_active(locvars):
    """The most locals live at one instruction: the deepest overlap of ranges.

    This is what the compiler checks against 200 as it declares each local.
    Loop control variables ("(for index)" and friends) are locals to it and
    count, which is why they are left in.

    A range is taken as closed at both ends. A local declared as the last thing
    in its scope has no instruction after it, so its range is empty (startpc ==
    endpc) -- but the compiler counted it on the way in all the same, with every
    local around it, whose ranges end at that same pc. Half-open ranges read one
    short there: 186 locals in a row measured 185."""
    events = []
    for _, start, end in locvars:
        events.append((start, 0, 1))
        events.append((end, 1, -1))
    # At one pc, everything that opens there is counted before anything closes.
    events.sort()
    live = best = 0
    for _, _, step in events:
        live += step
        best = max(best, live)
    return best


class _Reader:
    """Lua 5.1's dump format (lundump.c), read in the byte order and sizes the
    header declares rather than assumed, since those follow the build."""

    def __init__(self, data):
        self.data = data
        self.pos = 0
        if data[:4] != b"\x1bLua" or data[4] != 0x51:
            raise ValueError("not a Lua 5.1 chunk")
        endian = "<" if data[6] == 1 else ">"
        self.int_size, self.size_t, self.instr_size, self.number_size = data[7:11]
        self.integral = data[11]
        self.endian = endian
        self.pos = 12

    def _unsigned(self, size):
        fmt = {1: "B", 2: "H", 4: "I", 8: "Q"}[size]
        value = struct.unpack_from(self.endian + fmt, self.data, self.pos)[0]
        self.pos += size
        return value

    def byte(self):
        value = self.data[self.pos]
        self.pos += 1
        return value

    def int(self):
        return self._unsigned(self.int_size)

    def string(self):
        size = self._unsigned(self.size_t)
        if size == 0:
            return None
        # Stored with its terminating NUL.
        value = self.data[self.pos:self.pos + size - 1]
        self.pos += size
        return value.decode("utf-8", "replace")

    def function(self, parent_source):
        source = self.string() or parent_source
        line = self.int()
        last = self.int()
        upvalues = self.byte()
        params = self.byte()
        self.byte()  # is_vararg
        self.byte()  # maxstacksize
        # The count is read before the skip is added up: `self.pos += self.int()
        # * n` would take self.pos before int() moved it, and land 4 bytes short.
        count = self.int()
        self.pos += count * self.instr_size                  # code
        for _ in range(self.int()):                          # constants
            kind = self.byte()
            if kind == 1:        # boolean
                self.pos += 1
            elif kind == 3:      # number
                self.pos += self.number_size
            elif kind == 4:      # string
                self.string()
            elif kind != 0:      # nil carries nothing; anything else is not 5.1
                raise ValueError("unknown constant type %d" % kind)
        children = [self.function(source) for _ in range(self.int())]
        lines = [self.int() for _ in range(self.int())]      # line of each instruction
        locvars = []
        for _ in range(self.int()):
            name = self.string()
            start = self.int()
            locvars.append((name, start, self.int()))
        for _ in range(self.int()):                          # upvalue names
            self.string()
        f = Function(source, line, last, upvalues, params, locvars, children)
        f.lines = lines
        return f


def parse(dump):
    """Every prototype in a chunk string.dump produced, outermost first."""
    top = _Reader(dump).function("?")
    top.parent = None
    out = []

    def walk(f):
        out.append(f)
        for c in f.children:
            c.parent = f
            walk(c)
    walk(top)
    return out


_runtime = None


def dump_file(path):
    """string.dump of the file compiled by Lua 5.1, or raise with its error."""
    global _runtime
    if _runtime is None:
        from lupa import lua51 as lupa
        # encoding=None: the dump is binary and must come back as bytes.
        _runtime = lupa.LuaRuntime(encoding=None, unpack_returned_tuples=True)
        _runtime.execute(b"function __manners_dump(src, name)\n"
                         b"  local f, err = loadstring(src, name)\n"
                         b"  if not f then return false, err end\n"
                         b"  return string.dump(f), false\n"
                         b"end")
    src = open(path, "rb").read()
    if src.startswith(b"\xef\xbb\xbf"):
        src = src[3:]
    dump, err = _runtime.globals()[b"__manners_dump"](src, b"@" + path.encode("utf-8"))
    if not dump:
        raise SyntaxError(err.decode("utf-8", "replace"))
    return dump


def functions(path):
    return parse(dump_file(path))


if __name__ == "__main__":
    rows = []
    for p in sys.argv[1:]:
        for f in functions(p):
            rows.append((max(f.upvalues / MAX_UPVALUES, f.locals / MAX_LOCALS), p, f))
    rows.sort(key=lambda r: -r[0])
    for _, p, f in rows[:20]:
        print("%-28s line %-5d upvalues %2d/%d  locals %3d/%d"
              % (p, f.line, f.upvalues, MAX_UPVALUES, f.locals, MAX_LOCALS))
