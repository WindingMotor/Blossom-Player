import 'package:blossom/sheets/playing_sheet.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:blur/blur.dart';
import '../nplayer.dart';
import 'package:ticker_text/ticker_text.dart';
import '../../sheets/sleep_timer_sheet.dart';
import '../../sheets/metadata_sheet.dart';

class NPlayerWidget extends StatefulWidget {
  const NPlayerWidget({Key? key}) : super(key: key);

  @override
  _NPlayerWidgetState createState() => _NPlayerWidgetState();
}

class _NPlayerWidgetState extends State<NPlayerWidget>
    with TickerProviderStateMixin {
  bool _isPlayerExpanded = false;
  double _swipeOffset = 0.0;
  
  // Simplified animation controllers
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200), // Faster animation
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic, // More performant curve
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

  // Optimized image provider without caching overhead
  ImageProvider _getImageProvider(NPlayer player) {
    final song = player.getCurrentSong();
    return song?.picture != null
        ? MemoryImage(song!.picture!)
        : const AssetImage('assets/placeholder.png') as ImageProvider;
  }

  // Simplified album art widget
  Widget _buildAlbumArt(NPlayer player, {double size = 50, double radius = 10}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: _getImageProvider(player),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
    );
  }

  // Optimized song text widget
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
            color: Colors.white.withOpacity(0.75),
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

  // Simplified control button widget
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
                ? Colors.white.withOpacity(0.2) 
                : Colors.transparent,
            border: isPrimary 
                ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
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

  // Use Selector for targeted rebuilds - mini controls
  Widget _buildMiniControls() {
    return Selector<NPlayer, bool>(
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

  // Use Selector for targeted rebuilds - expanded controls
  Widget _buildExpandedControls() {
    return Selector<NPlayer, bool>(
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

  // Progress bar - don't cache this as it updates frequently
  Widget _buildProgressBar(NPlayer player) {
    final double max = player.duration.inSeconds.toDouble() > 0
        ? player.duration.inSeconds.toDouble()
        : 1.0;
    final double value =
        player.currentPosition.inSeconds.toDouble().clamp(0.0, max);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            overlayColor: Colors.white.withOpacity(0.1),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: max,
            onChanged: (value) {
              if (player.duration.inSeconds > 0) {
                HapticFeedback.selectionClick();
                final position = Duration(seconds: value.round());
                player.seek(position);
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
                Utils.formatDuration(player.currentPosition.inSeconds),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                Utils.formatDuration(player.duration.inSeconds),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Simplified background with strategic RepaintBoundary
  Widget _buildBackground(NPlayer player) {
    return RepaintBoundary( // Only one strategic RepaintBoundary
      child: Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Blur(
            blur: 15,
            blurColor: Colors.black,
            colorOpacity: 0.5,
            overlay: Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
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
    return <PopupMenuEntry<String>>[
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
              color: player.getCurrentSong()!.isFavorite
                  ? Colors.red
                  : null,
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
      case 'favorite':
        player.toggleFavorite();
        break;
      case 'sleep':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const SleepTimerSheet(),
        );
        break;
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
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

  @override
  Widget build(BuildContext context) {
    return Selector<NPlayer, Music?>(
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
                  // Swipe up
                  HapticFeedback.lightImpact();
                  if (!_isPlayerExpanded) {
                    setState(() => _isPlayerExpanded = true);
                    _expandController.forward();
                  }
                } else if (details.primaryVelocity! > 0) {
                  // Swipe down
                  if (!_isPlayerExpanded) {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
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
                        end: MediaQuery.of(context).size.height * 0.55,
                      ).animate(_expandAnimation).value,
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
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
                            // Mini player with fade out animation
                            if (!_isPlayerExpanded || _fadeAnimation.value > 0.0)
                              AnimatedBuilder(
                                animation: _fadeAnimation,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _fadeAnimation.value,
                                    child: Container(
                                      key: const ValueKey('collapsed'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          _buildAlbumArt(player),
                                          const SizedBox(width: 14),
                                          Expanded(child: _buildSongText(player)),
                                          const SizedBox(width: 12),
                                          _buildMiniControls(),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // Expanded player with fade in animation
                            if (_isPlayerExpanded && _expandAnimation.value > 0.3)
                              AnimatedBuilder(
                                animation: _expandAnimation,
                                builder: (context, child) {
                                  final opacity = ((_expandAnimation.value - 0.3) / 0.7).clamp(0.0, 1.0);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Padding(
                                      key: const ValueKey('expanded'),
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Hero(
                                            tag: 'album_art',
                                            child: _buildAlbumArt(player, size: 200, radius: 12),
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                currentSong.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                currentSong.album,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 16,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                          _buildProgressBar(player),
                                          _buildExpandedControls(),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
