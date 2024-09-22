import 'package:blossom/sheets/playing_sheet.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blur/blur.dart';
import 'nplayer.dart';
import 'package:ticker_text/ticker_text.dart';

class NPlayerWidgetDesktop extends StatefulWidget {
  const NPlayerWidgetDesktop({Key? key}) : super(key: key);

  @override
  _NPlayerWidgetDesktopState createState() => _NPlayerWidgetDesktopState();
}

class _NPlayerWidgetDesktopState extends State<NPlayerWidgetDesktop> {
  double _lastVolume = 1.0;

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
                activeColor: Colors.white,
                inactiveColor: Colors.grey.shade800,
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
              player.volume > 0 ? Icons.volume_up : Icons.volume_off,
              color: Colors.grey,
              size: 20,
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
                  style: const TextStyle(
                    color: Colors.white,
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
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: player.getCurrentSong()?.picture != null
                  ? MemoryImage(player.getCurrentSong()!.picture!)
                  : const AssetImage('assets/placeholder.png') as ImageProvider,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMarqueeText(player.getCurrentSong()!.title),
              const SizedBox(height: 4),
              Text(
                player.getCurrentSong()!.artist,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(NPlayer player) {
    final double max = player.duration.inSeconds.toDouble() > 0
        ? player.duration.inSeconds.toDouble()
        : 1.0;
    final double value =
        player.currentPosition.inSeconds.toDouble().clamp(0.0, max);

    return Row(
      children: [
        Text(
          Utils.formatDuration(player.currentPosition.inSeconds),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: value,
            activeColor: Colors.white,
            inactiveColor: Colors.grey.shade800,
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
        Text(
          Utils.formatDuration(player.duration.inSeconds),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildControls(NPlayer player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shuffle, color: Colors.grey),
          onPressed: () => player.shuffle(),
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          onPressed: () => player.previousSong(),
        ),
        IconButton(
          icon: Icon(
            player.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: Colors.white,
            size: 40,
          ),
          onPressed: () => player.togglePlayPause(),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white),
          onPressed: () => player.nextSong(),
        ),
        IconButton(
          icon: const Icon(Icons.repeat, color: Colors.grey),
          onPressed: () {}, // Implement repeat functionality
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(NPlayer player) {
    if (player.getCurrentSong()?.picture != null) {
      return Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Blur(
            blur: 15,
            blurColor: Colors.black,
            colorOpacity: 0.5,
            overlay: Container(color: Colors.black.withOpacity(0.3)),
            child: Image.memory(
              player.getCurrentSong()!.picture!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
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

        return Container(
          height: 120, // Reduced from 90 to 70
          color: Colors.black,
          child: Padding(
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
                        icon: const Icon(Icons.queue_music, color: Colors.grey),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const PlayingSongsSheet(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.devices, color: Colors.grey),
                        onPressed: () {
                          // Implement devices functionality
                        },
                      ),
                      _buildVolumeControls(player),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
