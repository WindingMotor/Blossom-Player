import 'dart:collection';
import 'package:blossom/sheets/playing_sheet.dart';
import 'package:blossom/sheets/playlist_sheet.dart';
import 'package:blossom/tools/app_navigation.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:blur/blur.dart';
import '../nplayer.dart';
import 'package:ticker_text/ticker_text.dart';
import '../../sheets/sleep_timer_sheet.dart';
import '../../sheets/metadata_sheet.dart';

// LRU image cache — bounded to avoid OOM on large libraries.
class _ImageCache {
  static const _maxSize = 50;
  static final _cache = LinkedHashMap<String, ImageProvider>();

  static ImageProvider getProvider(String? path, Uint8List? picture) {
    if (picture == null || path == null) {
      return const AssetImage('assets/placeholder.png');
    }
    final existing = _cache.remove(path);
    if (existing != null) {
      _cache[path] = existing;
      return existing;
    }
    final provider = MemoryImage(picture);
    _cache[path] = provider;
    if (_cache.length > _maxSize) _cache.remove(_cache.keys.first);
    return provider;
  }
}

class NPlayerWidget extends StatefulWidget {
  const NPlayerWidget({Key? key}) : super(key: key);

  @override
  _NPlayerWidgetState createState() => _NPlayerWidgetState();
}

