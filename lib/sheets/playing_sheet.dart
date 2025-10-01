// ignore_for_file: depend_on_referenced_packages
import 'package:blossom/sheets/lyrics_sheet.dart';
import 'package:blossom/song_list/song_list_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

class PlayingSongsSheet extends StatefulWidget {
  const PlayingSongsSheet({Key? key}) : super(key: key);

  @override
  State<PlayingSongsSheet> createState() => _PlayingSongsSheetState();
}

class _PlayingSongsSheetState extends State<PlayingSongsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );



  // Cached statistics - computed once when sheet opens
  Duration _total = Duration.zero;
  int _albumCount = 0;
  
  // Limited songs for performance
  static const int _maxDisplaySongs = 50; // Increased for better UX
  
  // Key for accessing SongListBuilder
  final GlobalKey<SongListBuilderState> _songListBuilderKey =
      GlobalKey<SongListBuilderState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrent();
      }
    });
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Get limited songs list for performance - include previous songs
  List<Music> _getLimitedSongs(List<Music> allSongs, Music? currentSong) {
    if (allSongs.length <= _maxDisplaySongs) {
      return allSongs;
    }

    if (currentSong == null) {
      return allSongs.take(_maxDisplaySongs).toList();
    }

    // Find current song index
    final currentIndex = allSongs.indexWhere((song) => song.path == currentSong.path);
    if (currentIndex == -1) {
      return allSongs.take(_maxDisplaySongs).toList();
    }

    // Show 3 previous + current + remaining songs up to limit
    final startIndex = (currentIndex - 3).clamp(0, allSongs.length);
    final endIndex = (startIndex + _maxDisplaySongs).clamp(0, allSongs.length);
    
    return allSongs.sublist(startIndex, endIndex);
  }

  // Check if two lists have same order (for detecting shuffle)
  bool _listsEqual(List<Music> list1, List<Music> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].path != list2[i].path) return false;
    }
    return true;
  }

  // Compute stats once when sheet opens
  void _computeStats(List<Music> list) {
    _total = list.fold(Duration.zero,
        (d, s) => d + Duration(milliseconds: s.duration));
    _albumCount = list.map((m) => m.album).toSet().length;
  }

  // ----------  UI  ---------- //

  @override
  Widget build(BuildContext context) {
    return Selector<NPlayer, ({Music? current, List<Music> list})>(
      selector: (ctx, p) => (current: p.getCurrentSong(), list: p.playingSongs),
      shouldRebuild: (previous, next) => 
          previous.current?.path != next.current?.path || 
          previous.list.length != next.list.length ||
          !_listsEqual(previous.list, next.list),
      builder: (ctx, data, _) {
        if (data.current == null) return _emptyState(ctx);

        // Compute stats once
        _computeStats(data.list);
        
        // Get limited songs for better performance
        final limitedSongs = _getLimitedSongs(data.list, data.current);

        return FadeTransition(
          opacity: _fade,
          child: _sheet(ctx, data.current!, limitedSongs, data.list.length),
        );
      },
    );
  }

  Widget _sheet(BuildContext ctx, Music now, List<Music> displaySongs, int totalSongs) {
    final theme = Theme.of(ctx);
    return Container(
      height: MediaQuery.of(ctx).size.height * 0.85, // Slightly taller
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.1),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          _dragHandle(),
          _Header(now: now),
          const SizedBox(height: 6),
          _Stats(
            count: totalSongs,
            albums: _albumCount, 
            total: _total,
            displayCount: displaySongs.length,
          ),
          const SizedBox(height: 8),
          _controls(ctx),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _songList(ctx, displaySongs)),
                if (totalSongs > _maxDisplaySongs) 
                  _limitMessage(ctx, totalSongs),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // Improved limit message with better spacing
  Widget _limitMessage(BuildContext ctx, int totalSongs) {
    final theme = Theme.of(ctx);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Text(
              'Showing next $_maxDisplaySongs of $totalSongs songs',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------  Song List using SongListBuilder  ---------- //

  Widget _songList(BuildContext ctx, List<Music> songs) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return SongListBuilder(
          key: _songListBuilderKey,
          songs: songs,
          orientation: orientation,
        );
      },
    );
  }

  // ----------  Helpers  ---------- //

  void _scrollToCurrent() {
    final songListBuilderState = _songListBuilderKey.currentState;
    if (songListBuilderState != null) {
      final player = context.read<NPlayer>();
      final now = player.getCurrentSong();
      if (now == null) return;
      
      final allSongs = player.playingSongs;
      final currentIndex = allSongs.indexWhere((song) => song.path == now.path);
      if (currentIndex == -1) return;
      
      // Calculate the position in the limited list
      final startIndex = (currentIndex - 3).clamp(0, allSongs.length);
      final positionInLimitedList = currentIndex - startIndex;
      
      songListBuilderState.scrollToPosition(positionInLimitedList.toDouble());
    }
  }

  void _scrollToTop() {
    final songListBuilderState = _songListBuilderKey.currentState;
    if (songListBuilderState != null) {
      songListBuilderState.scrollToPosition(0);
    }
  }

  // ----------  Structural  ---------- //

  Widget _dragHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 4), // Reduced margins
          decoration: BoxDecoration(
            color: Colors.grey[350],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _controls(BuildContext ctx) {
    final theme = Theme.of(ctx);
    
    Widget button(IconData icon, String label, VoidCallback tap) {
      return Expanded(
        child: Material(
          color: theme.colorScheme.surface.withOpacity(.6),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), // Better padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          button(Icons.shuffle_rounded, 'Shuffle', () {
            HapticFeedback.lightImpact();
            context.read<NPlayer>().shuffle();
          }),
          const SizedBox(width: 10),
          button(
            Icons.my_location_rounded,
            'Current',
            () => _scrollToCurrent(),
          ),
          const SizedBox(width: 10),
          button(Icons.lyrics_rounded, 'Lyrics', () {
            final now = context.read<NPlayer>().getCurrentSong();
            if (now != null) {
              showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => LyricsSheet(
                  artist: now.artist,
                  title: now.title,
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext ctx) => Container(
        height: MediaQuery.of(ctx).size.height * .4,
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _dragHandle(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No songs in queue',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start playing music to see your queue',
                    style: Theme.of(ctx)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ==================  SUB-COMPONENTS  ================== //

class _Header extends StatelessWidget {
  final Music now;
  const _Header({required this.now});

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Better spacing
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(ctx),
              iconSize: 24,
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52, // Slightly larger
                height: 52,
                child: now.picture == null
                    ? Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.album_rounded,
                          size: 28,
                          color: Colors.grey[400],
                        ),
                      )
                    : Image.memory(
                        now.picture!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.album_rounded,
                            size: 28,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14), // Better spacing
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Playing Queue',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge // Larger title
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${now.title} • ${now.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Stats extends StatelessWidget {
  final int count;
  final int albums;
  final Duration total;
  final int displayCount;

  const _Stats({
    required this.count,
    required this.albums,
    required this.total,
    required this.displayCount,
  });

  @override
  Widget build(BuildContext ctx) {
    String fmt(Duration d) => d.inHours > 0
        ? '${d.inHours}h ${d.inMinutes.remainder(60)}m'
        : '${d.inMinutes}min';

    Widget item(IconData i, String v, String l) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 16, color: Theme.of(ctx).colorScheme.primary),
          const SizedBox(height: 2),
          Text(
            v, 
            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            l,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              fontSize: 10, 
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Better padding
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface.withOpacity(.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(ctx).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            item(Icons.queue_music_rounded, '$count', 'Total'),
            Container(
              height: 24,
              width: 1,
              color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2),
              margin: const EdgeInsets.symmetric(horizontal: 6),
            ),
            item(Icons.album_rounded, '$albums', 'Albums'),
            Container(
              height: 24,
              width: 1,
              color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2),
              margin: const EdgeInsets.symmetric(horizontal: 6),
            ),
            item(Icons.access_time_rounded, fmt(total), 'Duration'),
          ],
        ),
      ),
    );
  }
}