# The package is hash-checked, rejects unsafe paths and cannot lose Libs.

S = "validate.py"

mutate("tools/install_package.py",
       "            if not actual.is_file() or sha256(actual) != wanted:\n"
       "                raise InstallError(\"%s was not installed byte-for-byte (%s)\"\n"
       "                                   % (root, relative))\n",
       "",
       "package-install: changed files are not detected",
       expect="package-install: installed hashes were not checked",
       script=S)

mutate("tools/install_package.py",
       "    elif existing_libs.is_dir():\n"
       "        shutil.copytree(existing_libs, staged_libs)\n",
       "",
       "package-install: a source copy drops the installed libraries",
       expect="installation would remove libraries:",
       script=S)

mutate("tools/install_package.py",
       "            if pure.is_absolute() or not name or \"..\" in pure.parts:\n"
       "                raise InstallError(\"unsafe path in archive: %s\" % info.filename)\n",
       "",
       "package-install: a zip can write outside its staging folder",
       expect="package-install: archive traversal was accepted",
       script=S)

mutate("tools/install_package.py",
       "    if require_package_libs and missing:\n"
       "        raise InstallError(\"package is missing libraries: %s\" % \", \".join(missing))\n"
       "    if missing:\n"
       "        raise InstallError(\"installation would remove libraries: %s\" % \", \".join(missing))\n",
       "",
       "package-install: an incomplete release zip is accepted",
       expect="package-install: a package without libraries was accepted",
       script=S)

mutate("tools/install_package.py",
       "            touched.append((target, backup))\n",
       "",
       "package-install: rollback deletes or leaves a half-installed addon",
       expect="package-install: rollback changed an untouched addon or its libraries",
       script=S)
