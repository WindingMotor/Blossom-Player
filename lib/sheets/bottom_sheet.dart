import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import 'package:blossom/sheets/song_actions_sheet.dart';
import 'package:blossom/song_list/song_list_tile.dart';
import 'package:blossom/song_list/song_list_tile_wrapper.dart';
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
  final String? playlistName;

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
    this.playlistName,
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

  Future<void> _removeSongFromPlaylist(Music song, NPlayer player) async {
    if (widget.playlistName == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Playlist'),
        content: Text('Remove "${song.title}" from "${widget.playlistName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await player.removeSongFromPlaylist(widget.playlistName!, song);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from ${widget.playlistName}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        final updatedSongs = player.getPlaylistSongs(widget.playlistName!);
        if (updatedSongs.isEmpty) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, _) {
        final currentSongs = widget.isPlaylist && widget.playlistName != null
            ? player.getPlaylistSongs(widget.playlistName!)
            : widget.songs;

        final totalDuration = currentSongs.fold<Duration>(
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
                  Theme.of(context)
                      .scaffoldBackgroundColor
                      .withValues(alpha: 0.8),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
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
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.5),
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
                          child: widget.image ??
                              (widget.isPlaylist
                                  ? PlaylistArtwork(
                                      customImagePath: widget.customImagePath,
                                      songs: currentSongs,
                                      size: 60,
                                    )
                                  : (currentSongs.isNotEmpty &&
                                          currentSongs.first.picture != null
                                      ? Image.memory(
                                          currentSongs.first.picture!,
                                          fit: BoxFit.cover)
                                      : Icon(Icons.album,
                                          size: 60,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary))),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '${currentSongs.length} songs',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        onPressed: () {
                          if (currentSongs.isNotEmpty) {
                            widget.onPlayPressed(currentSongs.first);
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                              context, 'Songs', currentSongs.length.toString()),
                          _buildStatItem(
                              context,
                              'Albums',
                              currentSongs
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
                  child: currentSongs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_note,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No songs in this playlist',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: DesktopScrollBehavior(),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: widget.isPlaylist &&
                                    widget.playlistName != null
                                ? _buildPlaylistSongList(currentSongs, player)
                                : _buildStaticSongList(currentSongs, player),
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

  Widget _buildStaticSongList(List<Music> songs, NPlayer player) {
    final isDesktopPlatform = [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ].contains(Theme.of(context).platform);

    return ListView.builder(
      itemCount: songs.length,
      itemExtent: isDesktopPlatform ? 60 : 80,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongListTileWrapper(
          key: ValueKey(song.path),
          song: song,
          isCurrentSong: song.path == player.getCurrentSong()?.path,
          isSelected: false,
          onTap: () => widget.onPlayPressed(song),
          onLongPress: () {},
          onMorePressed: () => SongActionsSheet.show(context, song),
        );
      },
    );
  }

  Widget _buildPlaylistSongList(List<Music> songs, NPlayer player) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }

        final reordered = List<Music>.from(songs);
        final song = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, song);

        await player.reorderPlaylistSongs(
          widget.playlistName!,
          reordered,
        );
      },
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final itemKey = Key('${widget.playlistName}_${song.path}_$index');

        final songWidget = Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: song.picture != null
                      ? Image(
                          image: AlbumArtCache.of(song.path, song.picture!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.music_note,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
              ],
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.grey[400],
              tooltip: 'Remove from playlist',
              onPressed: () => _removeSongFromPlaylist(song, player),
            ),
            onTap: () => widget.onPlayPressed(song),
          ),
        );

        return Dismissible(
          key: Key('dismissible_${widget.playlistName}_${song.path}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          confirmDismiss: (direction) async {
            await player.removeSongFromPlaylist(
              widget.playlistName!,
              song,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${song.title}"'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return true;
          },
          child: Container(
            key: itemKey,
            child: songWidget,
          ),
        );
      },
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
