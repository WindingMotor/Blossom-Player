import 'package:blossom/song_list/song_list_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../audio/nplayer.dart';
import 'package:blossom/widgets/playlist_artwork.dart';

class MusicBottomSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final int itemCount;
  final List<Music> songs;
  final Function(Music) onPlayPressed;
  final Widget? image;
  final bool isPlaylist;
  final String? customImagePath;

  const MusicBottomSheet({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.songs,
    required this.onPlayPressed,
    this.image,
    this.isPlaylist = false,
    this.customImagePath,
  }) : super(key: key);

  @override
  _MusicBottomSheetState createState() => _MusicBottomSheetState();
}

class _MusicBottomSheetState extends State<MusicBottomSheet>
    with SingleTickerProviderStateMixin {
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
    final totalDuration = widget.songs.fold<Duration>(
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
                      child: widget.image ?? (widget.isPlaylist 
                        ? PlaylistArtwork(
                            customImagePath: widget.customImagePath,
                            songs: widget.songs,
                            size: 60,
                          )
                        : (widget.songs.isNotEmpty && widget.songs.first.picture != null
                            ? Image.memory(widget.songs.first.picture!, fit: BoxFit.cover)
                            : Icon(Icons.album, size: 60, color: Theme.of(context).colorScheme.primary))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded),
                    onPressed: () {
                      if (widget.songs.isNotEmpty) {
                        // Get the first song in the list
                        Music firstSong = widget.songs.first;

                        // Call the onPlayPressed function with the first song
                        widget.onPlayPressed(firstSong);
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
                      _buildStatItem(
                          context, 'Songs', widget.itemCount.toString()),
                      _buildStatItem(
                          context,
                          'Albums',
                          widget.songs
                              .map((s) => s.album)
                              .toSet()
                              .length
                              .toString()),
                      _buildStatItem(context, 'Total Time',
                          _formatDuration(totalDuration)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ScrollConfiguration(
                behavior: DesktopScrollBehavior(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      return SongListBuilder(
                        songs: widget.songs,
                        orientation: orientation,
                        onTap: widget.onPlayPressed,
                        isPlaylist: widget.isPlaylist,
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

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
