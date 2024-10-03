import 'dart:async';
import 'package:blossom/dialog/playlist_dialog.dart';
import 'package:blossom/song_list/song_list_tile_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

class SongListBuilder extends StatefulWidget {
  final List<Music> songs;
  final bool isPlayingList;
  final void Function(Music)? onTap;
  final bool isPlaylist;
  final Orientation? orientation;

  const SongListBuilder({
    Key? key,
    required this.songs,
    this.isPlayingList = false,
    this.onTap,
    this.isPlaylist = false,
    required this.orientation,
  }) : super(key: key);

  @override
  SongListBuilderState createState() => SongListBuilderState();
}

class SongListBuilderState extends State<SongListBuilder> {
  Set<Music> selectedSongs = {};
  int? lastSelectedIndex;
  ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;
  double _scrollVelocity = 0.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _debouncedScroll(void Function() callback) {
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();

    // Adjust debounce duration based on scroll velocity
    int debounceDuration = _calculateDebounceDuration(_scrollVelocity);

    _scrollDebounce = Timer(Duration(milliseconds: debounceDuration), callback);
  }

  int _calculateDebounceDuration(double velocity) {
    // Base duration
    int baseDuration = 15;
    //print(velocity);
    // Adjust duration based on velocity
    if (velocity > 2500) {
      return (baseDuration * 3).round(); // Longer debounce for fast scrolls
    } else if (velocity > 100) {
      return (baseDuration * 1.5).round(); // Longer debounce for fast scrolls
    } else if (velocity > 20) {
      return baseDuration;
    } else {
      return (baseDuration * 0.75).round(); // Shorter debounce for slow scrolls
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      _scrollVelocity = notification.scrollDelta?.abs() ?? 0.0;
      _debouncedScroll(() {
        if (mounted) {
          setState(() {
            // Trigger a rebuild
          });
        }
      });
    } else if (notification is ScrollEndNotification) {
      _scrollVelocity = 0.0;
      // Ensure we update the state when scrolling ends
      if (mounted) {
        setState(() {});
      }
    }
    return false;
  }

  void scrollToPosition(double position) {
    _scrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: widget.songs.length,
                  itemExtent: 80,
                  itemBuilder: (BuildContext context, int index) {
                    final song = widget.songs[index];
                    return SongListTileWrapper(
                      key: ValueKey(song.path),
                      song: song,
                      isCurrentSong: song == player.getCurrentSong(),
                      isSelected: selectedSongs.contains(song),
                      onTap: () => _handleTap(song),
                      onLongPress: () => _handleLongPress(index),
                    );
                  },
                ),
              ),
            ),
            if (selectedSongs.isNotEmpty)
              Positioned(
                right: 16,
                bottom: 100,
                child: FloatingActionButton(
                  onPressed: () => _showPlaylistDialog(context, player),
                  child: const Icon(Icons.playlist_add),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showPlaylistDialog(BuildContext context, NPlayer player) {
    showDialog(
      context: context,
      barrierDismissible: true, // This allows tapping away to close
      builder: (BuildContext context) {
        return PlaylistDialog(
          selectedSongs: selectedSongs,
          player: player,
          onPlaylistAction: _handlePlaylistAction,
          onDeselectAll: () {
            if (mounted) {
              setState(() {
                selectedSongs.clear();
              });
            }
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _handlePlaylistAction(NPlayer player, String playlist) {
    bool allSongsInPlaylist =
        selectedSongs.every((song) => song.playlists.contains(playlist));

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
    if (mounted) {
      setState(() {});
    }
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
    if (mounted) {
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
  }
}
