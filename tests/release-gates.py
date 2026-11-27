"""Focused regression checks for the release gates."""
import contextlib
import glob
import io
import os
from pathlib import Path
import runpy
import subprocess
import sys
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import install_package
import release

LAYOUT = ("Manners", {"Manners/Modules/X": "Manners_X"}, ["Libs/Test"], [])
FIXTURES = ROOT / "tests" / "fixtures" / "release-gates"


def scenario_parent(worker_output, worker_code):
    old_argv = sys.argv
    old_run = subprocess.run
    old_glob = glob.glob
    old_jobs = os.environ.get("MANNERS_SCENARIO_JOBS")
    output = io.StringIO()
    sys.argv = ["tests/runscenarios.py", "--baseline", "--jobs", "2"]
    os.environ["MANNERS_SCENARIO_JOBS"] = "2"
    subprocess.run = lambda *args, **kwargs: SimpleNamespace(
        stdout=worker_output, stderr="", returncode=worker_code)
    glob.glob = lambda pattern: []
    try:
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            try:
                runpy.run_path(str(ROOT / "tests" / "runscenarios.py"),
                               run_name="__main__")
            except SystemExit as error:
                status = error.code
    finally:
        sys.argv = old_argv
        subprocess.run = old_run
        glob.glob = old_glob
        if old_jobs is None:
            os.environ.pop("MANNERS_SCENARIO_JOBS", None)
        else:
            os.environ["MANNERS_SCENARIO_JOBS"] = old_jobs
    return status, output.getvalue()


def rejected(package, fragment):
    try:
        install_package.validate_tree(FIXTURES / package, LAYOUT, True)
    except install_package.InstallError as error:
        return fragment in str(error)
    return False


def release_without_package_step():
    old_run = release.run
    old_find_run = release.find_run
    old_watch = release.watch
    output = io.StringIO()
    release.run = lambda *args, **kwargs: SimpleNamespace(
        stdout="", stderr="", returncode=0)
    release.find_run = lambda *args: (123, "https://example.invalid/run/123")
    release.watch = lambda *args: True
    old_say = release.say
    release.say = lambda text="": output.write(text + "\n")
    try:
        status = release.tag_and_release(
            "9.9.9", "v9.9.9", "Manners 9.9.9", "a" * 40, 8, lambda number: None)
    finally:
        release.run = old_run
        release.find_run = old_find_run
        release.watch = old_watch
        release.say = old_say
    return status, output.getvalue()


failures = []

status, output = scenario_parent("", -9)
if status == 0 or "ended with signal 9" not in output:
    failures.append("a killed baseline worker was classified as passing")

status, output = scenario_parent(
    "  release-gates: expected scenario red\nfailures: 1\n", 1)
if status == 0 or "release-gates: expected scenario red" not in output:
    failures.append("an ordinary scenario failure stopped being red")

if not rejected("dead-toc", "Missing.lua"):
    failures.append("a dead packaged TOC reference was accepted")
if not rejected("malformed-toc", "unsafe TOC file"):
    failures.append("a malformed packaged TOC reference was accepted")
if not rejected("malformed-xml", "malformed XML"):
    failures.append("malformed packaged XML was accepted")
if not rejected("dead-library", "Libs\\Test\\Missing.lua"):
    failures.append("a dead packaged library reference was accepted")

status, output = release_without_package_step()
if status == 0 or "Released " in output:
    failures.append("release success was claimed without Package and publish")

if failures:
    for failure in failures:
        print("  release-gates: " + failure)
    raise SystemExit(1)
print("release-gates: all 7 focused checks passed")
print("RESULT: all checks passed")
