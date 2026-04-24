/// library_stats_sheet.dart
/// Bottom sheet that displays library statistics and provides JSON/CSV export.

import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/tools/library_stats.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Entry point – call this from SettingsPage
// ---------------------------------------------------------------------------

void showLibraryStatsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
      useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LibraryStatsSheet(),
  );
}

// ---------------------------------------------------------------------------
// Sheet widget
// ---------------------------------------------------------------------------

class _LibraryStatsSheet extends StatefulWidget {
  const _LibraryStatsSheet();

  @override
  State<_LibraryStatsSheet> createState() => _LibraryStatsSheetState();
}

class _LibraryStatsSheetState extends State<_LibraryStatsSheet>
    with SingleTickerProviderStateMixin {
  LibraryStats? _stats;
  bool _isExporting = false;
  late TabController _tabController;

  static const _tabs = ['Overview', 'Artists', 'Albums', 'Genres', 'Years', 'Folders'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _compute());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _compute() {
    final player = Provider.of<NPlayer>(context, listen: false);
    final stats = LibraryStats.compute(player);
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _export(String format) async {
    if (_stats == null || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      await _stats!.exportAndShare(format);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded,
                    color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Library Stats',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_stats != null) ...[
                  _ExportButton(
                    label: 'JSON',
                    icon: Icons.data_object_rounded,
                    onTap: _isExporting ? null : () => _export('json'),
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  _ExportButton(
                    label: 'CSV',
                    icon: Icons.table_chart_rounded,
                    onTap: _isExporting ? null : () => _export('csv'),
                    color: theme.colorScheme.tertiary,
                  ),
                ],
              ],
            ),
          ),

          if (_stats != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Generated ${_formatTimestamp(_stats!.generatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),

          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor:
                theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            indicatorColor: theme.colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _stats == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _OverviewTab(stats: _stats!),
                      _ArtistsTab(stats: _stats!),
                      _AlbumsTab(stats: _stats!),
                      _GenresTab(stats: _stats!),
                      _YearsTab(stats: _stats!),
                      _FoldersTab(stats: _stats!),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Export button
// ---------------------------------------------------------------------------

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 22),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _RankedTile extends StatelessWidget {
  final int rank;
  final String title;
  final String? subtitle;
  final String trailing;
  final String? trailingSubtitle;

  const _RankedTile({
    required this.rank,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.trailingSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTop3 = rank <= 3;
    final badgeColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : theme.colorScheme.surfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: isTop3 ? 1.0 : 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isTop3 ? Colors.black87 : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Trailing
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trailing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (trailingSubtitle != null)
                Text(
                  trailingSubtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bar chart row (used for genres, years, folders)
// ---------------------------------------------------------------------------

class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;
  final String? trailingLabel;

  const _BarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                trailingLabel ?? '$value',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.toDouble(),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Overview
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  final LibraryStats stats;
  const _OverviewTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.colorScheme.primary;
    final s = theme.colorScheme.secondary;
    final t = theme.colorScheme.tertiary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Top stat cards grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _StatCard(label: 'Songs', value: '${stats.totalSongs}', icon: Icons.music_note_rounded, color: p),
            _StatCard(label: 'Artists', value: '${stats.totalArtists}', icon: Icons.person_rounded, color: s),
            _StatCard(label: 'Albums', value: '${stats.totalAlbums}', icon: Icons.album_rounded, color: t),
            _StatCard(label: 'Genres', value: '${stats.totalGenres}', icon: Icons.category_rounded, color: p),
            _StatCard(label: 'Favorites', value: '${stats.favoritesCount}', icon: Icons.favorite_rounded, color: Colors.redAccent),
            _StatCard(label: 'Size', value: stats.formattedTotalSize, icon: Icons.storage_rounded, color: s),
          ],
        ),

        const SizedBox(height: 12),

        // Duration card (full width)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.withValues(alpha: 0.15), t.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time_rounded, color: p, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.formattedTotalDuration,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total listening time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const _SectionHeader('Extremes'),

        // Extreme tiles
        _ExtremeTile(
          icon: Icons.keyboard_arrow_up_rounded,
          label: 'Longest song',
          title: stats.longestSong?.title ?? '—',
          subtitle: stats.longestSong?.artist ?? '',
          badge: stats.longestSong != null
              ? _formatMs(stats.longestSong!.duration)
              : '',
          color: Colors.orange,
        ),
        const SizedBox(height: 6),
        _ExtremeTile(
          icon: Icons.keyboard_arrow_down_rounded,
          label: 'Shortest song',
          title: stats.shortestSong?.title ?? '—',
          subtitle: stats.shortestSong?.artist ?? '',
          badge: stats.shortestSong != null
              ? _formatMs(stats.shortestSong!.duration)
              : '',
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 6),
        _ExtremeTile(
          icon: Icons.upload_rounded,
          label: 'Largest file',
          title: stats.largestFile?.title ?? '—',
          subtitle: stats.largestFile?.artist ?? '',
          badge: stats.largestFile != null
              ? _formatBytes(stats.largestFile!.size)
              : '',
          color: Colors.deepPurple,
        ),
        const SizedBox(height: 6),
        _ExtremeTile(
          icon: Icons.download_rounded,
          label: 'Smallest file',
          title: stats.smallestFile?.title ?? '—',
          subtitle: stats.smallestFile?.artist ?? '',
          badge: stats.smallestFile != null
              ? _formatBytes(stats.smallestFile!.size)
              : '',
          color: Colors.teal,
        ),

        if (stats.topFavorites.isNotEmpty) ...[
          const _SectionHeader('Favorited Songs'),
          ...stats.topFavorites.take(10).map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.favorite_rounded,
                      color: Colors.redAccent, size: 18),
                  title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
        ],
      ],
    );
  }

  static String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _ExtremeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final String badge;
  final Color color;

  const _ExtremeTile({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600)),
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Artists
// ---------------------------------------------------------------------------

