import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/messages.dart';
import '../waypoints/tag_style.dart';
import '../waypoints/waypoint_store.dart';
import 'backup_file.dart';
import 'backup_record.dart';
import 'snapshot_store.dart';

/// Backing up, and getting it back.
///
/// Two different protections live on this one screen, because to the user they
/// are one worry, and splitting them would mean nobody found the second.
///
/// The copies on the phone cover the likelier loss: something in this app
/// removed the waypoints — a bulk delete confirmed too fast, an import that
/// replaced rather than merged. They cost nothing and need no decisions.
///
/// The file covers the loss the phone cannot: the phone itself. That one needs
/// the user to put the file somewhere, and no amount of interface can do it for
/// them, so the page says so rather than implying the copies on the phone are
/// enough.
class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.store,
    required this.tagStyles,
    required this.snapshots,
    required this.record,
  });

  final WaypointStore store;
  final TagStyleStore tagStyles;
  final SnapshotStore snapshots;
  final BackupRecord record;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<Snapshot> _snapshots = const [];
  bool _loading = true;

  /// Whether the list was changed here, so the map knows to redraw on the way
  /// back rather than keeping markers for waypoints that no longer exist.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final snapshots = await widget.snapshots.list();
    if (!mounted) return;
    setState(() {
      _snapshots = snapshots;
      _loading = false;
    });
  }

  Future<void> _backUp() async {
    final items = widget.store.items;
    if (items.isEmpty) {
      showMessage(context, 'There is nothing to back up yet.');
      return;
    }
    final now = DateTime.now();
    final text = writeBackup(
      waypoints: items,
      tagStyles: widget.tagStyles.styles,
      createdAt: now,
    );
    final date = now.toIso8601String().split('T').first;
    final ShareResult shared;
    try {
      shared = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(text), mimeType: 'application/geo+json'),
          ],
          fileNameOverrides: ['openwoodsmap-backup-$date.geojson'],
          subject: 'OpenWoodsMap backup — ${describeItems(items)}',
        ),
      );
    } catch (error) {
      if (mounted) showMessage(context, 'Could not share the backup: $error');
      return;
    }
    // The status has to be read, not assumed. Recording unconditionally meant
    // that opening the chooser and backing out of it still wrote a backup down,
    // so the one screen whose job is to warn people instead reassured them:
    // dismiss the sheet and it said "Last backup today, and nothing has changed
    // since". That also silenced the stale-backup warning for the next 45 days.
    //
    // Success is still only "the user handed it to an app". Android reports the
    // component that was chosen, not what that component then did with the file,
    // so a share into a cloud app that later fails to sync counts here. That is
    // the ceiling on what this can know, and it is why the wording says "last
    // backup" and never "your waypoints are safe".
    //
    // Unavailable — desktop and web, where the platform cannot report at all —
    // deliberately does not count either. The cost is a build that keeps asking
    // somebody who has in fact made a backup, and the alternative is a build
    // that tells somebody they have one when they may not. Only one of those
    // loses data.
    if (shared.status != ShareResultStatus.success) {
      if (mounted && shared.status == ShareResultStatus.dismissed) {
        showMessage(context, 'Cancelled, so this does not count as a backup.');
      }
      return;
    }
    await widget.record.record(when: now, items: items.length);
    if (mounted) setState(() {});
  }

  Future<void> _restoreFromFile() async {
    final BackupContents contents;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['geojson', 'json'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw const FormatException('The file is unreadable.');
      contents = readBackup(utf8.decode(bytes));
    } catch (error) {
      if (mounted) showMessage(context, 'That file could not be read: $error');
      return;
    }
    if (contents.waypoints.isEmpty) {
      if (mounted) {
        showMessage(context, 'That file holds no waypoints or tracks.');
      }
      return;
    }
    await _restore(
      contents,
      from: 'that file',
      // Only a file of ours carries styling, so only a file of ours is allowed
      // to decide the styling. A GeoJSON from another app says nothing about
      // what a tag should look like, and clearing the user's colours on the
      // strength of that silence would be reading absence as instruction.
      replaceStyles: contents.isOwnBackup,
    );
  }

  Future<void> _restoreSnapshot(Snapshot snapshot) async {
    final contents = await widget.snapshots.read(snapshot.id);
    if (contents == null) {
      if (mounted) showMessage(context, 'That copy could not be read.');
      return;
    }
    await _restore(
      contents,
      from: 'the copy from ${_when(snapshot.takenAt)}',
      // Snapshots hold waypoints only, by design: no waypoint operation touches
      // the tag styling file, so there is nothing here for a snapshot to guard
      // and nothing for it to put back.
      replaceStyles: false,
    );
  }

  Future<void> _restore(
    BackupContents contents, {
    required String from,
    required bool replaceStyles,
  }) async {
    final current = widget.store.items;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore ${describeItems(contents.waypoints)}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current.isEmpty
                  ? 'Your list is empty, so this only adds.'
                  : 'This replaces your list. The '
                        '${describeItems(current)} in it now will be kept as a '
                        'copy on this phone, so you can come back from it.',
              style: const TextStyle(height: 1.35),
            ),
            if (replaceStyles && contents.tagStyles.isEmpty && current.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Nothing in this backup was styled, so any tag colours and '
                  'icons you have chosen since will be cleared too.',
                  style: TextStyle(height: 1.35),
                ),
              ),
            if (!replaceStyles && current.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Tag colours and icons are left as they are — this copy '
                  'carries none.',
                  style: TextStyle(height: 1.35),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Kept before anything is overwritten, and outside the rate limit that
    // governs ordinary editing: a restore is exactly the moment somebody
    // discovers they picked the wrong file, and "a snapshot was taken recently
    // enough" is no comfort then.
    await widget.snapshots.preserve(current);
    await widget.store.replaceAll(contents.waypoints);
    if (replaceStyles) await widget.tagStyles.replaceAll(contents.tagStyles);
    _changed = true;
    await _refresh();
    if (!mounted) return;
    showMessage(
      context,
      'Restored ${describeItems(contents.waypoints)} from $from.',
    );
  }

  Future<void> _forget(Snapshot snapshot) async {
    await widget.snapshots.delete(snapshot.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.store.items;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup & restore')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            AnimatedBuilder(
              animation: widget.record,
              builder: (context, _) => _Status(
                record: widget.record,
                items: items.length,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: items.isEmpty ? null : _backUp,
              icon: const Icon(Icons.save_alt),
              label: const Text('Make a backup file'),
            ),
            const SizedBox(height: 8),
            Text(
              'Writes everything — waypoints, tracks, tags and their styling — '
              'into one file, then hands it to whatever you want to send it '
              'to. Put it somewhere that is not this phone: a folder your '
              'cloud app syncs, a computer, an email to yourself. The app '
              'cannot do that part for you, and a copy that never leaves the '
              'phone does not survive losing the phone.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _restoreFromFile,
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Restore from a file'),
            ),
            const SizedBox(height: 8),
            Text(
              'Takes a backup file, or any GeoJSON of waypoints, and puts it '
              'back. This replaces your list rather than adding to it — use '
              'Import on the previous screen to merge one in instead.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const Divider(height: 36),
            Text('Copies on this phone', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              widget.snapshots.supported
                  ? 'Saved automatically before anything large is removed, and '
                        'now and then otherwise. The newest '
                        '${SnapshotStore.keep} are kept. These undo a mistake '
                        'made in the app; they do not survive losing the '
                        'phone, or uninstalling.'
                  : 'Not available on this platform.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_snapshots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'None yet. The first is saved the next time something is '
                  'removed.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              )
            else
              for (final snapshot in _snapshots)
                _SnapshotRow(
                  snapshot: snapshot,
                  onRestore: () => _restoreSnapshot(snapshot),
                  onForget: () => _forget(snapshot),
                ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.record, required this.items});

  final BackupRecord record;
  final int items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attention = record.needsAttention(items);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: attention ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            attention ? Icons.warning_amber : Icons.info_outline,
            color: attention ? scheme.onErrorContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              record.summary(items),
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: attention
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.snapshot,
    required this.onRestore,
    required this.onForget,
  });

  final Snapshot snapshot;
  final VoidCallback onRestore;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final readable = snapshot.describes != 'unreadable';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history),
      title: Text(_when(snapshot.takenAt)),
      subtitle: Text(
        readable
            ? '${snapshot.describes} · ${_size(snapshot.bytes)}'
            : 'This copy cannot be read.',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: readable ? onRestore : null,
            child: const Text('Restore'),
          ),
          IconButton(
            tooltip: 'Forget this copy',
            icon: const Icon(Icons.delete_outline),
            onPressed: onForget,
          ),
        ],
      ),
    );
  }
}

/// A date somebody can recognise, which is the whole job of the snapshot list.
///
/// Local time, because the user is choosing between "before I went out" and
/// "after I got back" and those are hours of their own day.
String _when(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final clock =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  final difference = today.difference(day).inDays;
  return switch (difference) {
    0 => 'Today at $clock',
    1 => 'Yesterday at $clock',
    < 7 => '$difference days ago at $clock',
    _ => '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} at $clock',
  };
}

String _size(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)} kB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
