import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blossom/tools/nextcloud_sync.dart';
import 'package:blossom/audio/nplayer.dart';

/// Call this once after NPlayer finishes initializing.
/// It runs the Nextcloud diff check and — if changes are found — shows a
/// bottom-sheet prompt. The user can Sync or Skip.
/// Called after LoadingPage confirms the library scan is stable.
/// [localMusic] is passed in directly from NPlayer.allSongs snapshot
/// so the diff builder has the complete library from the start.
Future<void> checkNextcloudOnStartup(
  BuildContext context, {
  List<Music>? localMusic,
}) async {
  final sync = NextcloudSync();
  if (!sync.isReady) return;

  // Fallback: read from provider if caller didn't pass the list
  final songs = localMusic ??
      List<Music>.unmodifiable(
        Provider.of<NPlayer>(context, listen: false).allSongs,
      );

  if (songs.isEmpty) return;  // nothing to diff against

  final diff = await sync.checkForChanges(localMusic: songs);
  if (diff == null || !diff.hasChanges) return;
  if (!context.mounted) return;

  await showModalBottomSheet(
    context:       context,
    isDismissible: true,
    builder:       (ctx) => _SyncPromptSheet(diff: diff),
  );
}

class _SyncPromptSheet extends StatefulWidget {
  final SyncDiff diff;
  const _SyncPromptSheet({required this.diff});

  @override
  State<_SyncPromptSheet> createState() => _SyncPromptSheetState();
}

class _SyncPromptSheetState extends State<_SyncPromptSheet> {
  bool _syncing = false;

  Future<void> _doSync() async {
    setState(() => _syncing = true);

    // FIX: use context directly — NPlayer is registered at the root
    // MultiProvider so this context (from showModalBottomSheet's builder
    // which inherits from the calling route) has access to it.
    final player = Provider.of<NPlayer>(context, listen: false);
    final nc     = NextcloudSync();

    await nc.applySync(
      onReloadNeeded: () => player.reloadSongs(),
    );

    if (mounted) Navigator.of(context).pop();
  }

  void _skip() {
    NextcloudSync().dismissPendingDiff();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final diff   = widget.diff;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.cloud_sync_outlined,
                    color: colors.secondary, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nextcloud Changes Detected',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${diff.totalChanges} file(s) out of sync',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Change summary ──────────────────────────────────────────────
            if (diff.toDownload.isNotEmpty)
              _ChangeTile(
                icon:  Icons.download_outlined,
                color: Colors.green,
                label: '${diff.toDownload.length} new/updated on Nextcloud',
              ),
            if (diff.toUpload.isNotEmpty)
              _ChangeTile(
                icon:  Icons.upload_outlined,
                color: colors.secondary,
                label: '${diff.toUpload.length} local song(s) not on Nextcloud',
              ),

            const SizedBox(height: 20),

            // ── Progress (shown while syncing) ─────────────────────────────
            // FIX: No ChangeNotifierProvider.value wrapper — NextcloudSync is
            // already at the root MultiProvider. Consumer resolves it directly.
            // FIX: Use bytesFraction + speedLabel + etaLabel from the updated
            //      SyncProgress model instead of the removed .fraction field.
            if (_syncing)
              Consumer<NextcloudSync>(
                builder: (_, nc, __) {
                  final progress = nc.progress;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Byte-level progress bar
                      LinearProgressIndicator(
                        value: progress?.bytesFraction,
                        backgroundColor: colors.outline.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(colors.secondary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      // Current file + file count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              progress?.currentFile ?? 'Preparing…',
                              style:    Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (progress != null)
                            Text(
                              '${progress.completed}/${progress.total}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.onSurface.withOpacity(0.5),
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Speed + ETA row
                      if (progress != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.speed,
                                    size:  12,
                                    color: colors.onSurface.withOpacity(0.4)),
                                const SizedBox(width: 4),
                                Text(
                                  progress.speedLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurface.withOpacity(0.5),
                                      ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size:  12,
                                    color: colors.onSurface.withOpacity(0.4)),
                                const SizedBox(width: 4),
                                Text(
                                  progress.etaLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurface.withOpacity(0.5),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

            // ── Action buttons ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _syncing ? null : _skip,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: _syncing
                        ? const SizedBox(
                            width:  16,
                            height: 16,
                            child:  CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync),
                    label: Text(_syncing ? 'Syncing…' : 'Sync Now'),
                    onPressed: _syncing ? null : _doSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.secondary,
                      foregroundColor: colors.onSecondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  const _ChangeTile(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}