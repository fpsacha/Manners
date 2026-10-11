"""What Blizzard's own API documentation says about the calls and events the
addon uses, read from the generated documentation of each client's UI source
(Gethe/wow-ui-source, Interface/AddOns/Blizzard_APIDocumentationGenerated).

tools/audit_apis.py asks "does this client have it". This asks "what does the
client say about it": which results come back as secret values and under what
restriction, which calls are restricted for addons, and what an event's payload
is, in what order, on each client.

    python tools/audit_docs.py --fetch DIR      # sparse clones, about 10 MB a client (needs git)
    python tools/audit_docs.py DIR secrets      # every API the addon calls whose docs name a Secret* rule
    python tools/audit_docs.py DIR restricted   # every API it calls that is restricted, or has a precondition
    python tools/audit_docs.py DIR events       # the payload of each event the addon handles, per client,
                                                # beside the handler's parameters
    python tools/audit_docs.py DIR shapes       # calls whose return types differ between clients
    python tools/audit_docs.py --help           # this text

DIR holds one folder per branch: live, forever, classic, classic_anniversary and
classic_era, as --fetch makes them (a branch missing from DIR is left out of the
report, and said once). Needs git for --fetch, and lupa for the addon's own
files, through tools/audit_apis.py, whose reader finds the calls. Nothing is
written but what --fetch clones into DIR. Exit status 0; 2 for a usage error
(an unknown subcommand, a DIR with no documentation in it, git missing).

What the documentation's own words mean (Blizzard_APIDocumentation):

  SecretWhen<X>Restricted    the result is a secret value while that restriction is on
  SecretReturns              always secret
  SecretArguments            "AllowedWhenUntainted": a secret may not be passed in from addon code
  HasRestrictions            addon code may be refused the call in some states
  Requires<X>                a precondition; the call errors when it does not hold
  RestrictedForMacroChatMessages  chat sent from a macro is refused during an instance encounter

A listed call is a place to read the code, not a finding: the addon passes
everything it branches on through ns.plain(), and each site is expected to.
`shapes` counts "cstring" as "string" and "FrameTime" as "number" (the same Lua
types under another documentation name), and compares nothing else.
"""
import os
import re
import shutil
import stat
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import audit_apis as A  # noqa: E402

BRANCHES = ("live", "forever", "classic", "classic_anniversary", "classic_era")
SPARSE = ("Interface/AddOns/Blizzard_APIDocumentationGenerated",)
DOCS = ("Interface", "AddOns", "Blizzard_APIDocumentationGenerated")
# Documentation names for the same Lua type.
TYPE_ALIAS = {"cstring": "string", "FrameTime": "number"}
FLAGS_OF_INTEREST = (
    "HasRestrictions", "IsProtectedFunction", "RequiresNonSecureCVar", "RequiresNonReadOnlyCVar",
    "RequiresValidAndPublicCVar", "IsNotSecure", "RestrictedForMacroChatMessages",
    "RequiresUnitAuraAccess", "RequiresNonSecretAura", "RequiresFontStringTextAccess",
    "RequiresValidFontAsset", "RequiresValidFontHeight", "RequiresLimitedInput",
)


def git(*command, **options):
    try:
        subprocess.run(["git"] + list(command), check=True, **options)
    except FileNotFoundError:
        sys.exit("--fetch needs git on the path")
    except subprocess.CalledProcessError as error:
        sys.exit("git %s failed (%d)" % (command[0], error.returncode))


def remove_tree(path):
    """A clone's packs are read-only on Windows; make each one writable and retry."""
    def writable(function, target, _info):
        os.chmod(target, stat.S_IWRITE)
        function(target)
    shutil.rmtree(path, onerror=writable)


def fetch(directory):
    os.makedirs(directory, exist_ok=True)
    for branch in BRANCHES:
        target = os.path.join(directory, branch)
        if os.path.isdir(os.path.join(target, *DOCS)):
            print("have", target)
            continue
        if os.path.isdir(target):
            # A clone that stopped half way leaves its .git and an empty tree.
            print("starting", target, "again")
            remove_tree(target)
        try:
            git("clone", "--quiet", "--depth", "1", "--filter=blob:none", "--sparse", "--branch", branch,
                "https://github.com/Gethe/wow-ui-source.git", target)
            git("sparse-checkout", "set", *SPARSE, cwd=target)
        except SystemExit:
            if os.path.isdir(target):
                remove_tree(target)
            raise
        print("cloned", target)


def parse_file(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    ns = re.search(r'Namespace = "([^"]+)"', text)
    ns = ns.group(1) if ns else None
    out = {}
    for m in re.finditer(r'\n\t\t\{\s*\n\s*Name = "([A-Za-z0-9_]+)",\s*\n\s*Type = "Function",(.*?)(?=\n\t\t\},)',
                         text, re.S):
        name = (ns + "." if ns else "") + m.group(1)
        head = m.group(2).split("Arguments =")[0].split("Returns =")[0]
        flags = re.findall(r"\n\s*([A-Z][A-Za-z]+) = ([^\n,]+)", "\n" + head)
        rets = re.search(r"Returns =\s*\{(.*?)\n\t\t\t\},", m.group(2), re.S)
        shape = tuple((TYPE_ALIAS.get(r[0], r[0]), r[1]) for r in re.findall(
            r'\{ Name = "[^"]+", Type = "([^"]+)"(?:, Nilable = (true|false))?', rets.group(1))) if rets else ()
        entry = {k: v.strip().strip('"') for k, v in flags if k != "Documentation"}
        entry["__shape"] = shape
        out[name] = entry
    return out


def index(directory):
    """name -> {flag: value}, with the first client to document a name winning."""
    out = {}
    for branch in BRANCHES:
        d = os.path.join(directory, branch, *DOCS)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".lua"):
                for k, v in parse_file(os.path.join(d, fn)).items():
                    entry = out.setdefault(k, {"flags": {}, "in": [], "shapes": {}})
                    shape = v.pop("__shape")
                    entry["flags"].update(v)
                    entry["in"].append(branch)
                    entry["shapes"][branch] = shape
    return out


