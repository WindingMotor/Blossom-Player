import 'dart:typed_data';
import 'dart:io';

import 'package:blossom/audio/nplayer.dart';
import 'package:flutter/material.dart';
import 'package:blossom/widgets/playlist_artwork.dart';

/// Bottom sheet for adding songs to playlists
class PlaylistSheet extends StatefulWidget {
  final Set<Music> selectedSongs;
  final NPlayer player;
  final Function(NPlayer, String) onPlaylistAction;
  final VoidCallback onDeselectAll;

  const PlaylistSheet({
    Key? key,
    required this.selectedSongs,
    required this.player,
    required this.onPlaylistAction,
    required this.onDeselectAll,
  }) : super(key: key);

  @override
  _PlaylistSheetState createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<PlaylistSheet> {
  late TextEditingController _searchController;
  late TextEditingController _newPlaylistController;
  List<String> _filteredPlaylists = [];
  bool _showNewPlaylistField = false;
  bool _showSearchField = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _newPlaylistController = TextEditingController();
    _filteredPlaylists = widget.player.playlists;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newPlaylistController.dispose();
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

  void _handlePlaylistAction(String playlist) {
    widget.onPlaylistAction(widget.player, playlist);
    Navigator.pop(context);
  }

  void _createNewPlaylist() {
    if (_newPlaylistController.text.isNotEmpty) {
      widget.player.createPlaylist(_newPlaylistController.text);
      if (mounted) {
        setState(() {
          _filteredPlaylists = widget.player.playlists;
          _showNewPlaylistField = false;
        });
      }
      _newPlaylistController.clear();
    }
  }

  Widget _buildPlaylistTile(String playlist) {
    NPlayer player = widget.player;
    List<Music> songs = player.getPlaylistSongs(playlist);
    String? imagePath = player.getPlaylistImagePath(playlist);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 42,
          height: 42,
          child: PlaylistArtwork(
            customImagePath: imagePath,
            songs: songs,
            size: 42,
          ),
        ),
      ),
      title: Text(
        playlist,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      onTap: () => _handlePlaylistAction(playlist),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 600;
    
    return Container(
      width: isDesktop ? screenSize.width * 0.4 : screenSize.width,
      constraints: BoxConstraints(
        maxWidth: 600,
        minWidth: 300,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: EdgeInsets.symmetric(
              vertical: isDesktop ? 12 : 8,
            ),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 16 : 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to playlist',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: isDesktop ? 24 : 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.selectedSongs.length} ${widget.selectedSongs.length == 1 ? 'song' : 'songs'} selected',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_showSearchField
                              ? Icons.search_off
                              : Icons.search),
                          iconSize: isDesktop ? 28 : 24,
                          onPressed: () {
                            setState(() {
                              _showSearchField = !_showSearchField;
                              if (!_showSearchField) {
                                _searchController.clear();
                                _filteredPlaylists = widget.player.playlists;
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(_showNewPlaylistField
                              ? Icons.close
                              : Icons.add),
                          iconSize: isDesktop ? 28 : 24,
                          onPressed: () {
                            setState(() {
                              _showNewPlaylistField = !_showNewPlaylistField;
                              if (!_showNewPlaylistField) {
                                _newPlaylistController.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // Search Field
                if (_showSearchField)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search playlists',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: _filterPlaylists,
                    ),
                  ),

                // New Playlist Field
                if (_showNewPlaylistField)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newPlaylistController,
                            decoration: InputDecoration(
                              hintText: 'New playlist name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onSubmitted: (_) => _createNewPlaylist(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _createNewPlaylist,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Playlist List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: bottomPadding + 16),
              itemCount: _filteredPlaylists.length,
              itemBuilder: (context, index) {
                final playlist = _filteredPlaylists[index];
                return _buildPlaylistTile(playlist);
              },
            ),
          ),
        ],
      ),
    );
  }
}
