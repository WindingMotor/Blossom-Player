import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/sheets/bottom_sheet.dart';

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
              itemCount: filteredPlaylists.length,
              itemBuilder: (context, index) {
                String playlist = filteredPlaylists[index];
                List<Music> playlistSongs = player.getPlaylistSongs(playlist);
                String? imagePath = player.getPlaylistImagePath(playlist);
                return _PlaylistListTile(
                  playlist: playlist,
                  songCount: playlistSongs.length,
                  imagePath: imagePath,
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

  void _showPlaylistBottomSheet(BuildContext context, NPlayer player,
      String playlistName, List<Music> songs) {
    String? playlistImagePath = player.getPlaylistImagePath(playlistName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return MusicBottomSheet(
          title: playlistName,
          subtitle: '${songs.length} songs',
          itemCount: songs.length,
          songs: songs,
          onPlayPressed: (song) {
            int index = songs.indexOf(song);
            player.playPlaylistFromIndex(songs, index);
            Navigator.pop(sheetContext);
          },
          image: playlistImagePath != null
              ? Image.file(File(playlistImagePath), fit: BoxFit.cover)
              : (songs.isNotEmpty && songs.first.picture != null
                  ? Image.memory(songs.first.picture!, fit: BoxFit.cover)
                  : null),
          isPlaylist: true,
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, NPlayer player) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Create New Playlist'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter playlist name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Create'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  player.createPlaylist(controller.text);
                  Navigator.of(dialogContext).pop();
                  if (mounted) {
                    setState(
                        () {}); // Trigger a rebuild to show the new playlist
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeletePlaylistDialog(
      BuildContext context, NPlayer player, String playlist) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Playlist'),
          content: Text('Are you sure you want to delete "$playlist"?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                player.deletePlaylist(playlist);
                Navigator.of(dialogContext).pop();
                setState(
                    () {}); // Trigger a rebuild to reflect the deleted playlist
              },
            ),
          ],
        );
      },
    );
  }
}

class _PlaylistListTile extends StatelessWidget {
  final String playlist;
  final int songCount;
  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onImageTap;

  const _PlaylistListTile({
    Key? key,
    required this.playlist,
    required this.songCount,
    this.imagePath,
    required this.onTap,
    required this.onPlay,
    required this.onDelete,
    required this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: GestureDetector(
          onTap: onImageTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 48,
              child: imagePath != null
                  ? Image.file(File(imagePath!), fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[800],
                      child: Icon(Icons.playlist_play, color: Colors.grey[600]),
                    ),
            ),
          ),
        ),
        title: Text(
          playlist,
          style: TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$songCount songs',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow, color: Colors.grey[400]),
              onPressed: onPlay,
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