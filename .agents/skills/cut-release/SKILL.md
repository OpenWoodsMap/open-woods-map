---
name: cut-release
description: >-
  Cut an OpenWoodsMap Android release: bump the version, tag, watch the Release
  APK workflow, and check the published APK on a device. Use when the user asks
  to release, ship, publish, tag a version, or put a build on GitHub Releases.
disable-model-invocation: false
---

# Cut a release (OpenWoodsMap)

The pipeline itself is `.github/workflows/release-apk.yml`, and
`docs/android_apk.md` explains the signing key and why it can never change.
This skill is the order of operations and the checks around it. Read the
workflow's comments if a step fails; each one says what its failure means.

Only release when the user has said to. A tag publishes to everyone watching
the repository through Obtainium, and a published release is not deleted to
fix a mistake: ship the next version instead.

## 1. Before touching the version

```powershell
$env:Path = "C:\_stuff\dev\tools\flutter\bin;$env:Path"
cd C:\_stuff\dev\open-woods-map
git status --short          # nothing unintended staged; _tmp* never committed
git log --oneline origin/main..HEAD
cd app; flutter analyze; flutter test; cd ..
```

Check that the latest push to `main` passed the CI workflow. The release
workflow runs analyze and test again, but finding a failure there wastes a tag.

Anything user-visible in the release should already have been looked at on a
device (`docs/devtest.md`). A release is the wrong place to find out.

## 2. Bump, commit, tag, push

`version:` in `app/pubspec.yaml` is `X.Y.Z+N`. Raise **both** parts. `+N` is the
Android version code, and it only goes up: a forgotten `+N` gives an update that
Android refuses to install. The convention so far is `+N` one higher than the
last release, e.g. `0.1.17+18` then `0.1.18+19`.

```powershell
git add app/pubspec.yaml
git commit -m "Release vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z - <one line on what changed for the user>"
git push origin main
git push origin vX.Y.Z
```

The tag without the `v` must match the pubspec version without `+N`. The
workflow refuses to publish if they disagree.

## 3. Watch the workflow

```powershell
gh run list --workflow release-apk.yml --limit 1
gh run watch <run id> --exit-status
```

It takes about ten minutes. In PowerShell, `gh ... --jq '<expr>'` gets its
argument split and fails. Use `--json` and pipe the output to
`ConvertFrom-Json` instead.

If it fails, read the `::error::` line. A secrets problem is reported before the
build starts. A failure in tests or signing means nothing was published. Fix
it, bump to the next patch version, and tag again. Don't move a pushed tag.

## 4. Check what was published, not what was built locally

```powershell
gh release view vX.Y.Z --json tagName,isDraft,assets | ConvertFrom-Json |
  ForEach-Object { $_.tagName; $_.assets | ForEach-Object { "$($_.name) $([math]::Round($_.size/1MB,1)) MB" } }
```

There should be exactly one `openwoodsmap-vX.Y.Z.apk`: the universal build,
86 MB as of v0.1.17. A per-ABI build is never published; the docs explain why.

Then install the published file on a device, over the previous version:

```powershell
New-Item -ItemType Directory -Force _tmp_rel | Out-Null
gh release download vX.Y.Z --dir _tmp_rel --clobber
# owm.ps1 install side-loads the local build; this is the release asset.
# Pick the device with `adb devices`; -r keeps the user's data.
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <serial> install -r _tmp_rel\openwoodsmap-vX.Y.Z.apk
```

`install -r` has to succeed as an **update**. If it fails with a signature
mismatch, the device holds a debug or local build. Uninstalling to get past
that wipes the user's waypoints, so ask before you do it. The app doesn't show
its version on screen, so confirm the new version with Android:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <serial> shell dumpsys package ca.openwoodsmap.open_woods_map |
  Select-String 'versionName|versionCode'
```

Then launch it and look at whatever this release changed. Afterwards, remove
`_tmp_rel`.

## 5. Tell the user

Say what version shipped, give a link to the release page, say what was checked
on a device, and name anything that wasn't checked.
