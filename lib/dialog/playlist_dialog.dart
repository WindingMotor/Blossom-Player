import 'dart:io';

import 'package:blossom/audio/nplayer.dart';
import 'package:flutter/material.dart';

class PlaylistDialog extends StatefulWidget {
  final Set<Music> selectedSongs;
  final NPlayer player;
  final Function(NPlayer, String) onPlaylistAction;
  final VoidCallback onDeselectAll;

  const PlaylistDialog({
    Key? key,
    required this.selectedSongs,
    required this.player,
    required this.onPlaylistAction,
    required this.onDeselectAll,
  }) : super(key: key);

  @override
  _PlaylistDialogState createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late TextEditingController _newPlaylistController;
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<String> _filteredPlaylists = [];
  bool _showNewPlaylistField = false;
  bool _showSearchField = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _newPlaylistController = TextEditingController();
    _filteredPlaylists = widget.player.playlists;

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newPlaylistController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterPlaylists(String query) {
    if (mounted) {
      setState(() {
        _filteredPlaylists = widget.player.playlists
            .where((playlist) =>
                playlist.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 400,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Add to playlist',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_showSearchField
                              ? Icons.search_off
                              : Icons.search),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _showSearchField = !_showSearchField;
                                if (!_showSearchField) {
                                  _searchController.clear();
                                  _filterPlaylists('');
                                }
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.deselect),
                          onPressed: widget.onDeselectAll,
                          tooltip: 'Deselect All',
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${widget.selectedSongs.length} songs selected',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 16),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  height: _showSearchField ? 48 : 0,
                  child: SingleChildScrollView(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search playlists',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      onChanged: _filterPlaylists,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredPlaylists.length,
                    itemBuilder: (context, index) =>
                        _buildPlaylistTile(_filteredPlaylists[index]),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        height: _showNewPlaylistField ? 48 : 0,
                        child: SingleChildScrollView(
                          child: TextField(
                            controller: _newPlaylistController,
                            decoration: InputDecoration(
                              hintText: 'New playlist',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(_showNewPlaylistField ? Icons.check : Icons.add),
                      onPressed: () {
                        if (_showNewPlaylistField) {
                          if (_newPlaylistController.text.isNotEmpty) {
                            widget.player
                                .createPlaylist(_newPlaylistController.text);
                            if (mounted) {
                              setState(() {
                                _filteredPlaylists = widget.player.playlists;
                                _showNewPlaylistField = false;
                              });
                            }
                            _newPlaylistController.clear();
                          }
                        } else {
                          if (mounted) {
                            setState(() {
                              _showNewPlaylistField = true;
                            });
                          }
                        }
                      },
                    ),
                    if (_showNewPlaylistField)
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _showNewPlaylistField = false;
                              _newPlaylistController.clear();
                            });
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(String playlist) {
    bool allSongsInPlaylist =
        widget.selectedSongs.every((song) => song.playlists.contains(playlist));
    bool someSongsInPlaylist =
        widget.selectedSongs.any((song) => song.playlists.contains(playlist));
    String? imagePath = widget.player.getPlaylistImagePath(playlist);

    return Card(
      color: someSongsInPlaylist
          ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
          : Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 48,
            height: 48,
            child: imagePath != null
                ? Image.file(File(imagePath), fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.playlist_play, color: Colors.grey[600]),
                  ),
          ),
        ),
        title: Text(
          playlist,
          style: TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          allSongsInPlaylist ? Icons.playlist_add_check : Icons.playlist_add,
          color: Colors.grey[400],
        ),
        onTap: () {
          widget.onPlaylistAction(widget.player, playlist);
          Navigator.pop(context);
        },
      ),
    );
  }
}
