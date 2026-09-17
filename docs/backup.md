# Backup: what is protected, and what is not

Waypoints and tracks are the only data in this app the user made themselves.
Everything else — packs, basemap tiles, seasons, policies — is a free download
that can be fetched again. So they are the only thing worth protecting, and the
only thing that cannot be replaced.

Until recently a waypoint existed in exactly one place: one file, on one phone.
Export could save it, but only if someone remembered to, and bulk delete ships
with a full-wipe option whose only protection is a snackbar that disappears in
four seconds.

## Two losses, not one

They are separate problems with separate answers, and conflating them is how an
app ends up protecting against the rare one while leaving the common one open.

| What goes wrong | How likely | Covered by |
| --- | --- | --- |
| A bulk delete confirmed too fast | Common | Copies on the phone |
| An import that replaced instead of merging | Common | Copies on the phone |
| A waypoints file that will not parse | Occasional | Copies on the phone |
| The app is uninstalled or its data cleared | Occasional | A backup file |
| The phone is lost, stolen, drowned, replaced | Certain, eventually | A backup file |

Both live on one screen — **Waypoints & tracks → ⋮ → Backup & restore** — because
to the person using the app these are one worry, and splitting them across two
places means the second is never found.

## Copies on the phone

`app/lib/backup/snapshot_store.dart`. Automatic, invisible, and free.

- Taken **before** a save replaces the list, never after. The state being written
  is about to exist in the waypoints file anyway; the state being replaced is the
  one about to stop existing anywhere.
- Taken on any save that removes items, and otherwise about once a day, so a
  list that only ever grows still has history behind it.
- Rate limited to one per ten minutes for removals. Somebody tidying up deletes
  repeatedly, and the state before the *first* deletion is a superset of the
  state before the fifth — so reusing the earlier copy keeps the more useful one
  and stops one sitting consuming the whole history.
- Gzipped, and the newest five are kept. A season of tracks is megabytes;
  several uncompressed copies would take back more than the feature gives.
- Waypoints only. Tag styling lives in its own file that no waypoint operation
  touches, so there is nothing here for a snapshot to guard.

They do not survive losing the phone, and the screen says so rather than letting
the reassurance of a list of copies imply otherwise.

## The backup file

`app/lib/backup/backup_file.dart`.

**A backup is not an export, and the difference is not cosmetic.** An export is a
file for somebody else's program, so it carries what that program understands and
nothing more — which is why the GPX and KML writers carry no tag styling and are
right not to. A backup is a file for this app to read back, so anything it omits
is data the user quietly loses on the day they need it.

It is still GeoJSON rather than a private format, because a backup outlives the
build that wrote it and may outlive the app. [RFC 7946 §6.1](https://datatracker.ietf.org/doc/html/rfc7946#section-6.1)
permits foreign members at the top level and requires a reader to ignore what it
does not understand, so the styling rides in an `openwoodsmap` member and one
file is both things: an ordinary collection of waypoints to CalTopo or QGIS, and
a complete restore for us.

That member is written **before** `features`, so anything working out what a file
is does not have to read megabytes of track geometry first.

Restoring **replaces** rather than merges — Import on the previous screen is the
merge — and preserves what it replaced first, outside the rate limit above.
Picking the wrong file is exactly the moment when "a copy was taken recently
enough" is no comfort.

### What the app is allowed to claim

It knows a file was produced. It does not know the file was kept. A backup sent
to a chat and never opened again is indistinguishable here from one saved to a
synced folder. So the screen may say *you have not made one in a while*, which is
true, and must never say *your waypoints are safe*, which it cannot know. Putting
the file somewhere that is not the phone is the user's part, and the page says so
plainly instead of implying the copies on the phone are enough.

## Operating-system backup

Android Auto Backup is on by default — `android:allowBackup` is unset, which
means true — so the waypoints file is already being copied to the user's Google
account, invisibly. iOS behaves the same way through iCloud backup of the
Documents directory.

This is worth knowing for two reasons, and neither is comfortable.

**It is a privacy default nobody chose.** Hunting spots leave the phone for a
Google account in an app built around having no accounts.

**It is probably not working.** The quota is 25 MB per app, and exceeding it
stops Auto Backup for that app silently. Two things in the same backed-up
directory blow straight through it:

- `app_flutter/offline_packs/` — installed province packs, tens of megabytes.
- `mbgl-offline.db` in the app's files directory — MapLibre's basemap tile store,
  which can reach hundreds of megabytes.

So anyone who has installed a pack has most likely had no OS backup at all, after
their bandwidth was spent uploading files that are a free download from the
Releases page.

**Open item.** The fix is directory-level exclusion, which is what the mechanism
is for: *back up what the user made, never back up what we can fetch again.* It
has not been written yet because a mis-named path in `dataExtractionRules` fails
silently, and the exact backup domain for Flutter's documents directory needs
checking on a device rather than guessing. Snapshots want excluding too — they
are already copies of a file being backed up beside them.

Note what excluding **tracks** would take, since it looks like the obvious lever
and is not: exclusion works per file, not per record, and tracks share
`open_woods_map_waypoints.json` with waypoints. Carving them out would mean
splitting the only copy of the user's data across two files, and it would not
help — at the recorder's 5 m point spacing, 25 MB is about 2,100 km of walking.
Tracks are not what is filling the quota.

## What is deliberately not built

**Dropbox, Google Drive and OneDrive integrations.** Each needs an OAuth app
registration and a client secret, which in a public open-source binary is not a
secret. Each needs the user to hold an account. That is three integrations to
maintain and three sets of API terms that can change underneath the app, against
[constraints.md](constraints.md)'s no-accounts rule and the project's tolerance
for future maintenance.

The decentralised version of the same idea — the user picks a folder once through
Android's Storage Access Framework, and whatever cloud app owns that folder does
the syncing — is a much better fit, needs no API key and works with providers
nobody here has heard of. It is not built yet because the maintained package for
it is Android-only, and [ios.md](ios.md) requires new packages to support iOS so
that door does not close quietly. iOS has a direct equivalent in
`UIDocumentPickerViewController` with security-scoped bookmarks, so the design
ports; somebody has to write that side.
