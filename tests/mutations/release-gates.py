# Release gates: dead workers and incomplete packages must never be green.

S = "release-gates.py"

mutate("tests/runscenarios.py",
       "        if not saw_result or code not in (0, 1):\n"
       "            label = keys[n] if keys else \" \".join(tasks[n])\n"
       "            detail = \"signal %d\" % -code if code < 0 else \"exit code %d\" % code\n"
       "            line = \"SCENARIO HARNESS ERROR: worker %s ended with %s and no result\" % (label, detail)\n"
       "            lines.append(line)\n"
       "            if mine is not None:\n"
       "                mine.append(line)\n"
       "            broken = True\n",
       "",
       "release-gates: killed baseline worker is ignored",
       expect="release-gates: a killed baseline worker was classified as passing",
       script=S)

mutate("tools/install_package.py",
       "            for reference in validate_toc(root, toc):\n",
       "            for reference in ():\n",
       "release-gates: TOC references are not checked",
       expect="release-gates: a dead packaged TOC reference was accepted",
       script=S)

mutate("tools/install_package.py",
       "    if pure.is_absolute() or not pure.parts or \"..\" in pure.parts:\n",
       "    if False:\n",
       "release-gates: unsafe TOC paths are allowed",
       expect="release-gates: a malformed packaged TOC reference was accepted",
       script=S)

mutate("tools/install_package.py",
       "        parsed = ElementTree.fromstring(xml_file.read_text(encoding=\"utf-8\"))\n",
       "        parsed = ElementTree.fromstring(\"<Ui />\")\n",
       "release-gates: malformed XML is not parsed",
       expect="release-gates: malformed packaged XML was accepted",
       script=S)

mutate("tools/install_package.py",
       "    if not target.is_file():\n"
       "        raise InstallError(\"%s references missing %s: %s\"\n"
       "                           % (relative, kind, reference))\n",
       "",
       "release-gates: dead package references are not checked",
       expect="release-gates: a dead packaged library reference was accepted",
       script=S)

mutate("tools/release.py",
       "    if PACKAGE_STEP not in log_steps(log.stdout):\n"
       "        say(\"The release build reported success without the '%s' step; no release success\"\n"
       "            \" can be confirmed.\" % PACKAGE_STEP)\n"
       "        return 1\n",
       "",
       "release-gates: missing package step still releases",
       expect="release-gates: release success was claimed without Package and publish",
       script=S)
