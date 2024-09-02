import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../custom/custom_song_list_builder.dart';

class PlayingSongsSheet extends StatelessWidget {
  const PlayingSongsSheet({Key? key}) : super(key: key);

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

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
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
              _buildHeader(context, player, currentSong),
              _buildStats(context, player, totalDuration),
              const SizedBox(height: 16),
              Expanded(
                child: SongListBuilder(
                  songs: player.playingSongs,
                  isPlayingList: true,
                  onTap: (song) => player.playSpecificSong(song),
                  isPlaylist: false,
                ),
              ),
            ],
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
            icon: const Icon(Icons.play_circle_fill_rounded),
            onPressed: () => player.togglePlayPause(),
            color: Theme.of(context).colorScheme.secondary,
            iconSize: 48,
          ),
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