class _NPlayerWidgetState extends State<NPlayerWidget>
    with TickerProviderStateMixin {
  bool _isPlayerExpanded = false;
  double _swipeOffset = 0.0;

  // Keep original animation setup
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  // Original image provider method with caching optimization
  ImageProvider _getImageProvider(NPlayer player) {
    try {
      final song = player.getCurrentSong();
      if (song?.picture != null) {
        return _ImageCache.getProvider(song!.path, song.picture!);
      } else {
        return const AssetImage('assets/placeholder.png') as ImageProvider;
      }
    } catch (e) {
      return const AssetImage('assets/placeholder.png') as ImageProvider;
    }
  }

  // Keep original album art styling exactly
  Widget _buildAlbumArt(NPlayer player,
      {double size = 50, double radius = 10}) {
    return RepaintBoundary(
      // Performance optimization only
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: size * 0.16,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image(
            image: _getImageProvider(player),
            width: size,
            height: size,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: size,
                height: size,
                color: Colors.grey[800],
                child: Icon(
                  Icons.music_note,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: size * 0.4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Keep exact original song text styling
  Widget _buildSongText(NPlayer player) {
    final song = player.getCurrentSong()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: TickerText(
                    scrollDirection: Axis.horizontal,
                    speed: 30,
                    startPauseDuration: const Duration(seconds: 1),
                    endPauseDuration: const Duration(seconds: 1),
                    returnDuration: const Duration(milliseconds: 800),
                    primaryCurve: Curves.linear,
                    returnCurve: Curves.easeOut,
                    child: Text(
                      song.title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          song.artist,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 13,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Keep exact original control button styling
  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          padding: EdgeInsets.all(isPrimary ? 6 : 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            color: isPrimary
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            border: isPrimary
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keep original mini controls with performance optimization
  Widget _buildMiniControls() {
    return Selector<NPlayer, bool>(
      // Performance optimization only
      selector: (_, player) => player.isPlaying,
      builder: (context, isPlaying, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlButton(
              icon: Icons.skip_previous_rounded,
              size: 28,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<NPlayer>().previousSong();
              },
            ),
            const SizedBox(width: 8),
            _buildControlButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              onPressed: () {
                HapticFeedback.mediumImpact();
                context.read<NPlayer>().togglePlayPause();
              },
              isPrimary: true,
            ),
            const SizedBox(width: 8),
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              size: 28,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<NPlayer>().nextSong();
              },
            ),
          ],
        );
      },
    );
  }

  // Keep original expanded controls with performance optimization
  Widget _buildExpandedControls() {
    return Selector<NPlayer, bool>(
      // Performance optimization only
      selector: (_, player) => player.isPlaying,
      builder: (context, isPlaying, child) {
        final player = context.read<NPlayer>();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.more_vert,
              size: 28,
              onPressed: () {
                HapticFeedback.lightImpact();
                final RenderBox? box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final Offset offset = box.localToGlobal(Offset.zero);
                  _showDropdownMenu(player, offset);
                }
              },
            ),
            _buildControlButton(
              icon: Icons.skip_previous_rounded,
              size: 28,
              onPressed: () {
                HapticFeedback.lightImpact();
                player.previousSong();
              },
            ),
            _buildControlButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 40,
              onPressed: () {
                HapticFeedback.mediumImpact();
                player.togglePlayPause();
              },
              isPrimary: true,
            ),
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              size: 28,
              onPressed: () {
                HapticFeedback.lightImpact();
                player.nextSong();
              },
            ),
            _buildControlButton(
              icon: Icons.queue_music_rounded,
              size: 28,
              onPressed: () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const PlayingSongsSheet(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Progress bar subscribes directly to positionNotifier so only this small
  // widget rebuilds at ~5 Hz instead of the entire NPlayerWidget.
  Widget _buildProgressBar(NPlayer player) {
    return ValueListenableBuilder<Duration>(
      valueListenable: player.positionNotifier,
      builder: (context, position, _) {
        final double max = player.duration.inSeconds.toDouble() > 0
            ? player.duration.inSeconds.toDouble()
            : 1.0;
        final double value = position.inSeconds.toDouble().clamp(0.0, max);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                overlayColor: Colors.white.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: max,
                onChanged: (value) {
                  if (player.duration.inSeconds > 0) {
                    HapticFeedback.selectionClick();
                    final pos = Duration(seconds: value.round());
                    player.seek(pos);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Utils.formatDuration(position.inSeconds),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    Utils.formatDuration(player.duration.inSeconds),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  // Keep exact original background with blur (your preferred style)
  Widget _buildBackground(NPlayer player) {
    return Positioned.fill(
      child: RepaintBoundary(
        // Performance optimization only
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Blur(
            blur: 15, // Keep your original blur value
            blurColor: Colors.black,
            colorOpacity: 0.5,
            overlay: Container(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
            ),
            child: Image(
              image: _getImageProvider(player),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Keep all original menu functionality
  void _showDropdownMenu(NPlayer player, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 50,
        position.dy - 100,
        position.dx + 50,
        position.dy + 100,
      ),
      items: _buildPopupMenuItems(player),
    ).then((value) => _handleMenuSelection(value, player));
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems(NPlayer player) {
    final source = player.playbackSource;
    final song = player.getCurrentSong();
    final canOpenPlaylist = source.type == PlaybackSourceType.playlist &&
        source.name?.isNotEmpty == true;
    final canOpenArtist = song?.artist.isNotEmpty == true;
    final canOpenAlbum = song?.album.isNotEmpty == true;

    return <PopupMenuEntry<String>>[
      if (canOpenPlaylist || canOpenArtist || canOpenAlbum) ...[
        if (canOpenPlaylist)
          const PopupMenuItem<String>(
            value: 'open_playlist',
            child: Row(
              children: [
                Icon(Icons.playlist_play_rounded),
                SizedBox(width: 8),
                Text('Open Playlist'),
              ],
            ),
          ),
        if (canOpenArtist)
          const PopupMenuItem<String>(
            value: 'open_artist',
            child: Row(
              children: [
                Icon(Icons.person_rounded),
                SizedBox(width: 8),
                Text('Open Artist'),
              ],
            ),
          ),
        if (canOpenAlbum)
          const PopupMenuItem<String>(
            value: 'open_album',
            child: Row(
              children: [
                Icon(Icons.album_rounded),
                SizedBox(width: 8),
                Text('Open Album'),
              ],
            ),
          ),
        const PopupMenuDivider(),
      ],
      const PopupMenuItem<String>(
        value: 'shuffle',
        child: Row(
          children: [
            Icon(Icons.shuffle_rounded),
            SizedBox(width: 8),
            Text('Shuffle'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'favorite',
        child: Row(
          children: [
            Icon(
              player.getCurrentSong()!.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: player.getCurrentSong()!.isFavorite ? Colors.red : null,
            ),
            const SizedBox(width: 8),
            const Text('Favorite'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Text('Edit Metadata'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'addtoplaylist',
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded),
            SizedBox(width: 8),
            Text('Add to Playlist'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'sleep',
        child: Row(
          children: [
            Icon(Icons.bedtime_outlined),
            SizedBox(width: 8),
            Text('Sleep Timer'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'share',
        child: Row(
          children: [
            Icon(Icons.share_outlined),
            SizedBox(width: 8),
            Text('Share'),
          ],
        ),
      ),
    ];
  }

  Future<void> _handleMenuSelection(String? value, NPlayer player) async {
    if (value == null) return;

    HapticFeedback.selectionClick();
    switch (value) {
      case 'shuffle':
        player.shuffle();
        break;
      case 'open_playlist':
        _openPlaylistSource(player);
        break;
      case 'open_artist':
        final artist = player.getCurrentSong()?.artist;
        if (artist?.isNotEmpty == true) _openArtist(artist!);
        break;
      case 'open_album':
        final song = player.getCurrentSong();
        if (song != null) _openAlbum(song);
        break;
      case 'favorite':
        player.toggleFavorite();
        break;
      case 'addtoplaylist':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PlaylistSheet(
            selectedSongs: {player.getCurrentSong()!},
            player: player,
            onPlaylistAction: (player, name) => player.addSongToPlaylist(
              name, // ← playlist name (String) - first parameter
              player
                  .getCurrentSong()!, // ← song (Music object) - second parameter
            ),
            onDeselectAll: () {},
          ),
        );
        break;
      case 'sleep':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const SleepTimerSheet(),
        );
        break;
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => MetadataSheet(
            song: player.getCurrentSong()!,
          ),
        );
        break;
      case 'share':
        try {
          await player.shareSong(player.getCurrentSong()!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error sharing song: $e')),
            );
          }
        }
        break;
    }
  }

  void _openPlaylistSource(NPlayer player) {
    final source = player.playbackSource;
    if (source.name?.isNotEmpty == true) {
      context.read<AppNavigationController>().openPlaylist(source.name!);
    }
    _collapsePlayer();
  }

  void _openArtist(String artist) {
    context.read<AppNavigationController>().openArtist(artist);
    _collapsePlayer();
  }

  void _openAlbum(Music song) {
    context.read<AppNavigationController>().openAlbum(song);
    _collapsePlayer();
  }

  void _collapsePlayer() {
    if (_isPlayerExpanded) {
      setState(() => _isPlayerExpanded = false);
      _expandController.reverse();
    }
  }

  // Keep exact original build method structure and styling
  @override
  Widget build(BuildContext context) {
    return Selector<NPlayer, Music?>(
      // Performance optimization only
      selector: (_, player) => player.getCurrentSong(),
      builder: (context, currentSong, child) {
        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        return Consumer<NPlayer>(
          builder: (context, player, _) {
            return GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! < 0) {
                  HapticFeedback.lightImpact();
                  if (!_isPlayerExpanded) {
                    setState(() => _isPlayerExpanded = true);
                    _expandController.forward();
                  }
                } else if (details.primaryVelocity! > 0) {
                  if (!_isPlayerExpanded) {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const PlayingSongsSheet(),
                    );
                  } else {
                    HapticFeedback.lightImpact();
                    setState(() => _isPlayerExpanded = false);
                    _expandController.reverse();
                  }
                }
              },
              onTap: () {
                HapticFeedback.lightImpact();
                if (!_isPlayerExpanded) {
                  setState(() => _isPlayerExpanded = true);
                  _expandController.forward();
                } else {
                  setState(() => _isPlayerExpanded = false);
                  _expandController.reverse();
                }
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _swipeOffset += details.delta.dx;
                  _swipeOffset = _swipeOffset.clamp(-100.0, 100.0);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_swipeOffset.abs() > 50) {
                  HapticFeedback.lightImpact();
                  if (_swipeOffset > 0) {
                    player.previousSong();
                  } else {
                    player.nextSong();
                  }
                }
                setState(() => _swipeOffset = 0);
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                player.togglePlayPause();
              },
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_swipeOffset, 0),
                    child: Container(
                      height: Tween<double>(
                        begin: 70,
                        end: MediaQuery.of(context).size.height * 0.72,
                      ).animate(_expandAnimation).value,
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.0),
                        child: Stack(
                          children: [
                            _buildBackground(player),

                            // Mini player with original fade animation
                            if (!_isPlayerExpanded ||
                                _fadeAnimation.value > 0.0)
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _fadeAnimation,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _fadeAnimation.value,
                                      child: Container(
                                        key: const ValueKey('collapsed'),
                                        padding: const EdgeInsets.fromLTRB(
                                          16.0,
                                          4.0,
                                          16.0,
                                          8.0,
                                        ),
                                        child: Row(
                                          children: [
                                            _buildAlbumArt(player),
                                            const SizedBox(width: 14),
                                            Expanded(
                                                child: _buildSongText(player)),
                                            const SizedBox(width: 12),
                                            _buildMiniControls(),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                            // Expanded player — fades in after 50% open
                            if (_isPlayerExpanded &&
                                _expandAnimation.value > 0.5)
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _expandAnimation,
                                  builder: (context, child) {
                                    final opacity =
                                        ((_expandAnimation.value - 0.5) / 0.5)
                                            .clamp(0.0, 1.0);
                                    return Opacity(
                                      opacity: opacity,
                                      child: Padding(
                                        key: const ValueKey('expanded'),
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 4, 16, 12),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            // Album art fills remaining space
                                            Expanded(
                                              child: Center(
                                                child: Hero(
                                                  tag: 'album_art',
                                                  child: LayoutBuilder(
                                                    builder:
                                                        (context, constraints) {
                                                      final artSize =
                                                          constraints.maxHeight
                                                              .clamp(
                                                                  120.0, 280.0);
                                                      return _buildAlbumArt(
                                                          player,
                                                          size: artSize,
                                                          radius: 16);
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Song title
                                            Text(
                                              currentSong.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 4),
                                            // Artist
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () => _openArtist(
                                                    currentSong.artist),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  child: Text(
                                                    currentSong.artist,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.78),
                                                      fontSize: 15,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Album
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () =>
                                                    _openAlbum(currentSong),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  child: Text(
                                                    currentSong.album,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.45),
                                                      fontSize: 13,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),

                                            // Progress bar
                                            _buildProgressBar(player),
                                            const SizedBox(height: 4),

                                            // Controls
                                            _buildExpandedControls(),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
