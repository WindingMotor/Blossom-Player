/// Standby Page
/// Main playback interface that shows currently playing song and controls
/// Provides:
/// - Now playing information
/// - Playback controls
/// - Queue management
/// - Visual feedback for current playback state

import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/sheets/bottom_sheet.dart';
import 'package:blossom/song_list/song_list_builder.dart';
import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blur/blur.dart';
import 'dart:io';

/// Main widget for the standby/now playing screen
class StandbyPage extends StatefulWidget {
  const StandbyPage({Key? key}) : super(key: key);

  @override
  _StandbyPageState createState() => _StandbyPageState();
}

/// State management for StandbyPage
/// Handles:
/// - Playback control
/// - Queue display
/// - UI animations
/// - Player state updates
class _StandbyPageState extends State<StandbyPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  bool _isQueueVisible = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  /// Shows the current queue in a bottom sheet
  /// Allows users to:
  /// - View upcoming songs
  /// - Reorder queue
  /// - Remove songs from queue
  void _showQueue(BuildContext context) {
    setState(() {
      _isQueueVisible = !_isQueueVisible;
      if (_isQueueVisible) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    });
  }

  Widget _buildProgressBar(BuildContext context, NPlayer player) {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final currentSong = player.getCurrentSong();

        return Scaffold(
          body: Stack(
            children: [
              // Background when song is playing
              if (currentSong?.picture != null)
                Positioned.fill(
                  child: Blur(
                    blur: 20,
                    blurColor: Colors.black,
                    colorOpacity: 0.5,
                    overlay: Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.3),
                    ),
                    child: Image.memory(
                      currentSong!.picture!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              // Exit button for desktop
              if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      tooltip: 'Exit Standby Mode',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              // Main content
              if (currentSong != null)
                Row(
                  children: [
                    // Left side - Album Art with scale animation
                    Expanded(
                      flex: 1,
                      child: AnimatedScale(
                        scale: _isQueueVisible ? 0.7 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: currentSong.picture != null
                                    ? MemoryImage(currentSong.picture!)
                                    : const AssetImage('assets/placeholder.png')
                                        as ImageProvider,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right side - Controls
                    Expanded(
                      flex: 1,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    currentSong.title,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    currentSong.artist,
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Progress Bar
                                _buildProgressBar(context, player),
                                const SizedBox(height: 24),

                                // Control Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.shuffle_rounded,
                                          color: Colors.white, size: 30),
                                      onPressed: () => player.shuffle(),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.skip_previous_rounded,
                                          color: Colors.white,
                                          size: 48),
                                      onPressed: () => player.previousSong(),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: Icon(
                                        player.isPlaying
                                            ? Icons.pause_circle_filled_rounded
                                            : Icons.play_circle_filled_rounded,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                      onPressed: () => player.togglePlayPause(),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next_rounded,
                                          color: Colors.white, size: 48),
                                      onPressed: () => player.nextSong(),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.queue_music_rounded,
                                          color: Colors.white, size: 30),
                                      onPressed: () => _showQueue(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          if (_isQueueVisible)
                            Positioned.fill(
                              child: _buildQueueList(context, player),

                            ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No song playing',
                        style: TextStyle(
                          fontSize: 24,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Play a song to see it here',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
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

  Widget _buildQueueList(BuildContext context, NPlayer player) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => _showQueue(context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Queue',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${player.playingSongs.length} songs',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Theme.of(context).cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context, 
                      'Songs', 
                      player.playingSongs.length.toString()
                    ),
                    _buildStatItem(
                      context,
                      'Albums',
                      player.playingSongs
                          .map((s) => s.album)
                          .toSet()
                          .length
                          .toString()
                    ),
                    _buildStatItem(
                      context, 
                      'Total Time', 
                      _formatDuration(player.playingSongs.fold<Duration>(
                        Duration.zero,
                        (total, song) => total + Duration(milliseconds: song.duration),
                      ))
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Song List
          Expanded(
            child: ScrollConfiguration(
              behavior: DesktopScrollBehavior(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OrientationBuilder(
                  builder: (context, orientation) {
                    return SongListBuilder(
                      songs: player.playingSongs,
                      orientation: orientation,
                      isPlayingList: true,
                      onTap: (song) {
                        player.playSpecificSong(song);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
