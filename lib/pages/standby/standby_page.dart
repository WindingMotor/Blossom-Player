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
        final mediaQuery = MediaQuery.of(context);
        final isLandscape = mediaQuery.orientation == Orientation.landscape;
        final bottomPadding = mediaQuery.padding.bottom;
        final topPadding = mediaQuery.padding.top;

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
                  top: topPadding + 16,
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
              // Main content - responsive layout with proper padding
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topPadding,
                    bottom: bottomPadding,
                    left: mediaQuery.padding.left,
                    right: mediaQuery.padding.right,
                  ),
                  child: currentSong != null
                      ? _buildMainContent(context, player, currentSong, isLandscape)
                      : _buildNoSongContent(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context, NPlayer player, dynamic currentSong, bool isLandscape) {
    if (isLandscape) {
      // Landscape layout - side by side
      return Row(
        children: [
          // Left side - Album Art with scale animation
          Expanded(
            flex: 1,
            child: AnimatedScale(
              scale: _isQueueVisible ? 0.7 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: _buildAlbumArt(currentSong),
              ),
            ),
          ),
          // Right side - Controls
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                _buildControls(context, player, currentSong, isLandscape),
                if (_isQueueVisible)
                  Positioned.fill(
                    child: _buildQueueList(context, player),
                  ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Portrait layout - stacked vertically with flexible sizing
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final albumArtHeight = availableHeight * 0.55; // 55% for album art
          final controlsHeight = availableHeight * 0.45;  // 45% for controls
          
          return Column(
            children: [
              // Album Art
              SizedBox(
                height: albumArtHeight,
                child: AnimatedScale(
                  scale: _isQueueVisible ? 0.8 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
                    child: _buildAlbumArt(currentSong),
                  ),
                ),
              ),
              // Controls
              SizedBox(
                height: controlsHeight,
                child: Stack(
                  children: [
                    _buildControls(context, player, currentSong, isLandscape),
                    if (_isQueueVisible)
                      Positioned.fill(
                        child: _buildQueueList(context, player),
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

  Widget _buildAlbumArt(dynamic currentSong) {
    return Container(
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
              : const AssetImage('assets/placeholder.png') as ImageProvider,
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, NPlayer player, dynamic currentSong, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 24.0 : 20.0,
        vertical: isLandscape ? 24.0 : 8.0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Song Title
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                currentSong.title,
                style: TextStyle(
                  fontSize: isLandscape ? 32 : 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Artist
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                currentSong.artist,
                style: TextStyle(
                  fontSize: isLandscape ? 24 : 18,
                  color: Colors.white.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(height: isLandscape ? 24 : 16),
          // Progress Bar
          _buildProgressBar(context, player),
          SizedBox(height: isLandscape ? 20 : 12),
          // Control Buttons
          _buildControlButtons(context, player, isLandscape),
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, NPlayer player, bool isLandscape) {
    final buttonSize = isLandscape ? 28.0 : 24.0;
    final playButtonSize = isLandscape ? 60.0 : 52.0;
    final skipButtonSize = isLandscape ? 44.0 : 38.0;
    final spacing = isLandscape ? 16.0 : 12.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.shuffle_rounded, color: Colors.white, size: buttonSize),
            onPressed: () => player.shuffle(),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          SizedBox(width: spacing),
          IconButton(
            icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: skipButtonSize),
            onPressed: () => player.previousSong(),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          SizedBox(width: spacing),
          IconButton(
            icon: Icon(
              player.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: playButtonSize,
            ),
            onPressed: () => player.togglePlayPause(),
            constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
          ),
          SizedBox(width: spacing),
          IconButton(
            icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: skipButtonSize),
            onPressed: () => player.nextSong(),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          SizedBox(width: spacing),
          IconButton(
            icon: Icon(Icons.queue_music_rounded, color: Colors.white, size: buttonSize),
            onPressed: () => _showQueue(context),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSongContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No song playing',
            style: TextStyle(
              fontSize: 24,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play a song to see it here',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
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