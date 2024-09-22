import 'package:blossom/tools/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

class SongListBuilder extends StatefulWidget {
  final List<Music> songs;
  final bool isPlayingList;
  final void Function(Music)? onTap;
  final bool isPlaylist;

  const SongListBuilder({
    Key? key,
    required this.songs,
    this.isPlayingList = false,
    this.onTap,
    this.isPlaylist = false,
  }) : super(key: key);

  @override
  _SongListBuilderState createState() => _SongListBuilderState();
}

class _SongListBuilderState extends State<SongListBuilder> {
  Set<Music> selectedSongs = {};
  int? lastSelectedIndex;
  ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true, // Always show the scrollbar
          child: ListView.builder(
            controller: _scrollController,
            itemCount: widget.songs.length + (selectedSongs.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == lastSelectedIndex && selectedSongs.isNotEmpty) {
                return Column(
                  children: [
                    _SongListTile(
                      song: widget.songs[index],
                      isCurrentSong:
                          widget.songs[index] == player.getCurrentSong(),
                      isSelected: selectedSongs.contains(widget.songs[index]),
                      player: player,
                      onTap: _handleTap,
                      onLongPress: () => _handleLongPress(index),
                    ),
                    _buildPlaylistCard(player),
                  ],
                );
              } else if (index < widget.songs.length) {
                return _SongListTile(
                  song: widget.songs[index],
                  isCurrentSong: widget.songs[index] == player.getCurrentSong(),
                  isSelected: selectedSongs.contains(widget.songs[index]),
                  player: player,
                  onTap: _handleTap,
                  onLongPress: () => _handleLongPress(index),
                );
              } else {
                return _buildPlaylistCard(player);
              }
            },
          ),
        );
      },
    );
  }

  void _handleTap(Music song) {
    if (selectedSongs.isEmpty) {
      if (widget.onTap != null) {
        widget.onTap!(song);
      } else {
        final player = Provider.of<NPlayer>(context, listen: false);
        if (widget.isPlaylist) {
          int index = widget.songs.indexOf(song);
          player.playPlaylistFromIndex(widget.songs, index);
        } else {
          widget.isPlayingList
              ? player.playSpecificSong(song)
              : player.playSong(widget.songs.indexOf(song));
        }
      }
    } else {
      _handleLongPress(widget.songs.indexOf(song));
    }
  }

  void _handleLongPress(int index) {
    setState(() {
      if (selectedSongs.contains(widget.songs[index])) {
        selectedSongs.remove(widget.songs[index]);
        if (selectedSongs.isEmpty) {
          lastSelectedIndex = null;
        }
      } else {
        selectedSongs.add(widget.songs[index]);
        lastSelectedIndex = index;
      }
    });
  }

  Widget _buildPlaylistCard(NPlayer player) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text('Deselect All'),
                  avatar: Icon(Icons.deselect,
                      color: Theme.of(context).colorScheme.secondary),
                  onPressed: () {
                    setState(() {
                      selectedSongs.clear();
                      lastSelectedIndex = null;
                    });
                  },
                ),
                ...player.playlists
                    .map((playlist) => _buildPlaylistChip(player, playlist)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistChip(NPlayer player, String playlist) {
    bool allSongsInPlaylist =
        selectedSongs.every((song) => song.playlists.contains(playlist));
    bool someSongsInPlaylist =
        selectedSongs.any((song) => song.playlists.contains(playlist));

    return ActionChip(
      label: Text(playlist),
      avatar: Icon(
        allSongsInPlaylist ? Icons.playlist_add_check : Icons.playlist_add,
        color: Theme.of(context).colorScheme.secondary,
      ),
      onPressed: () {
        if (allSongsInPlaylist) {
          for (var song in selectedSongs) {
            player.removeSongFromPlaylist(playlist, song);
          }
        } else {
          for (var song in selectedSongs) {
            if (!song.playlists.contains(playlist)) {
              player.addSongToPlaylist(playlist, song);
            }
          }
        }
        setState(() {});
      },
      backgroundColor: someSongsInPlaylist
          ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
          : null,
    );
  }
}

class _SongListTile extends StatelessWidget {
  final Music song;
  final bool isCurrentSong;
  final bool isSelected;
  final NPlayer player;
  final Function(Music) onTap;
  final VoidCallback onLongPress;

  const _SongListTile({
    Key? key,
    required this.song,
    required this.isCurrentSong,
    required this.isSelected,
    required this.player,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected
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
            child: song.picture != null
                ? Image.memory(song.picture!, fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.music_note, color: Colors.grey[600]),
                  ),
          ),
        ),
        title: Text(
          song.title,
          style: TextStyle(
            fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
            color: isCurrentSong
                ? Theme.of(context).colorScheme.secondary
                : Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${song.artist} • ${song.genre}',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          Utils.formatMilliseconds(song.duration),
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        onTap: () => onTap(song),
        onLongPress: onLongPress,
        selected: isSelected,
      ),
    );
  }
}
