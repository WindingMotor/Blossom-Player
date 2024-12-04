import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import 'package:metadata_god/metadata_god.dart';
import 'dart:typed_data';
import '../tools/utils.dart';
import '../sheets/metadata_sheet.dart';

class ManagerSongList extends StatefulWidget {
  final List<Music> songs;
  final Orientation? orientation;

  const ManagerSongList({
    Key? key,
    required this.songs,
    required this.orientation,
  }) : super(key: key);

  @override
  ManagerSongListState createState() => ManagerSongListState();
}

class _AlbumArt extends StatelessWidget {
  final Uint8List? picture;

  const _AlbumArt({Key? key, required this.picture}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 48,
        height: 48,
        child: picture != null
            ? Image.memory(picture!, fit: BoxFit.cover)
            : Container(
                color: theme.colorScheme.surface,
                child: Icon(Icons.music_note, color: theme.colorScheme.onSurface),
              ),
      ),
    );
  }
}

class ManagerSongListState extends State<ManagerSongList> {
  Set<Music> selectedSongs = {};
  ScrollController scrollController = ScrollController();
  
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _editSongMetadata(Music song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MetadataSheet(song: song),
      ),
    );
  }

  Future<void> _deleteSong(Music song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Are you sure you want to delete "${song.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final player = Provider.of<NPlayer>(context, listen: false);
      await player.deleteSong(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: widget.songs.length,
      itemBuilder: (context, index) {
        final song = widget.songs[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: _AlbumArt(picture: song.picture),
            title: Text(
              song.title,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${song.artist} • ${song.album}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Utils.formatMilliseconds(song.duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editSongMetadata(song),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteSong(song),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MetadataEditDialog extends StatefulWidget {
  final Music song;

  const MetadataEditDialog({Key? key, required this.song}) : super(key: key);

  @override
  MetadataEditDialogState createState() => MetadataEditDialogState();
}

class MetadataEditDialogState extends State<MetadataEditDialog> {
  late TextEditingController titleController;
  late TextEditingController artistController;
  late TextEditingController albumController;
  late TextEditingController yearController;
  late TextEditingController genreController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.song.title);
    artistController = TextEditingController(text: widget.song.artist);
    albumController = TextEditingController(text: widget.song.album);
    yearController = TextEditingController(text: widget.song.year);
    genreController = TextEditingController(text: widget.song.genre);
  }

  @override
  void dispose() {
    titleController.dispose();
    artistController.dispose();
    albumController.dispose();
    yearController.dispose();
    genreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Song Metadata'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
            TextField(
              controller: albumController,
              decoration: const InputDecoration(labelText: 'Album'),
            ),
            TextField(
              controller: yearController,
              decoration: const InputDecoration(labelText: 'Year'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: genreController,
              decoration: const InputDecoration(labelText: 'Genre'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'title': titleController.text,
            'artist': artistController.text,
            'album': albumController.text,
            'year': yearController.text,
            'genre': genreController.text,
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
