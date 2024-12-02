import 'package:blossom/sheets/playing_sheet.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blur/blur.dart';
import 'package:confetti/confetti.dart';
import 'nplayer.dart';
import 'package:ticker_text/ticker_text.dart';

class NPlayerWidgetDesktop extends StatefulWidget {
  const NPlayerWidgetDesktop({Key? key}) : super(key: key);

  @override
  _NPlayerWidgetDesktopState createState() => _NPlayerWidgetDesktopState();
}

class _NPlayerWidgetDesktopState extends State<NPlayerWidgetDesktop> with TickerProviderStateMixin {
  double _lastVolume = 1.0;
  bool _isRepeatEnabled = false;
  late final AnimationController _shuffleController;
  late final Animation<double> _shuffleAnimation;
  late Animation<Color?> _shuffleColorAnimation;
  late final AnimationController _favoriteController;
  late final Animation<double> _favoriteAnimation;
  late Animation<Color?> _favoriteColorAnimation;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    
    _shuffleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _shuffleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_shuffleController);

    _shuffleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shuffleController.reverse();
      }
    });

    _favoriteController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _favoriteAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_favoriteController);

    _favoriteController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _favoriteController.reverse();
      }
    });

    _confettiController = ConfettiController(duration: const Duration(milliseconds: 500));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    _shuffleColorAnimation = ColorTween(
      begin: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
      end: Theme.of(context).colorScheme.secondary,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_shuffleController);

    _favoriteColorAnimation = ColorTween(
      begin: Colors.grey,
      end: Colors.red,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_favoriteController);
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    _favoriteController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleShuffle(NPlayer player) {
    player.shuffle();
    _shuffleController.forward();
    if (Settings.showConfetti) {
      _confettiController.play();
    }
  }

  void _handleFavorite(NPlayer player) {
    player.toggleFavorite();
    _favoriteController.forward();
    if (Settings.showConfetti && player.getCurrentSong()?.isFavorite == true) {
      _confettiController.play();
    }
  }

  Widget _buildVolumeControls(NPlayer player) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16),
          child: SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                trackHeight: 4,
              ),
              child: Slider(
                value: player.volume,
                min: 0.0,
                max: 1.0,
                activeColor: Theme.of(context).colorScheme.secondary,
                inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                onChanged: (newVolume) {
                  if (newVolume > 0) {
                    _lastVolume = newVolume;
                  }
                  player.setVolume(newVolume);
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (player.volume > 0) {
                  _lastVolume = player.volume;
                  player.setVolume(0);
                } else {
                  player.setVolume(_lastVolume);
                }
              },
              child: Icon(
                player.volume == 0
                    ? Icons.volume_off
                    : player.volume < 0.3
                        ? Icons.volume_mute
                        : player.volume < 0.7
                            ? Icons.volume_down
                            : Icons.volume_up,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarqueeText(String text) {
    return Tooltip(
        message: text,
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
                  text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ));
  }

  Widget _buildSongInfo(NPlayer player) {
    final currentSong = player.getCurrentSong();
    if (currentSong == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const PlayingSongsSheet(),
          );
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: currentSong.picture != null
                      ? MemoryImage(currentSong.picture!)
                      : const AssetImage('assets/placeholder.png') as ImageProvider,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMarqueeText(currentSong.title),
                  const SizedBox(height: 4),
                  Text(
                    currentSong.artist,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(NPlayer player) {
    final double max = player.duration.inSeconds.toDouble() > 0
        ? player.duration.inSeconds.toDouble()
        : 1.0;
    final double value = player.currentPosition.inSeconds.toDouble().clamp(0.0, max);

    return Row(
      children: [
        Text(
          Utils.formatDuration(player.currentPosition.inSeconds),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              activeColor: Theme.of(context).colorScheme.secondary,
              inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              min: 0,
              max: max,
              onChanged: (value) {
                if (player.duration.inSeconds > 0) {
                  final position = Duration(seconds: value.round());
                  player.seek(position);
                }
              },
            ),
          ),
        ),
        Text(
          Utils.formatDuration(player.duration.inSeconds),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(NPlayer player) {
    final currentSong = player.getCurrentSong();
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _shuffleAnimation,
              child: AnimatedBuilder(
                animation: _shuffleColorAnimation,
                builder: (context, child) => IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: _shuffleColorAnimation.value,
                  ),
                  onPressed: () => _handleShuffle(player),
                  tooltip: 'Shuffle',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 32),
              onPressed: () => player.previousSong(),
              tooltip: 'Previous',
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: player.togglePlayPause,
                tooltip: player.isPlaying ? 'Pause' : 'Play',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
              onPressed: () => player.nextSong(),
              tooltip: 'Next',
            ),
            ScaleTransition(
              scale: _favoriteAnimation,
              child: AnimatedBuilder(
                animation: _favoriteColorAnimation,
                builder: (context, child) => IconButton(
                  icon: Icon(
                    currentSong?.isFavorite == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: currentSong?.isFavorite == true ? Colors.red : _favoriteColorAnimation.value,
                  ),
                  onPressed: () => _handleFavorite(player),
                  tooltip: 'Favorite',
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -3.14 / 2, // straight up
            emissionFrequency: 0.3,
            numberOfParticles: 20,
            maxBlastForce: 5,
            minBlastForce: 2,
            gravity: 0.3,
            colors: [
              Colors.red,
              Colors.pink,
              Colors.orange,
              Colors.yellow,
              Colors.blue,
              Colors.green,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(NPlayer player) {
    if (player.getCurrentSong()?.picture != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Positioned.fill(
        child: Blur(
          blur: 20,
          blurColor: isDark ? Colors.black : Colors.white,
          colorOpacity: isDark ? 0.5 : 0.3,
          overlay: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(isDark ? 0.9 : 0.85),
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(isDark ? 0.7 : 0.6),
                ],
              ),
            ),
          ),
          child: Image.memory(
            player.getCurrentSong()!.picture!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final currentSong = player.getCurrentSong();
        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey[400]!).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Stack(
            children: [
              _buildBackgroundImage(player),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildSongInfo(player),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControls(player),
                          const SizedBox(height: 4),
                          _buildProgressBar(player),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.queue_music_rounded, color: Colors.grey),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const PlayingSongsSheet(),
                              );
                            },
                            tooltip: 'Queue',
                          ),
                          const SizedBox(width: 8),
                          _buildVolumeControls(player),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