def uses():
    calls, gets, _, _, _ = A.collect()
    out = {}
    for name, rel, line, _guard in calls:
        out.setdefault(name, set()).add((rel, line, "call"))
    for name, rel, line in gets:
        out.setdefault(name, set()).add((rel, line, "get"))
    return out


def report_secrets(directory):
    idx, used = index(directory), uses()
    for name in sorted(used):
        meta = idx.get(name)
        if not meta:
            continue
        secret = {k: v for k, v in meta["flags"].items() if k.startswith("SecretWhen") or k == "SecretReturns"}
        if not secret:
            continue
        print("%s  %s  [documented on %s]" % (name, ", ".join(sorted(secret)), ",".join(meta["in"])))
        for rel, line, kind in sorted(used[name])[:8]:
            print("    %s:%d %s: %s" % (rel, line, kind, A.source_line(rel, line)[:110]))


def report_restricted(directory):
    idx, used = index(directory), uses()
    for name in sorted(used):
        meta = idx.get(name)
        if not meta:
            continue
        flags = sorted(k for k in meta["flags"] if k in FLAGS_OF_INTEREST)
        if not flags:
            continue
        print("%s  %s  [documented on %s]" % (name, ", ".join(flags), ",".join(meta["in"])))
        for rel, line, kind in sorted(used[name])[:8]:
            print("    %s:%d %s: %s" % (rel, line, kind, A.source_line(rel, line)[:110]))


def report_shapes(directory):
    """Calls whose results are not the same list of types on every client that
    documents them: a table on one and several values on another is the shape
    of a Lua error on the client the code was not written for."""
    idx, used = index(directory), uses()
    for name in sorted(used):
        meta = idx.get(name)
        if not meta:
            continue
        groups = {}
        for branch, shape in meta["shapes"].items():
            groups.setdefault(shape, []).append(branch)
        if len(groups) > 1:
            print(name)
            for shape, branches in groups.items():
                print("    %-52s %s" % (",".join(branches), [t for t, _ in shape]))
            for rel, line, kind in sorted(used[name])[:4]:
                print("      %s:%d %s: %s" % (rel, line, kind, A.source_line(rel, line)[:100]))


def payloads(directory, events):
    out = {}
    for branch in BRANCHES:
        d = os.path.join(directory, branch, *DOCS)
        if not os.path.isdir(d):
            continue
        found = {}
        for fn in os.listdir(d):
            if not fn.endswith(".lua"):
                continue
            text = open(os.path.join(d, fn), encoding="utf-8", errors="replace").read()
            for m in re.finditer(r'LiteralName = "([A-Z_]+)",(.*?)\n\t\t\},', text, re.S):
                if m.group(1) in events:
                    found[m.group(1)] = re.findall(r'\{ Name = "([^"]+)"', m.group(2))
        out[branch] = found
    return out


def handlers():
    """event -> the parameters of `function addon:EVENT(...)`, wherever it is."""
    out = {}
    for rel in A.addon_files():
        text = open(os.path.join(ROOT, rel), encoding="utf-8-sig").read()
        for m in re.finditer(r"function addon:([A-Z][A-Z0-9_]+)\(([^)]*)\)", text):
            out[m.group(1)] = (rel, [p.strip() for p in m.group(2).split(",") if p.strip()])
    return out


def report_events(directory):
    have = handlers()
    pay = payloads(directory, set(have))
    print("handler parameters after the event name (an `_` skips one), against each client's payload:")
    for event in sorted(have):
        rel, params = have[event]
        print("\n%s  (%s)  handler: (%s)" % (event, rel, ", ".join(params)))
        seen = {}
        for branch in BRANCHES:
            fields = pay.get(branch, {}).get(event)
            if fields is None:
                continue
            seen.setdefault(tuple(fields), []).append(branch)
        for fields, branches in seen.items():
            print("    %-46s %s" % (",".join(branches), ", ".join(fields) or "(no payload)"))


def usage_error(message):
    sys.stderr.write("audit_docs.py: %s\n(python tools/audit_docs.py --help)\n" % message)
    sys.exit(2)


def main():
    args = sys.argv[1:]
    if args[:1] in (["-h"], ["--help"]):
        print(__doc__)
        return
    if args[:1] == ["--fetch"]:
        if len(args) != 2:
            usage_error("--fetch takes one directory")
        fetch(args[1])
        return
    reports = {"secrets": report_secrets, "restricted": report_restricted, "events": report_events,
               "shapes": report_shapes}
    if len(args) != 2 or args[1] not in reports:
        usage_error("expected DIR and one of %s" % " ".join(reports))
    directory = args[0]
    if not os.path.isdir(directory):
        usage_error("%s is not a directory (python tools/audit_docs.py --fetch %s makes it)"
                    % (directory, directory))
    have = [b for b in BRANCHES if os.path.isdir(os.path.join(directory, b, *DOCS))]
    if not have:
        usage_error("no <branch>/%s in %s (python tools/audit_docs.py --fetch %s clones them)"
                    % ("/".join(DOCS), directory, directory))
    for branch in BRANCHES:
        if branch not in have:
            print("note: no documentation for %s in %s, so it is left out" % (branch, directory))
    reports[args[1]](directory)


if __name__ == "__main__":
    main()
