import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../custom/custom_song_list_builder.dart';

class MusicBottomSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final int itemCount;
  final List<Music> songs;
  final Function(Music) onPlayPressed;
  final Widget? image;
  final bool isPlaylist; // Add this line

  const MusicBottomSheet({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.songs,
    required this.onPlayPressed,
    this.image,
    this.isPlaylist = false, // Add this line
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<NPlayer>(context, listen: false);

    // Calculate total playtime
    final totalDuration = songs.fold<Duration>(
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
          Padding(
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
                    child: image ?? const Icon(Icons.album, size: 60),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
IconButton(
  icon: const Icon(Icons.play_circle_fill_rounded),
  onPressed: () {
    // Find the index of the first song in the playlist
    int firstSongIndex = player.allSongs.indexWhere((song) => song.title == songs.first.title);
    if (firstSongIndex != -1) {
      player.playPlaylistFromIndex(songs, firstSongIndex);
      Navigator.pop(context);
    } else {
      // Handle the case where the song is not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to play playlist: First song not found')),
      );
    }
  },
  color: Theme.of(context).colorScheme.secondary,
  iconSize: 48,
),
              ],
            ),
          ),
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
                    _buildStatItem(context, 'Songs', itemCount.toString()),
                    _buildStatItem(context, 'Albums', songs.map((s) => s.album).toSet().length.toString()),
                    _buildStatItem(context, 'Total Time', _formatDuration(totalDuration)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
   Expanded(
            child: SongListBuilder(
              songs: songs,
              isPlayingList: true,
              onTap: onPlayPressed,
              isPlaylist: isPlaylist, // Add this line
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