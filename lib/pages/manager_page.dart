import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../song_list/manager_song_list.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({Key? key}) : super(key: key);

  @override
  _ManagerPageState createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final filteredSongs = _searchQuery.isEmpty
            ? player.allSongs
            : player.allSongs
                .where((song) =>
                    song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    song.artist.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    song.album.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Song Manager'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search songs...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ),
            ),
          ),
          body: OrientationBuilder(
            builder: (context, orientation) {
              return ManagerSongList(
                songs: filteredSongs,
                orientation: orientation,
              );
            },
          ),
        );
      },
    );
  }
}
