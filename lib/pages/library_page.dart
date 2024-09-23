import 'package:blossom/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import 'package:blossom/custom/custom_song_list_builder.dart';

class SongLibrary extends StatefulWidget {
  final VoidCallback onThemeChanged;

  const SongLibrary({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  _SongLibraryState createState() => _SongLibraryState();
}

class _SongLibraryState extends State<SongLibrary> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = Provider.of<NPlayer>(context, listen: false);
      player.sortSongs(sortBy: 'title', ascending: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              decoration: const InputDecoration(
                hintText: 'Search songs...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                player.setSearchQuery(value);
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(
                        onThemeChanged: widget.onThemeChanged,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 15),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort by',
                onSelected: (String value) {
                  if (player.sortBy == value) {
                    player.sortSongs(
                        sortBy: value, ascending: !player.sortAscending);
                  } else {
                    player.sortSongs(sortBy: value);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    _buildPopupMenuItem('title', Icons.abc_rounded),
                    _buildPopupMenuItem('artist', Icons.person_rounded),
                    _buildPopupMenuItem('album', Icons.album_rounded),
                    _buildPopupMenuItem('duration', Icons.timer_rounded),
                    _buildPopupMenuItem('folder', Icons.folder_rounded),
                    _buildPopupMenuItem('last modified', Icons.update_rounded),
                  ];
                },
              ),
              const SizedBox(width: 20),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: OrientationBuilder(
                builder: (context, orientation) {
                  return SongListBuilder(
                    songs: player.sortedSongs,
                    orientation: orientation,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(_capitalize(value)),
        ],
      ),
    );
  }
}


String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
