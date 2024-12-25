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
            title: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search songs...',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Add some spacing between search bar and exit button
              ],
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
