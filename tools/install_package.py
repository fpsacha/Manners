"""Stage, install and verify a Manners package without losing its libraries.

    python tools/install_package.py --source . \
        "D:/wow/World of Warcraft/_forever_/Interface/AddOns"
    python tools/install_package.py --zip Manners-1.12.2.zip \
        "D:/wow/World of Warcraft/_forever_/Interface/AddOns" --dry-run

Source mode preserves an existing Manners/Libs tree because Libs is not in
git. Zip mode refuses a release archive that does not contain every external
declared by .pkgmeta. Both modes hash every installed package file after the
copy and restore the previous addons if any replacement or verification fails.
"""
import argparse
import hashlib
import os
import re
import shutil
import sys
import tempfile
import uuid
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKGMETA = ROOT / ".pkgmeta"


class InstallError(RuntimeError):
    pass


def package_layout(root):
    text = (root / ".pkgmeta").read_text(encoding="utf-8")
    package = re.search(r"^package-as:\s*(\S+)", text, re.M)
    sections = {}
    section = None
    for line in text.splitlines():
        if line and not line.startswith((" ", "\t")) and line.endswith(":"):
            section = line[:-1]
            sections.setdefault(section, [])
        elif section and line.startswith("  "):
            sections[section].append(line.strip())
    moves = {}
    for entry in sections.get("move-folders", ()):
        match = re.match(r"([^:]+):\s*(\S+)$", entry)
        if match:
            moves[match.group(1)] = match.group(2)
    externals = []
    for entry in sections.get("externals", ()):
        match = re.match(r"(Libs/[^:]+):$", entry)
        if match:
            externals.append(match.group(1))
    ignored = [entry[2:].strip() for entry in sections.get("ignore", ())
               if entry.startswith("- ")]
    if not package or len(moves) != 5 or len(externals) != 14:
        raise InstallError("package layout in .pkgmeta is incomplete")
    return package.group(1), moves, externals, ignored


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def files(root):
    return {
        path.relative_to(root).as_posix(): sha256(path)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def validate_tree(stage, layout, require_package_libs):
    package, moves, externals, _ = layout
    roots = [package] + list(moves.values())
    for addon in roots:
        root = stage / addon
        if not root.is_dir() or not list(root.glob("*.toc")):
            raise InstallError("%s has no addon folder and toc" % addon)
    main = stage / package
    if not (main / "embeds.xml").is_file():
        raise InstallError("%s/embeds.xml is missing" % package)
    missing = []
    for external in externals:
        lib_root = main / external
        if not lib_root.is_dir() or not any(path.is_file() for path in lib_root.rglob("*")):
            missing.append(external)
    if require_package_libs and missing:
        raise InstallError("package is missing libraries: %s" % ", ".join(missing))
    if missing:
        raise InstallError("installation would remove libraries: %s" % ", ".join(missing))
    return roots


def extract_archive(archive, stage, layout):
    allowed, moves = layout[0], layout[1]
    roots = {allowed} | set(moves.values())
    seen = set()
    with zipfile.ZipFile(archive) as zipped:
        for info in zipped.infolist():
            name = info.filename.replace("\\", "/")
            pure = Path(name)
            if pure.is_absolute() or not name or ".." in pure.parts:
                raise InstallError("unsafe path in archive: %s" % info.filename)
            normalized = pure.as_posix().strip("/")
            if normalized in seen and not info.is_dir():
                raise InstallError("duplicate path in archive: %s" % normalized)
            seen.add(normalized)
            top = normalized.split("/", 1)[0]
            if top not in roots:
                raise InstallError("unexpected archive root: %s" % top)
            target = stage / normalized
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with zipped.open(info) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)


