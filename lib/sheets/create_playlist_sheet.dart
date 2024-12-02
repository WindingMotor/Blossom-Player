import 'package:flutter/material.dart';
import 'package:blossom/audio/nplayer.dart';

/// Bottom sheet for creating new playlists
class CreatePlaylistSheet extends StatefulWidget {
  final NPlayer player;
  final VoidCallback onPlaylistCreated;

  const CreatePlaylistSheet({
    Key? key,
    required this.player,
    required this.onPlaylistCreated,
  }) : super(key: key);

  @override
  _CreatePlaylistSheetState createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<CreatePlaylistSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _createPlaylist() {
    if (_controller.text.isNotEmpty) {
      widget.player.createPlaylist(_controller.text.trim());
      widget.onPlaylistCreated();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create New Playlist',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter playlist name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onSubmitted: (_) => _createPlaylist(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _createPlaylist,
                child: const Text('Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
