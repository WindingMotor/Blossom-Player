/// Library Page - Main interface for browsing and managing music library
import 'dart:math';
import 'package:blossom/custom/search_bar.dart';
import 'package:blossom/song_list/song_list_builder.dart';
import 'package:blossom/tools/nextcloud_sync.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import 'package:blossom/pages/settings_page.dart';

class SongLibrary extends StatefulWidget {
  final VoidCallback onThemeChanged;
  const SongLibrary({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  _SongLibraryState createState() => _SongLibraryState();
}

class _SongLibraryState extends State<SongLibrary>
    with TickerProviderStateMixin {
  final GlobalKey<SongListBuilderState> _songListBuilderKey =
      GlobalKey<SongListBuilderState>();

  late AnimationController _animationController;
  late Animation<double>   _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _filterButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController =
        UIHelpers.createFadeAnimationController(this);
    _fadeAnimation =
        UIHelpers.createFadeAnimation(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = Provider.of<NPlayer>(context, listen: false);
      player.loadSortSettings().then((_) {
        player.sortSongs(
          sortBy:    Settings.songSortBy,
          ascending: Settings.songSortAscending,
        );
        if (mounted) {
          setState(() {});
          _animationController.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToRandomSong() {
    final state = _songListBuilderKey.currentState;
    if (state != null) {
      final player    = Provider.of<NPlayer>(context, listen: false);
      final songCount = player.sortedSongs.length;
      if (songCount > 0) {
        final randomIndex    = Random().nextInt(songCount);
        const itemExtent     = 80.0;
        final scrollPosition = randomIndex * itemExtent;
        state.scrollToPosition(scrollPosition);
      }
    }
  }

  void _showSortMenu() {
    final player = context.read<NPlayer>();
    UIHelpers.showSortMenu(
      context,
      buttonKey: _filterButtonKey,
      items: [
        UIHelpers.buildPopupMenuItem(context,
            value: 'title',    icon: Icons.abc_rounded,
            isActive: player.sortBy == 'title'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'artist',   icon: Icons.person_rounded,
            isActive: player.sortBy == 'artist'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'album',    icon: Icons.album_rounded,
            isActive: player.sortBy == 'album'),
        const PopupMenuDivider(),
        UIHelpers.buildPopupMenuItem(context,
            value: 'favorite', icon: Icons.favorite_rounded,
            isActive: player.sortBy == 'favorite'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'plays',    icon: Icons.play_circle_outline_rounded,
            isActive: player.sortBy == 'plays'),
        const PopupMenuDivider(),
        UIHelpers.buildPopupMenuItem(context,
            value: 'duration', icon: Icons.timer_rounded,
            isActive: player.sortBy == 'duration'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'year',     icon: Icons.calendar_today_rounded,
            isActive: player.sortBy == 'year'),
        const PopupMenuDivider(),
        UIHelpers.buildPopupMenuItem(context,
            value: 'folder',   icon: Icons.folder_rounded,
            isActive: player.sortBy == 'folder'),
        UIHelpers.buildPopupMenuItem(context,
            value: 'modified', icon: Icons.update_rounded,
            isActive: player.sortBy == 'modified'),
      ],
    ).then((String? value) {
      if (value != null) {
        if (player.sortBy == value) {
          player.sortSongs(sortBy: value, ascending: !player.sortAscending);
        } else {
          player.sortSongs(sortBy: value);
        }
      }
    });
  }

  Widget _buildTrailingButtons() {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final currentSort   = UIHelpers.capitalize(player.sortBy);
        final sortDirection = player.sortAscending ? '↑' : '↓';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CloudSyncBadge(),
            const SizedBox(width: 4),
            UIHelpers.buildSortButton(
              context,
              key:          _filterButtonKey,
              onTap:        _showSortMenu,
              sortAscending: player.sortAscending,
              tooltip:      'Sorted by $currentSort $sortDirection',
            ),
            const SizedBox(width: 8),
            UIHelpers.buildIconButton(
              context,
              icon:    Icons.shuffle_rounded,
              onTap:   _scrollToRandomSong,
              tooltip: 'Shuffle',
            ),
            const SizedBox(width: 4),
            UIHelpers.buildIconButton(
              context,
              icon:  Icons.settings_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        SettingsPage(onThemeChanged: widget.onThemeChanged),
                  ),
                );
              },
              tooltip: 'Settings',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        return Scaffold(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.1),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  OptimizedSearchBar(
                    searchController: _searchController,
                    onSearchChanged: (value) {
                      if (value.length == 1) {
                        _songListBuilderKey.currentState?.scrollToPosition(0);
                        Settings.setLibraryScrollPosition(0);
                      }
                      player.setSearchQuery(value);
                    },
                    trailingWidget: _buildTrailingButtons(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: player.sortedSongs.isEmpty
                          ? UIHelpers.buildEmptyState(
                              context,
                              icon:     Icons.music_note_outlined,
                              title:    'No songs found',
                              subtitle: 'Add some music to get started',
                            )
                          : _buildSongList(player),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongList(NPlayer player) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: OrientationBuilder(
        builder: (context, orientation) {
          return SongListBuilder(
            key:         _songListBuilderKey,
            songs:       player.sortedSongs,
            orientation: orientation,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Cloud Sync Badge
// ─────────────────────────────────────────────────────────────────────────────

class _CloudSyncBadge extends StatefulWidget {
  const _CloudSyncBadge();

  @override
  State<_CloudSyncBadge> createState() => _CloudSyncBadgeState();
}

class _CloudSyncBadgeState extends State<_CloudSyncBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _onStatusChanged(SyncStatus status) {
    final active = status == SyncStatus.syncing ||
                   status == SyncStatus.checking;
    if (active && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!active && _spinController.isAnimating) {
      _spinController.stop();
      _spinController.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }
  }

  Color _dotColor(SyncStatus status, ColorScheme cs) {
    switch (status) {
      case SyncStatus.syncing:
      case SyncStatus.checking:
        return cs.primary;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return cs.error;
      default:
        return Colors.transparent;
    }
  }

  Color _iconColor(SyncStatus status, ColorScheme cs) {
    switch (status) {
      case SyncStatus.syncing:
      case SyncStatus.checking:
        return cs.primary;
      case SyncStatus.error:
        return cs.error;
      case SyncStatus.success:
        return cs.onSurface.withValues(alpha: 0.7);
      default:
        return cs.onSurface.withValues(alpha: 0.45);
    }
  }

  void _openSyncSheet(BuildContext context) {
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:   Colors.transparent,
      // Keep the sheet alive even while syncing is in progress.
      isDismissible:     true,
      builder:           (_) => const _SyncStatusSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NextcloudSync>(
      builder: (context, nc, _) {
        if (!nc.enabled || !nc.isConfigured) return const SizedBox.shrink();

        _onStatusChanged(nc.status);

        final cs       = Theme.of(context).colorScheme;
        final active   = nc.status == SyncStatus.syncing ||
                         nc.status == SyncStatus.checking;
        final dotColor = _dotColor(nc.status, cs);
        final iconCol  = _iconColor(nc.status, cs);

        return Tooltip(
          message: nc.statusMessage,
          child: GestureDetector(
            onTap: () => _openSyncSheet(context),
            child: SizedBox(
              width:  36,
              height: 36,
              child: Stack(
                alignment:    Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Cloud icon — rotates smoothly while syncing.
                  RotationTransition(
                    turns: _spinController,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        active
                            ? Icons.sync_rounded
                            : Icons.cloud_rounded,
                        key:   ValueKey(active),
                        size:  22,
                        color: iconCol,
                      ),
                    ),
                  ),

                  // Status dot (top-right).
                  Positioned(
                    top:   2,
                    right: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:    8,
                      height:   8,
                      decoration: BoxDecoration(
                        color:  dotColor,
                        shape:  BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                        boxShadow: dotColor != Colors.transparent
                            ? [
                                BoxShadow(
                                  color:        dotColor.withValues(alpha: 0.5),
                                  blurRadius:   4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sync Status Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SyncStatusSheet extends StatelessWidget {
  const _SyncStatusSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<NextcloudSync>(
      builder: (context, nc, _) {
        return _SyncSheetContent(nc: nc);
      },
    );
  }
}

class _SyncSheetContent extends StatelessWidget {
  final NextcloudSync nc;
  const _SyncSheetContent({required this.nc});

  bool get _isBusy =>
      nc.status == SyncStatus.syncing || nc.status == SyncStatus.checking;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ───────────────────────────────────────────────────
          Center(
            child: Container(
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                color:        cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              _StatusIcon(status: nc.status, cs: cs),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nextcloud Sync',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      nc.statusMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              // Cancel button — only visible while syncing.
              if (_isBusy)
                TextButton.icon(
                  onPressed: () {
                    nc.cancelSync();
                    Navigator.of(context).pop();
                  },
                  icon:  Icon(Icons.stop_circle_outlined,
                              color: cs.error, size: 18),
                  label: Text('Cancel',
                              style: TextStyle(color: cs.error)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Progress section ──────────────────────────────────────────────
          if (nc.progress != null) ...[
            _ProgressSection(progress: nc.progress!, cs: cs, theme: theme),
            const SizedBox(height: 16),
          ],

          // ── Last sync time ────────────────────────────────────────────────
          if (nc.lastSyncTime != null && nc.progress == null) ...[
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 14, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Text(
                  'Last synced: ${_formatTime(nc.lastSyncTime!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ── Action buttons ────────────────────────────────────────────────
          if (!_isBusy)
            _ActionButtons(nc: nc, context: context),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now  = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

// ── Status icon with built-in spin animation ─────────────────────────────────

class _StatusIcon extends StatefulWidget {
  final SyncStatus  status;
  final ColorScheme cs;
  const _StatusIcon({required this.status, required this.cs});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync:    this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didUpdateWidget(_StatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    final active = widget.status == SyncStatus.syncing ||
                   widget.status == SyncStatus.checking;
    if (active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!active && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _resolve(widget.status, widget.cs);
    return RotationTransition(
      turns: _ctrl,
      child: Container(
        width:  40,
        height: 40,
        decoration: BoxDecoration(
          color:  color.withValues(alpha: 0.12),
          shape:  BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  static (IconData, Color) _resolve(SyncStatus s, ColorScheme cs) =>
      switch (s) {
        SyncStatus.checking => (Icons.sync_rounded,         cs.primary),
        SyncStatus.syncing  => (Icons.sync_rounded,         cs.primary),
        SyncStatus.success  => (Icons.cloud_done_outlined,  Colors.green),
        SyncStatus.error    => (Icons.cloud_off_outlined,   cs.error),
        SyncStatus.idle     => (Icons.cloud_outlined,       cs.onSurface.withValues(alpha: 0.5)),
      };
}

// ── Progress detail section ───────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final SyncProgress progress;
  final ColorScheme  cs;
  final ThemeData    theme;
  const _ProgressSection({
    required this.progress,
    required this.cs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Byte-level progress bar.
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value:            progress.bytesFraction,
            minHeight:        6,
            backgroundColor:  cs.outline.withValues(alpha: 0.15),
            valueColor:       AlwaysStoppedAnimation(cs.primary),
          ),
        ),
        const SizedBox(height: 8),

        // File count + current file name.
        Row(
          children: [
            Expanded(
              child: Text(
                progress.currentFile,
                style:    theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${progress.completed}/${progress.total}',
              style: theme.textTheme.bodySmall?.copyWith(
                color:       cs.onSurface.withValues(alpha: 0.5),
                fontWeight:  FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Speed + ETA chips.
        Row(
          children: [
            _Chip(
              icon:  Icons.speed_rounded,
              label: progress.speedLabel,
              cs:    cs,
              theme: theme,
            ),
            const SizedBox(width: 12),
            _Chip(
              icon:  Icons.timer_outlined,
              label: progress.etaLabel,
              cs:    cs,
              theme: theme,
            ),
            const Spacer(),
            // Bytes transferred / total.
            Text(
              '${_fmtBytes(progress.transferredBytes)} / '
              '${_fmtBytes(progress.totalBytes)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _fmtBytes(int b) {
    if (b <= 0) return '0 B';
    if (b < 1024)                return '$b B';
    if (b < 1024 * 1024)         return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024)  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

class _Chip extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final ColorScheme cs;
  final ThemeData   theme;
  const _Chip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

// ── Action buttons shown when idle ────────────────────────────────────────────

class _ActionButtons extends StatefulWidget {
  final NextcloudSync nc;
  final BuildContext  context;
  const _ActionButtons({required this.nc, required this.context});

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final player = Provider.of<NPlayer>(context, listen: false);
      await widget.nc.manualSync(
        onReloadNeeded: () => player.reloadSongs(),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Dismiss / skip.
        Expanded(
          child: OutlinedButton(
            onPressed: _syncing
                ? null
                : () {
                    widget.nc.dismissPendingDiff();
                    Navigator.of(context).pop();
                  },
            style: OutlinedButton.styleFrom(
              shape:   RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Dismiss'),
          ),
        ),
        const SizedBox(width: 12),
        // Sync now.
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            icon: _syncing
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(_syncing ? 'Syncing…' : 'Sync Now'),
            onPressed: _syncing ? null : _syncNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}