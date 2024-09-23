import 'package:blossom/sheets/bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../custom/custom_song_list_builder.dart';

class PlayingSongsSheet extends StatefulWidget {
  const PlayingSongsSheet({Key? key}) : super(key: key);

  @override
  _PlayingSongsSheetState createState() => _PlayingSongsSheetState();
}

class _PlayingSongsSheetState extends State<PlayingSongsSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, _) {
        final currentSong = player.getCurrentSong();
        if (currentSong == null) {
          return const Center(child: Text('No song playing'));
        }

        final totalDuration = player.playingSongs.fold<Duration>(
          Duration.zero,
          (total, song) => total + Duration(milliseconds: song.duration),
        );

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _animation.value) * 100),
              child: Opacity(
                opacity: _animation.value,
                child: child,
              ),
            );
          },
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                _buildHeader(context, player, currentSong),
                _buildStats(context, player, totalDuration),
                const SizedBox(height: 16),
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
                  );
                },
              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildHeader(BuildContext context, NPlayer player, Music currentSong) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: currentSong.picture != null
                  ? Image.memory(currentSong.picture!, fit: BoxFit.cover)
                  : const Icon(Icons.album, size: 60),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now Playing',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentSong.title,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: () => player.shuffle(),
            iconSize: 32,
          ),
          SizedBox(width: 16),
        ],
      ),
    );
  }


  Widget _buildStats(BuildContext context, NPlayer player, Duration totalDuration) {
    return Padding(
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
              _buildStatItem(context, 'Songs', player.playingSongs.length.toString()),
              _buildStatItem(context, 'Albums', player.playingSongs.map((s) => s.album).toSet().length.toString()),
              _buildStatItem(context, 'Total Time', _formatDuration(totalDuration)),
            ],
          ),
        ),
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