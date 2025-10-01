// ignore_for_file: depend_on_referenced_packages
import 'package:blossom/sheets/lyrics_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';           // NEW
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

/// Caches already-decoded MemoryImages keyed by file path.
class ArtCache {
  static final _mem = <String, MemoryImage>{};

  static MemoryImage? fromBytes(String path, Uint8List? bytes) {
    if (bytes == null) return null;
    return _mem.putIfAbsent(
      path,
      () => MemoryImage(bytes, scale: 1.0),
    );
  }
}

class PlayingSongsSheet extends StatefulWidget {
  const PlayingSongsSheet({Key? key}) : super(key: key);

  @override
  State<PlayingSongsSheet> createState() => _PlayingSongsSheetState();
}

class _PlayingSongsSheetState extends State<PlayingSongsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 180),
    vsync: this,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  final _scroll = ScrollController();
  bool _showScrollToTop = false;
  bool _reorderMode = false;

  // Cached statistics
  Duration _total = Duration.zero;
  int _albumCount = 0;
  List<Music> _songsCache = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _setOptimalDisplayMode();                                           // NEW
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  Future<void> _setOptimalDisplayMode() async {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {
      // Platform not supported – ignore
    }
  }

  void _onScroll() {
    final shouldShow = _scroll.offset > 200;
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ----------  UI  ---------- //

  @override
  Widget build(BuildContext context) {
    return Selector<NPlayer, ({Music? current, List<Music> list})>(
      selector: (ctx, p) => (current: p.getCurrentSong(), list: p.playingSongs),
      builder: (ctx, data, _) {
        if (data.current == null) return _emptyState(ctx);

        _updateStats(data.list);

        return FadeTransition(
          opacity: _fade,
          child: Transform.translate(
            offset: Offset(0, (1 - _fade.value) * 30),
            child: _sheet(ctx, data.current!, data.list),
          ),
        );
      },
    );
  }

  Widget _sheet(BuildContext ctx, Music now, List<Music> songs) {
    final theme = Theme.of(ctx);
    return Container(
      height: MediaQuery.of(ctx).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _dragHandle(),
              _Header(now: now),
              _Stats(count: songs.length, albums: _albumCount, total: _total),
              _controls(ctx),
              const SizedBox(height: 4),
              Expanded(child: _songList(ctx, songs, now)),
            ],
          ),
          if (_showScrollToTop)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.small(
                onPressed: _scrollToTop,
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
        ],
      ),
    );
  }

  // ----------  Lists  ---------- //

  Widget _songList(BuildContext ctx, List<Music> songs, Music now) {
    if (_reorderMode) {
      return ReorderableListView.builder(
        proxyDecorator: _proxy,
        scrollController: _scroll,
        padding: const EdgeInsets.only(bottom: 25),
        itemCount: songs.length,
        itemExtent: 60,
        buildDefaultDragHandles: false,
        onReorder: (oldIdx, newIdx) {
          HapticFeedback.mediumImpact();
          context.read<NPlayer>().reorderPlayingSongs(_mutated(songs, oldIdx, newIdx));
        },
        itemBuilder: (c, i) => _Tile(
          key: ValueKey(songs[i].path),
          song: songs[i],
          index: i,
          nowPath: now.path,
          reorderMode: true,
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      itemCount: songs.length,
      padding: const EdgeInsets.only(bottom: 25),
      itemExtent: 60,
      cacheExtent: 800,
      itemBuilder: (c, i) => _Tile(
        song: songs[i],
        index: i,
        nowPath: now.path,
        reorderMode: false,
      ),
    );
  }

  // ----------  Helpers  ---------- //

  List<Music> _mutated(List<Music> list, int oldIndex, int newIndex) {
    final copy = List<Music>.from(list);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = copy.removeAt(oldIndex);
    copy.insert(newIndex, item);
    return copy;
  }

  Widget _proxy(Widget child, int index, Animation<double> anim) =>
      AnimatedBuilder(
        animation: anim,
        builder: (c, child) =>
            Transform.scale(scale: 1 + 0.05 * anim.value, child: child),
        child: child,
      );

  void _updateStats(List<Music> list) {
    if (identical(list, _songsCache)) return;
    _songsCache = list;
    _total = list.fold(Duration.zero,
        (d, s) => d + Duration(milliseconds: s.duration));
    _albumCount = list.map((m) => m.album).toSet().length;
  }

  void _scrollToCurrent() {
    final player = context.read<NPlayer>();
    final now = player.getCurrentSong();
    if (now == null || !_scroll.hasClients) return;
    final idx = player.playingSongs.indexWhere((s) => s.path == now.path);
    if (idx == -1) return;
    const itemH = 60.0;
    final vpH = MediaQuery.of(context).size.height * .8;
    final target = (idx * itemH) - vpH * .25;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() =>
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  // ----------  Structural  ---------- //

  Widget _dragHandle() => Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(2.5),
        ),
      );

  Widget _controls(BuildContext ctx) {
    final theme = Theme.of(ctx);
    Material button(IconData icon, String label, VoidCallback tap,
        {bool active = false}) {
      return Material(
        color: active
            ? theme.colorScheme.primary.withOpacity(.18)
            : theme.colorScheme.surface.withOpacity(.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 18,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 11,
                      color: active
                          ? theme.colorScheme.primary
                          : Colors.grey[600],
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: button(Icons.shuffle_rounded, 'Shuffle', () {
              HapticFeedback.lightImpact();
              context.read<NPlayer>().shuffle();
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Queue shuffled'),
                  duration: Duration(seconds: 1)));
            }),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: button(Icons.my_location_rounded, 'Current',
                () => _scrollToCurrent()),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: button(Icons.lyrics_rounded, 'Lyrics', () {
              final now = context.read<NPlayer>().getCurrentSong();
              if (now != null) {
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      LyricsSheet(artist: now.artist, title: now.title),
                );
              }
            }),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: button(
              _reorderMode ? Icons.check_rounded : Icons.reorder_rounded,
              _reorderMode ? 'Done' : 'Reorder',
              () {
                HapticFeedback.lightImpact();
                setState(() => _reorderMode = !_reorderMode);
              },
              active: _reorderMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext ctx) => Container(
        height: MediaQuery.of(ctx).size.height * .4,
        decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dragHandle(),
            const SizedBox(height: 40),
            Icon(Icons.queue_music_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No songs in queue',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.grey[400])),
            const SizedBox(height: 8),
            Text('Start playing music to see your queue',
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[500])),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: now.picture == null
                    ? Icon(Icons.album_rounded,
                        size: 24, color: Colors.grey[400])
                    : Image(
                        image:
                            ArtCache.fromBytes(now.path, now.picture!)!, // cached
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,

                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Playing Queue',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${now.title} • ${now.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            )),
                  ]),
            ),
          ],
        ),
      );
}

