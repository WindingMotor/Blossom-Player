import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/sheets/bottom_sheet.dart';
import 'package:blossom/sheets/create_playlist_sheet.dart';
import 'package:blossom/widgets/playlist_artwork.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({Key? key}) : super(key: key);

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  bool _isMounted = false;
  String _searchQuery = '';

  Future<void> _selectPlaylistImage(
      BuildContext context, NPlayer player, String playlist) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null && _isMounted) {
      File imageFile = File(image.path);
      await player.setPlaylistImage(playlist, imageFile);
      if (mounted) {
        _safeSetState(() {}); // Trigger a rebuild to reflect the new image
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _isMounted = true;
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  // Use this method instead of directly calling setState
  void _safeSetState(VoidCallback fn) {
    if (_isMounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        List<String> filteredPlaylists = player.playlists
            .where((playlist) =>
                playlist.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: TextField(
              decoration: const InputDecoration(
                hintText: 'Search playlists...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                if (mounted) {
                  _safeSetState(() {
                    _searchQuery = value;
                  });
                }
              },
            ),
            actions: [
              const SizedBox(width: 15),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Create Playlist',
                onPressed: () => _showCreatePlaylistDialog(context, player),
              ),
              const SizedBox(width: 20),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: ListView.builder(
  padding: const EdgeInsets.only(top: 10),
  itemCount: filteredPlaylists.length,
  itemExtent: [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]
      .contains(Theme.of(context).platform) ? 60.0 : 80.0,
  itemBuilder: (context, index) {
                String playlist = filteredPlaylists[index];
                List<Music> playlistSongs = player.getPlaylistSongs(playlist);
                String? imagePath = player.getPlaylistImagePath(playlist);
                return _PlaylistListTile(
                  playlist: playlist,
                  songCount: playlistSongs.length,
                  imagePath: imagePath,
                  songs: playlistSongs,
                  onTap: () => _showPlaylistBottomSheet(
                      context, player, playlist, playlistSongs),
                  onPlay: () => player.playPlaylistFromIndex(playlistSongs, 0),
                  onDelete: () =>
                      _showDeletePlaylistDialog(context, player, playlist),
                  onImageTap: () =>
                      _selectPlaylistImage(context, player, playlist),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showPlaylistBottomSheet(
      BuildContext context, NPlayer player, String playlist, List<Music> songs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MusicBottomSheet(
          title: playlist,
          subtitle: '${songs.length} songs',
          itemCount: songs.length,
          songs: songs,
          onPlayPressed: (song) {
            int index = songs.indexOf(song);
            player.playPlaylistFromIndex(songs, index);
            Navigator.pop(context);
          },
          isPlaylist: true,
          customImagePath: player.getPlaylistImagePath(playlist),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, NPlayer player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePlaylistSheet(
        player: player,
        onPlaylistCreated: () {
          if (mounted) {
            setState(() {}); // Refresh to show new playlist
          }
        },
      ),
    );
  }

  void _showDeletePlaylistDialog(
      BuildContext context, NPlayer player, String playlist) {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, 
                  color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  'Delete Playlist',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Are you sure you want to delete "$playlist"?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    player.deletePlaylist(playlist);
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistListTile extends StatelessWidget {
  final String playlist;
  final int songCount;
  final String? imagePath;
  final List<Music> songs;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onImageTap;

  const _PlaylistListTile({
    Key? key,
    required this.playlist,
    required this.songCount,
    this.imagePath,
    required this.songs,
    required this.onTap,
    required this.onPlay,
    required this.onDelete,
    required this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktopPlatform = [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]
        .contains(Theme.of(context).platform);

    return Card(
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: 8, 
        vertical: isDesktopPlatform ? 2 : 4
      ),
      child: ListTile(
        dense: isDesktopPlatform,
        visualDensity: isDesktopPlatform 
            ? VisualDensity.compact 
            : VisualDensity.standard,
        leading: GestureDetector(
          onTap: onImageTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: isDesktopPlatform ? 36 : 48,
              height: isDesktopPlatform ? 36 : 48,
              child: PlaylistArtwork(
                customImagePath: imagePath,
                songs: songs,
              ),
            ),
          ),
        ),
        title: Text(
          playlist,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$songCount songs',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow, color: Colors.grey[400]),
              onPressed: songs.isNotEmpty ? onPlay : null,
              color: songs.isNotEmpty ? Colors.grey[400] : Colors.grey[800],
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.grey[400]),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
