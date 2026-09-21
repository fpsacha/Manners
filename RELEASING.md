# Releasing

`Libs/` is not in this repository. `.pkgmeta` declares all thirteen libraries
as build-time externals, so the packager fetches current upstream copies under
their own licences.

**A zip built from a clone has no libraries and the addon will not load.**
Build through the workflow.

## One-time setup

1. **Create the GitHub repository** and push:

   ```
   git remote add origin https://github.com/<you>/Manners.git
   git push -u origin main
   ```

2. **Create the CurseForge project.** Sign in, Author Dashboard, new WoW
   project. The slug becomes the URL. Category: Buffs & Debuffs. Paste the
   README as the description.

3. **Copy the numeric project id** from the project page and uncomment the
   `X-Curse-Project-ID` line in `Manners.toc`. The packager will not upload
   without it.

4. **Create an API token** at
   <https://legacy.curseforge.com/account/api-tokens> and add it to the GitHub
   repository as a secret named `CF_API_KEY`
   (Settings, Secrets and variables, Actions).

   `WOWI_API_TOKEN` and `WAGO_API_TOKEN` work the same way for those sites.
   Any destination without a token is skipped rather than failing the build.

## Each release

```
git tag v0.9.0
git push origin v0.9.0
```

The workflow runs the three suites, fails if any check has stopped being able
to detect the fault it exists for, packages, and uploads.

## Game version

The toc declares `## Interface: 16001`, which is WoW Forever (internally
"Camelot"). If the packager cannot map a brand-new interface number to a
CurseForge game version, the upload still succeeds and the version is set by
hand on the file page. Check it after the first release.

## Before the first upload

- [ ] Confirm the addon name is free on CurseForge
- [ ] Decide whether `verbose` should default on -- every user gets a chat line
      each time somebody buffs them
- [ ] The description should repeat what the toc says: Mage is tested in game,
      the other five classes are implemented but unverified