class _ArtistsTab extends StatelessWidget {
  final LibraryStats stats;
  const _ArtistsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final artists = stats.topArtists;
    if (artists.isEmpty) return const _EmptyState(message: 'No artist data');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: artists.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
      itemBuilder: (_, i) {
        final a = artists[i];
        return _RankedTile(
          rank: i + 1,
          title: a.name,
          subtitle:
              '${a.albumCount} ${a.albumCount == 1 ? 'album' : 'albums'}',
          trailing: '${a.songCount} songs',
          trailingSubtitle: a.formattedDuration,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Albums
// ---------------------------------------------------------------------------

class _AlbumsTab extends StatelessWidget {
  final LibraryStats stats;
  const _AlbumsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final albums = stats.topAlbums;
    if (albums.isEmpty) return const _EmptyState(message: 'No album data');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: albums.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
      itemBuilder: (_, i) {
        final a = albums[i];
        return _RankedTile(
          rank: i + 1,
          title: a.name,
          subtitle: a.artist + (a.year.isNotEmpty ? ' · ${a.year}' : ''),
          trailing: '${a.songCount} songs',
          trailingSubtitle: a.formattedDuration,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Genres
// ---------------------------------------------------------------------------

class _GenresTab extends StatelessWidget {
  final LibraryStats stats;
  const _GenresTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final genres = stats.genreBreakdown;
    if (genres.isEmpty) return const _EmptyState(message: 'No genre data');

    final maxCount = genres.first.songCount;
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: genres.length,
      itemBuilder: (_, i) {
        final g = genres[i];
        return _BarRow(
          label: g.name,
          value: g.songCount,
          maxValue: maxCount,
          color: colors[i % colors.length],
          trailingLabel:
              '${g.songCount} · ${g.percentage.toStringAsFixed(1)}%',
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Years
// ---------------------------------------------------------------------------

class _YearsTab extends StatelessWidget {
  final LibraryStats stats;
  const _YearsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final years = stats.songsByYear;
    if (years.isEmpty) return const _EmptyState(message: 'No year data');

    final maxCount = years.map((y) => y.songCount).reduce((a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.secondary;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: years.length,
      itemBuilder: (_, i) {
        final y = years[i];
        return _BarRow(
          label: y.year,
          value: y.songCount,
          maxValue: maxCount,
          color: color,
          trailingLabel: '${y.songCount} songs',
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Folders
// ---------------------------------------------------------------------------

class _FoldersTab extends StatelessWidget {
  final LibraryStats stats;
  const _FoldersTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final folders = stats.songsByFolder;
    if (folders.isEmpty) return const _EmptyState(message: 'No folder data');

    final maxCount = folders.values.reduce((a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.tertiary;
    final entries = folders.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return _BarRow(
          label: e.key,
          value: e.value,
          maxValue: maxCount,
          color: color,
          trailingLabel: '${e.value} songs',
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline,
              size: 40,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  )),
        ],
      ),
    );
  }
}