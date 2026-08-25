import 'dart:math';
import 'dart:ui';

import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/audio/song_data.dart';
import 'package:blossom/sheets/library_stats_sheet.dart';
import 'package:blossom/sheets/song_actions_sheet.dart';
import 'package:blossom/song_list/song_list_tile.dart';
import 'package:blossom/tools/app_navigation.dart';
import 'package:blossom/tools/library_stats.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Home tab: greeting + library hero, song shelves, and a swipeable
/// "Library insights" section that previews the full stats sheet.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Cached derived data — recomputed only when the library itself changes,
  // not on every playback notifyListeners().
  int _librarySignature = -1;
  List<Music> _recent = const [];
  List<(Music, int)> _mostPlayed = const [];
  List<Music> _favorites = const [];
  List<Music> _rediscover = const [];
  List<List<Music>> _albumPicks = const [];
  LibraryStats? _stats;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Up late?';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _refreshDerivedData(NPlayer player) {
    final songs = player.allSongs;
    final signature =
        Object.hash(songs.length, songs.where((s) => s.isFavorite).length);
    if (signature == _librarySignature) return;
    _librarySignature = signature;

    // Recently added
    final byDate = List<Music>.from(songs)
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    _recent = byDate.take(15).toList();

    // Most played
    final played = <(Music, int)>[];
    for (final song in songs) {
      final count = SongData.getPlayCount(song.path);
      if (count > 0) played.add((song, count));
    }
    played.sort((a, b) => b.$2.compareTo(a.$2));
    _mostPlayed = played.take(15).toList();

    // Favorites
    _favorites = songs.where((s) => s.isFavorite).take(15).toList();

    // Rediscover: never-played songs, in a daily-stable random order
    final daySeed = DateTime.now().day + DateTime.now().month * 31;
    final never = songs
        .where((s) => SongData.getPlayCount(s.path) == 0)
        .toList()
      ..shuffle(Random(daySeed));
    _rediscover = never.take(15).toList();

    // Daily album picks: albums with enough songs, rotated daily
    final albums = player.albumMap.values
        .where((list) => list.length >= 3 && list.first.picture != null)
        .toList()
      ..shuffle(Random(daySeed));
    _albumPicks = albums.take(10).toList();

    _stats = LibraryStats.compute(player);
  }

  void _playSongFromLibrary(NPlayer player, Music song) {
    final index = player.sortedSongs.indexWhere((s) => s.path == song.path);
    if (index != -1) {
      player.playSong(index);
    } else {
      // Filtered out of the sorted list (e.g. active search) — queue it.
      player.playNext(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Consumer<NPlayer>(
      builder: (context, player, _) {
        _refreshDerivedData(player);

        return ListView(
          // Top: clear the status bar (mobile has no app bar).
          // Bottom: clear the floating NPlayer widget + nav bar.
          padding: EdgeInsets.only(
            top: topInset + 12,
            bottom: 210 + bottomInset,
          ),
          children: [
            _HeroHeader(greeting: _greeting, player: player),

            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionTitle('Recently added'),
              _SongShelf(
                songs: _recent,
                onTap: (song) => _playSongFromLibrary(player, song),
              ),
            ],

            if (_albumPicks.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionTitle('Albums for today'),
              _AlbumShelf(albums: _albumPicks),
            ],

            if (_mostPlayed.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionTitle('Most played'),
              _SongShelf(
                songs: _mostPlayed.map((p) => p.$1).toList(),
                badges: {for (final p in _mostPlayed) p.$1.path: '${p.$2}×'},
                onTap: (song) => _playSongFromLibrary(player, song),
              ),
            ],

            if (_favorites.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionTitle('Favorites'),
              _SongShelf(
                songs: _favorites,
                onTap: (song) => _playSongFromLibrary(player, song),
              ),
            ],

            if (_rediscover.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionTitle('Rediscover — never played'),
              _SongShelf(
                songs: _rediscover,
                onTap: (song) => _playSongFromLibrary(player, song),
              ),
            ],

            if (_stats != null && _stats!.totalSongs > 0) ...[
              const SizedBox(height: 28),
              const _SectionTitle('Library insights'),
              _InsightsPager(stats: _stats!),
            ],

            if (player.allSongs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    Icon(Icons.library_music_outlined,
                        size: 56,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'Your library is empty',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add music to your device to get started',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Hero header with album-art mosaic backdrop ──────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String greeting;
  final NPlayer player;

  const _HeroHeader({required this.greeting, required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final withArt =
        player.allSongs.where((s) => s.picture != null).take(3).toList();
    final albumCount = player.allSongs.map((s) => s.album).toSet().length;
    final artistCount = player.allSongs.map((s) => s.artist).toSet().length;

    Widget stat(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          if (withArt.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Row(
                  children: [
                    for (final song in withArt)
                      Expanded(
                        child: Image(
                          image: AlbumArtCache.of(song.path, song.picture!),
                          fit: BoxFit.cover,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: ColoredBox(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.72),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'What do you want to listen to?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    stat('${player.allSongs.length}', 'Songs'),
                    stat('$albumCount', 'Albums'),
                    stat('$artistCount', 'Artists'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ─── Horizontal song shelf ───────────────────────────────────────────────────

class _SongShelf extends StatelessWidget {
  final List<Music> songs;
  final Map<String, String>? badges;
  final void Function(Music) onTap;

  const _SongShelf({
    required this.songs,
    required this.onTap,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final song = songs[index];
          final badge = badges?[song.path];
          return SizedBox(
            width: 112,
            child: InkWell(
              onTap: () => onTap(song),
              onLongPress: () => SongActionsSheet.show(context, song),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AlbumArtThumbnail(
                        picture: song.picture,
                        songPath: song.path,
                        size: 112,
                      ),
                      if (badge != null)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Horizontal album shelf (daily picks) ────────────────────────────────────

class _AlbumShelf extends StatelessWidget {
  final List<List<Music>> albums;

  const _AlbumShelf({required this.albums});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final songs = albums[index];
          final first = songs.first;
          return SizedBox(
            width: 128,
            child: InkWell(
              onTap: () =>
                  context.read<AppNavigationController>().openAlbum(first),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlbumArtThumbnail(
                    picture: first.picture,
                    songPath: first.path,
                    size: 128,
                    icon: Icons.album_rounded,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    first.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${first.artist} · ${songs.length} songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Library insights: swipeable stat cards + link to the full sheet ─────────

class _InsightsPager extends StatefulWidget {
  final LibraryStats stats;

  const _InsightsPager({required this.stats});

  @override
  State<_InsightsPager> createState() => _InsightsPagerState();
}

class _InsightsPagerState extends State<_InsightsPager> {
  final PageController _controller = PageController(viewportFraction: 0.88);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final stats = widget.stats;

    final cards = <Widget>[
      _InsightCard(
        icon: Icons.access_time_rounded,
        color: cs.primary,
        title: stats.formattedTotalDuration,
        subtitle: 'of music in your library',
        detail: '${stats.totalPlays} total plays',
      ),
      if (stats.topArtists.isNotEmpty)
        _InsightCard(
          icon: Icons.person_rounded,
          color: cs.secondary,
          title: stats.topArtists.first.name,
          subtitle: 'is your biggest artist',
          detail:
              '${stats.topArtists.first.songCount} songs · ${stats.topArtists.first.albumCount} albums',
        ),
      if (stats.genreBreakdown.isNotEmpty)
        _InsightCard(
          icon: Icons.category_rounded,
          color: cs.tertiary,
          title: stats.genreBreakdown.first.name,
          subtitle: 'is your top genre',
          detail:
              '${stats.genreBreakdown.first.percentage.toStringAsFixed(0)}% of your library',
        ),
      if (stats.topPlayed.isNotEmpty)
        _InsightCard(
          icon: Icons.repeat_rounded,
          color: cs.primary,
          title: stats.topPlayed.first.song.title,
          subtitle: 'is your most played song',
          detail: '${stats.topPlayed.first.playCount} plays',
        ),
      _InsightCard(
        icon: Icons.storage_rounded,
        color: cs.secondary,
        title: stats.formattedTotalSize,
        subtitle: 'on disk',
        detail:
            '${stats.totalSongs} songs · ${stats.totalAlbums} albums · ${stats.totalGenres} genres',
      ),
      // Final card links to the full stats sheet
      _InsightCard(
        icon: Icons.bar_chart_rounded,
        color: cs.primary,
        title: 'Full stats',
        subtitle: 'artists, albums, genres, years, folders & export',
        detail: 'Tap to open',
        onTap: () => showLibraryStatsSheet(context),
      ),
    ];

    return SizedBox(
      height: 132,
      child: PageView.builder(
        controller: _controller,
        itemCount: cards.length,
        padEnds: false,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(left: index == 0 ? 16 : 6, right: 6),
          child: cards[index],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String detail;
  final VoidCallback? onTap;

  const _InsightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