def copy_source(source, stage, destination, layout):
    package, moves, _, ignored = layout
    source = source.resolve()
    ignored = [item.replace("\\", "/").rstrip("/") for item in ignored]
    ignored += [".git", ".claude", ".github", "AGENTS.md", "Libs", ".pkgmeta",
                ".gitignore", ".gitattributes"]
    moved_sources = []
    for item in moves:
        item = item.replace("\\", "/").rstrip("/")
        prefix = package + "/"
        moved_sources.append(item[len(prefix):] if item.startswith(prefix) else item)

    def excluded(relative):
        value = relative.replace("\\", "/").rstrip("/")
        if value == "Modules":
            return False
        return any(value == item or value.startswith(item + "/")
                   for item in ignored + moved_sources)

    main = stage / package
    for path in sorted(source.rglob("*")):
        relative = path.relative_to(source)
        if excluded(relative.as_posix()) or path.is_dir() or path.name.endswith(".tmp"):
            continue
        target = main / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    for old, new in moves.items():
        prefix = package + "/"
        local = old[len(prefix):] if old.startswith(prefix) else old
        module = source / local
        if not module.is_dir():
            raise InstallError("source module is missing: %s" % local)
        shutil.copytree(module, stage / new)

    source_libs = source / "Libs"
    existing_libs = destination / package / "Libs"
    staged_libs = main / "Libs"
    if source_libs.is_dir():
        shutil.copytree(source_libs, staged_libs)
    elif existing_libs.is_dir():
        shutil.copytree(existing_libs, staged_libs)


def verify_installed(destination, roots, expected):
    for root, manifest in expected.items():
        installed = destination / root
        for relative, wanted in manifest.items():
            actual = installed / relative
            if not actual.is_file() or sha256(actual) != wanted:
                raise InstallError("%s was not installed byte-for-byte (%s)"
                                   % (root, relative))
    return expected


def install(stage, destination, roots, dry_run):
    expected = {root: files(stage / root) for root in roots}
    if dry_run:
        return sum(len(expected[root]) for root in roots)
    destination.mkdir(parents=True, exist_ok=True)
    token = ".manners-install-" + uuid.uuid4().hex
    touched = []
    try:
        for root in roots:
            target = destination / root
            backup = destination / (root + token)
            if target.exists():
                os.replace(target, backup)
            else:
                backup = None
            touched.append((target, backup))
            os.replace(stage / root, target)
        verify_installed(destination, roots, expected)
    except Exception:
        for target, backup in reversed(touched):
            if target.exists():
                shutil.rmtree(target)
            if backup is not None and backup.exists():
                os.replace(backup, target)
        raise
    for _, backup in touched:
        if backup is not None:
            shutil.rmtree(backup)
    return sum(len(files(destination / root)) for root in roots)


def prepare(args, workspace):
    layout = package_layout(ROOT if args.source is None else Path(args.source))
    if args.archive:
        extract_archive(Path(args.archive).resolve(), workspace, layout)
    else:
        copy_source(Path(args.source).resolve(), workspace, Path(args.destination).resolve(), layout)
    roots = validate_tree(workspace, layout, args.archive is not None)
    return roots


