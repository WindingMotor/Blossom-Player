import 'package:blossom/sheets/playing_sheet.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blur/blur.dart';
import 'nplayer.dart';
import 'package:ticker_text/ticker_text.dart';

class NPlayerWidget extends StatefulWidget {
  const NPlayerWidget({Key? key}) : super(key: key);

  @override
  _NPlayerWidgetState createState() => _NPlayerWidgetState();
}

class _NPlayerWidgetState extends State<NPlayerWidget> {
  bool _isPlayerExpanded = false;
  double _swipeOffset = 0.0;

  Widget _buildMarqueeText(String text) {
    return LayoutBuilder(
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
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(NPlayer player) {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8), // This rounds the corners
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
              SizedBox(
                height: 20,
                child: ClipRect(
                  child: _buildMarqueeText(player.getCurrentSong()!.title),
                ),
              ),
              Text(
                player.getCurrentSong()!.artist,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
                if (player.isHeadphonesConnected)
          Icon(
            Icons.headset,
            color: Colors.white,
            size: 20,
          ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          tooltip: 'Previous',
          onPressed: () => player.previousSong(),
        ),
        IconButton(
          icon: Icon(
            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
            color: Colors.white,
          ),
          tooltip: player.isPlaying ? 'Pause' : 'Play',
          onPressed: () => player.togglePlayPause(),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          tooltip: 'Next',
          onPressed: () => player.nextSong(),
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

    return Column(
      children: [
        Slider(
          value: value,
          activeColor: Theme.of(context).colorScheme.secondary,
          inactiveColor:
              Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          min: 0,
          max: max,
          onChanged: (value) {
            if (player.duration.inSeconds > 0) {
              final position = Duration(seconds: value.round());
              player.seek(position);
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Utils.formatDuration(player.currentPosition.inSeconds),
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                Utils.formatDuration(player.duration.inSeconds),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedView(NPlayer player) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 12,
        ),
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            image: DecorationImage(
              fit: BoxFit.cover,
              image: player.getCurrentSong()?.picture != null
                  ? MemoryImage(player.getCurrentSong()!.picture!)
                  : const AssetImage('assets/placeholder.png') as ImageProvider,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Text(
              player.getCurrentSong()!.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              player.getCurrentSong()!.artist,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        _buildProgressBar(player),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.shuffle_rounded, color: Colors.white),
              tooltip: 'Shuffle',
              onPressed: () => player.shuffle(),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded,
                  color: Colors.white, size: 36),
              tooltip: 'Previous',
              onPressed: () => player.previousSong(),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            IconButton(
              icon: Icon(
                player.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 64,
              ),
              tooltip: player.isPlaying ? 'Pause' : 'Play',
              onPressed: () => player.togglePlayPause(),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded,
                  color: Colors.white, size: 36),
              tooltip: 'Next',
              onPressed: () => player.nextSong(),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            IconButton(
              icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
              tooltip: 'Queue',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const PlayingSongsSheet(),
                );
              },
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
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
            overlay: Container(
                color:
                    Theme.of(context).colorScheme.surface.withOpacity(0.3)),
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

        return GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity! < 0) {
              // Swipe up
              setState(() => _isPlayerExpanded = true);
            } else if (details.primaryVelocity! > 0) {
              // Swipe down
              setState(() => _isPlayerExpanded = false);
            }
          },
          onTap: () {
            setState(() => _isPlayerExpanded = !_isPlayerExpanded);
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _swipeOffset += details.delta.dx;
              _swipeOffset = _swipeOffset.clamp(-100.0, 100.0);
            });
          },
          onHorizontalDragEnd: (details) {
            if (_swipeOffset.abs() > 50) {
              if (_swipeOffset > 0) {
                player.previousSong();
              } else {
                player.nextSong();
              }
            }
            setState(() {
              _swipeOffset = 0;
            });
          },
          onLongPress: () {
            player.togglePlayPause();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_swipeOffset, 0, 0),
            height: _isPlayerExpanded
                ? MediaQuery.of(context).size.height * 0.55
                : 70,
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
                  _buildBackgroundImage(player),
                  _isPlayerExpanded
                      ? _buildExpandedView(player)
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: _buildSongInfo(player),
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