class _Stats extends StatelessWidget {
  final int count;
  final int albums;
  final Duration total;

  const _Stats(
      {required this.count, required this.albums, required this.total});

  @override
  Widget build(BuildContext ctx) {
    String fmt(Duration d) =>
        d.inHours > 0 ? '${d.inHours}h ${d.inMinutes.remainder(60)}m' : '${d.inMinutes}min';

    TextStyle numSt(bool bold) => Theme.of(ctx).textTheme.bodyMedium!.copyWith(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        );

    Widget item(IconData i, String v, String l) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 16, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(height: 2),
            Text(v, style: numSt(true)),
            Text(l,
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 10, color: Colors.grey[500])),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface.withOpacity(.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            item(Icons.queue_music_rounded, '$count', 'Songs'),
            VerticalDivider(width: 1, thickness: 1, color: Colors.grey[300]),
            item(Icons.album_rounded, '$albums', 'Albums'),
            VerticalDivider(width: 1, thickness: 1, color: Colors.grey[300]),
            item(Icons.access_time_rounded, fmt(total), 'Total'),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Music song;
  final int index;
  final String nowPath;
  final bool reorderMode;

  const _Tile(
      {Key? key,
      required this.song,
      required this.index,
      required this.nowPath,
      required this.reorderMode})
      : super(key: key);

  @override
  Widget build(BuildContext ctx) {
    final isNow = nowPath == song.path;

    Widget tile = Material(
      color: isNow
          ? Theme.of(ctx).colorScheme.primary.withOpacity(.1)
          : Theme.of(ctx).cardColor.withOpacity(.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ctx.read<NPlayer>().playSpecificSong(song);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            if (reorderMode)
              const Icon(Icons.drag_handle_rounded,
                  size: 18, color: Colors.grey)
            else
              SizedBox(
                  width: 20,
                  child: Text('${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight:
                              isNow ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                          color: isNow
                              ? Theme.of(ctx).colorScheme.primary
                              : Colors.grey[500]))),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 40,
                child: song.picture == null
                    ? Icon(Icons.music_note_rounded,
                        color: Colors.grey[400], size: 20)
                    : Image(
                        image: ArtCache.fromBytes(song.path, song.picture!)!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isNow ? FontWeight.w600 : FontWeight.normal,
                          color: isNow
                              ? Theme.of(ctx).colorScheme.primary
                              : null)),
                  const SizedBox(height: 1),
                  Text(
                      '${song.artist} • ${_mmss(Duration(milliseconds: song.duration))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[500], fontSize: 11)),
                ])),
            if (isNow)
              Icon(Icons.play_arrow_rounded,
                  size: 20, color: Theme.of(ctx).colorScheme.primary)
          ]),
        ),
      ),
    );

    return reorderMode
        ? Row(children: [
            const SizedBox(width: 12),
            ReorderableDragStartListener(
              index: index,
              child: tile,
            ),
          ])
        : tile;
  }

  String _mmss(Duration d) =>
      '${d.inMinutes.remainder(60)}:${(d.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
}
