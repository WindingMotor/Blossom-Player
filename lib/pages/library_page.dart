/// Library Page - Main interface for browsing and managing music library
/// Provides functionality for:
/// - Displaying all songs in the library
/// - Sorting and filtering songs
/// - Searching through the music collection
/// - Managing playback queue

import 'dart:math';
import 'package:blossom/custom/custom_searchbar.dart';
import 'package:blossom/sheets/server_sheet.dart';
import 'package:blossom/song_list/song_list_builder.dart';
import 'package:blossom/tools/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import 'package:blossom/pages/settings_page.dart';
import '../pages/manager_page.dart';

/// Main widget for the song library interface
/// Manages the display and interaction with the user's music collection
class SongLibrary extends StatefulWidget {
  /// Callback function triggered when theme changes
  final VoidCallback onThemeChanged;

  const SongLibrary({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  _SongLibraryState createState() => _SongLibraryState();
}

/// State management for the SongLibrary widget
/// Handles:
/// - Song list initialization
/// - Sort preferences
/// - Search functionality
/// - UI interactions
class _SongLibraryState extends State<SongLibrary> {
  /// Key for accessing the SongListBuilder state
  final GlobalKey<SongListBuilderState> _songListBuilderKey =
      GlobalKey<SongListBuilderState>();

  @override
  void initState() {
    super.initState();
    // Initialize song list with sort preferences after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = Provider.of<NPlayer>(context, listen: false);
      player.loadSortSettings().then((_) {
        player.sortSongs(
          sortBy: Settings.songSortBy, 
          ascending: Settings.songSortAscending
        );
        if (mounted) {
          setState(() {}); // Refresh UI after applying sort settings
        }
      });
    });
    print("initState lib/pages/library_page.dart");
  }

  /// Displays the server connection sheet
  /// Used for managing remote music sources
  void _showServerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ServerSheet(),
    );
  }

  /// Scrolls to a random song in the library
  /// Provides quick access to random music selection
  void _scrollToRandomSong() {
    final songListBuilderState = _songListBuilderKey.currentState;
    if (songListBuilderState != null) {
      final player = Provider.of<NPlayer>(context, listen: false);
      final songCount = player.sortedSongs.length;
      if (songCount > 0) {
        final random = Random();
        final randomIndex = random.nextInt(songCount);
        final itemExtent = 80.0; // Assuming each item has a fixed height of 80
        final scrollPosition = randomIndex * itemExtent;
        songListBuilderState.scrollToPosition(scrollPosition);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        return Scaffold(
          appBar: CustomSearchBar(
            hintText: 'Search songs...',
            onChanged: (value) {
              player.setSearchQuery(value);
            },
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
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Song Manager',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ManagerPage(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.hardware_rounded),
                tooltip: 'Server',
                onPressed: _showServerSheet, // Show the ServerSheet
              ),
              IconButton(
                icon: const Icon(Icons.shuffle),
                tooltip: 'Scroll to random song',
                onPressed: _scrollToRandomSong,
              ),
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
                    // Primary metadata
                    _buildPopupMenuItem('title', Icons.abc_rounded),
                    _buildPopupMenuItem('artist', Icons.person_rounded),
                    _buildPopupMenuItem('album', Icons.album_rounded),
                    
                    // User engagement
                    _buildPopupMenuItem('favorite', Icons.favorite_rounded),
                    _buildPopupMenuItem('plays', Icons.play_circle_outline_rounded),
                    
                    // Technical metadata
                    _buildPopupMenuItem('duration', Icons.timer_rounded),
                    _buildPopupMenuItem('year', Icons.calendar_today_rounded),
                    
                    // File system
                    _buildPopupMenuItem('folder', Icons.folder_rounded),
                    _buildPopupMenuItem('modified', Icons.update_rounded),
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
                    key: _songListBuilderKey,
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

  /// Builds a popup menu item for sorting options
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

/// Capitalizes the first letter of a string
String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
