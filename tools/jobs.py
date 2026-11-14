"""How many test processes to run at once when --jobs is not given.

    python tools/jobs.py          # prints the number and how it was reached

The cores less two (the machine stays usable), no more than the free memory
allows at GB_PER_JOB each, and no more than MANNERS_JOBS when that is set:

    MANNERS_JOBS=6 python tools/check.py --release     # bash
    $env:MANNERS_JOBS = 6; python tools/check.py ...   # PowerShell

MANNERS_JOBS is the cap to set while several agents or suites share the
machine; an explicit --jobs N on a command is taken as it is. check.py,
prove.py, fuzz.py, tests/runscenarios.py and tests/selftest.py all ask here,
so one variable caps them all.
"""
import os
import sys

# What one scenario process is allowed for: each loads the whole addon afresh
# per scenario and peaks at a few hundred MB; this leaves room for the copies
# of the tree and the rest of the machine.
GB_PER_JOB = 0.75
KEEP_FREE = 2       # cores


def free_gb():
    """Free physical memory in GB, or None where it cannot be asked."""
    try:
        if sys.platform == "win32":
            import ctypes

            class Status(ctypes.Structure):
                _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                            ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                            ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                            ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                            ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]

            status = Status()
            status.dwLength = ctypes.sizeof(Status)
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
                return status.ullAvailPhys / 2.0 ** 30
            return None
        with open("/proc/meminfo", encoding="ascii") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) / 2.0 ** 20
    except Exception:
        pass
    return None


def explain():
    """(the number, why): the default for --jobs on this machine now."""
    cores = os.cpu_count() or 4
    n = max(1, cores - KEEP_FREE)
    why = "%d cores less %d" % (cores, KEEP_FREE)
    free = free_gb()
    if free is not None:
        by_memory = max(1, int(free / GB_PER_JOB))
        if by_memory < n:
            n = by_memory
            why += "; %.1f GB free at %.2f GB a job allows %d" % (free, GB_PER_JOB, by_memory)
        else:
            why += "; %.1f GB free is enough" % free
    cap = os.environ.get("MANNERS_JOBS", "").strip()
    if cap:
        try:
            capped = max(1, int(cap))
            if capped < n:
                n = capped
                why += "; MANNERS_JOBS caps it at %d" % capped
        except ValueError:
            why += "; MANNERS_JOBS=%r is not a number and was ignored" % cap
    return n, why


def default_jobs():
    return explain()[0]


if __name__ == "__main__":
    print("%d jobs (%s)" % explain())