def selftest():
    def check(condition, message):
        if not condition:
            raise InstallError("package-install: " + message)

    with tempfile.TemporaryDirectory(prefix="manners-package-") as temporary:
        base = Path(temporary)
        package, moves, externals, ignored = package_layout(ROOT)
        source = base / "source"
        source.mkdir()
        (source / ".pkgmeta").write_bytes(PKGMETA.read_bytes())
        (source / "Manners.lua").write_text("return 1\n", encoding="utf-8")
        (source / "embeds.xml").write_text("<Ui />\n", encoding="utf-8")
        (source / "Manners.toc").write_text("## Interface: 16001\n", encoding="utf-8")
        (source / "Libs").mkdir()
        for external in externals:
            target = source / external
            target.mkdir(parents=True, exist_ok=True)
            (target / "Lib.lua").write_text("library\n", encoding="utf-8")
        for old in moves:
            prefix = package + "/"
            local = old[len(prefix):] if old.startswith(prefix) else old
            module = source / local
            module.mkdir(parents=True, exist_ok=True)
            (module / (Path(old).name + ".toc")).write_text("## Title: test\n", encoding="utf-8")
        destination = base / "AddOns"
        stage = base / "stage"
        stage.mkdir()
        layout = package_layout(source)
        copy_source(source, stage, destination, layout)
        roots = validate_tree(stage, layout, True)
        count = install(stage, destination, roots, False)
        check(count > 0, "an install copied no package files")
        sentinel = destination / package / "Libs" / "kept.txt"
        sentinel.write_text("keep\n", encoding="utf-8")
        before = sha256(sentinel)
        before_install = {root: files(destination / root) for root in roots}
        failure_stage = base / "failure-stage"
        failure_stage.mkdir()
        copy_source(source, failure_stage, destination, layout)
        real_replace = os.replace

        def fail_second_install(source_path, destination_path):
            if (Path(source_path).parent == failure_stage
                    and Path(destination_path) == destination / roots[1]):
                raise OSError("injected second-addon failure")
            return real_replace(source_path, destination_path)

        os.replace = fail_second_install
        try:
            install(failure_stage, destination, roots, False)
        except OSError:
            pass
        else:
            check(False, "the injected install failure did not stop the install")
        finally:
            os.replace = real_replace
        try:
            verify_installed(destination, roots, before_install)
        except InstallError:
            check(False, "rollback changed an untouched addon or its libraries")
        check(sentinel.is_file() and sha256(sentinel) == before,
              "rollback changed an untouched addon or its libraries")
        source_libs = source / "Libs"
        shutil.rmtree(source_libs)
        stage = base / "stage-two"
        stage.mkdir()
        copy_source(source, stage, destination, layout)
        roots = validate_tree(stage, layout, False)
        install(stage, destination, roots, False)
        check(sentinel.is_file() and sha256(sentinel) == before,
              "source install removed the installed libraries")
        bad = base / "unsafe.zip"
        with zipfile.ZipFile(bad, "w") as zipped:
            zipped.writestr("Manners/../../escape.lua", "bad")
        try:
            extract_archive(bad, base / "bad-stage", layout)
        except InstallError:
            pass
        else:
            check(False, "archive traversal was accepted")
        try:
            verify_installed(destination, ["not-an-addon"], {
                "not-an-addon": {"Manners.toc": "0" * 64},
            })
        except InstallError:
            pass
        else:
            check(False, "installed hashes were not checked")
        incomplete = base / "incomplete"
        shutil.copytree(destination / package, incomplete / package)
        shutil.rmtree(incomplete / package / "Libs")
        for root in roots:
            if root != package:
                shutil.copytree(destination / root, incomplete / root)
        try:
            validate_tree(incomplete, layout, True)
        except InstallError as error:
            check("package is missing libraries:" in str(error),
                  "an incomplete release was not identified as a package")
        else:
            check(False, "a package without libraries was accepted")
        archive = base / "Manners-valid.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zipped:
            for root in roots:
                for path in sorted((destination / root).rglob("*")):
                    if path.is_file():
                        zipped.write(path, path.relative_to(destination).as_posix())
        extracted = base / "from-zip"
        extracted.mkdir()
        extract_archive(archive, extracted, layout)
        zip_roots = validate_tree(extracted, layout, True)
        zip_destination = base / "zip-AddOns"
        count = install(extracted, zip_destination, zip_roots, False)
        check(count > 0, "a valid package zip copied no files")
        check((zip_destination / package / "Libs").is_dir(),
              "the valid package zip lost its libraries")
    print("package-install: all 7 install checks passed")


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--source", metavar="CHECKOUT")
    mode.add_argument("--zip", dest="archive", metavar="PACKAGE.zip")
    mode.add_argument("--selftest", action="store_true")
    parser.add_argument("destination", nargs="?")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return
    if not args.destination:
        parser.error("destination AddOns folder is required")
    destination = Path(args.destination).resolve()
    if destination.name.lower() != "addons":
        raise InstallError("destination must be an Interface/AddOns folder")
    with tempfile.TemporaryDirectory(prefix=".manners-stage-", dir=destination.parent) as temporary:
        workspace = Path(temporary)
        roots = prepare(args, workspace)
        count = install(workspace, destination, roots, args.dry_run)
        action = "verified" if args.dry_run else "installed"
        print("%s %d files in %s: %s" % (action, count, destination, ", ".join(roots)))


if __name__ == "__main__":
    try:
        main()
    except (InstallError, OSError, zipfile.BadZipFile) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
