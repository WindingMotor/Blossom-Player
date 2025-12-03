/// Library Page - Main interface for browsing and managing music library
/// Provides functionality for:
/// - Displaying all songs in the library
/// - Sorting and filtering songs
/// - Searching through the music collection
/// - Managing playback queue

import 'dart:math';
import 'package:blossom/custom/search_bar.dart';
import 'package:blossom/song_list/song_list_builder.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import 'package:blossom/pages/settings_page.dart';

/// Main widget for the song library interface
class SongLibrary extends StatefulWidget {
  /// Callback function triggered when theme changes
  final VoidCallback onThemeChanged;

  const SongLibrary({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  _SongLibraryState createState() => _SongLibraryState();
}

/// State management for the SongLibrary widget
class _SongLibraryState extends State<SongLibrary> with TickerProviderStateMixin {
  /// Key for accessing the SongListBuilder state
  final GlobalKey<SongListBuilderState> _songListBuilderKey =
      GlobalKey<SongListBuilderState>();

  /// Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  /// Text controller for search input
  final TextEditingController _searchController = TextEditingController();
  
  /// Global key for the filter button to properly anchor the popup menu
  final GlobalKey _filterButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    // Initialize animations using helper
    _animationController = UIHelpers.createFadeAnimationController(this);
    _fadeAnimation = UIHelpers.createFadeAnimation(_animationController);

    // Initialize song list with sort preferences after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = Provider.of<NPlayer>(context, listen: false);
      player.loadSortSettings().then((_) {
        player.sortSongs(
          sortBy: Settings.songSortBy, 
          ascending: Settings.songSortAscending
        );
        if (mounted) {
          setState(() {});
          _animationController.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Scrolls to a random song in the library
  void _scrollToRandomSong() {
    final songListBuilderState = _songListBuilderKey.currentState;
    if (songListBuilderState != null) {
      final player = Provider.of<NPlayer>(context, listen: false);
      final songCount = player.sortedSongs.length;
      if (songCount > 0) {
        final random = Random();
        final randomIndex = random.nextInt(songCount);
        final itemExtent = 80.0;
        final scrollPosition = randomIndex * itemExtent;
        songListBuilderState.scrollToPosition(scrollPosition);
      }
    }
  }

  /// Shows the sort menu with proper positioning relative to filter button
  void _showSortMenu() {
    final player = context.read<NPlayer>();
    
    UIHelpers.showSortMenu(
      context,
      buttonKey: _filterButtonKey,
      items: [
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'title',
          icon: Icons.abc_rounded,
          isActive: player.sortBy == 'title',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'artist',
          icon: Icons.person_rounded,
          isActive: player.sortBy == 'artist',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'album',
          icon: Icons.album_rounded,
          isActive: player.sortBy == 'album',
        ),
        const PopupMenuDivider(),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'favorite',
          icon: Icons.favorite_rounded,
          isActive: player.sortBy == 'favorite',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'plays',
          icon: Icons.play_circle_outline_rounded,
          isActive: player.sortBy == 'plays',
        ),
        const PopupMenuDivider(),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'duration',
          icon: Icons.timer_rounded,
          isActive: player.sortBy == 'duration',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'year',
          icon: Icons.calendar_today_rounded,
          isActive: player.sortBy == 'year',
        ),
        const PopupMenuDivider(),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'folder',
          icon: Icons.folder_rounded,
          isActive: player.sortBy == 'folder',
        ),
        UIHelpers.buildPopupMenuItem(
          context,
          value: 'modified',
          icon: Icons.update_rounded,
          isActive: player.sortBy == 'modified',
        ),
      ],
    ).then((String? value) {
      if (value != null) {
        if (player.sortBy == value) {
          player.sortSongs(sortBy: value, ascending: !player.sortAscending);
        } else {
          player.sortSongs(sortBy: value);
        }
      }
    });
  }

  /// Builds the trailing widget with sort, shuffle, and settings buttons
  Widget _buildTrailingButtons() {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final currentSort = UIHelpers.capitalize(player.sortBy);
        final sortDirection = player.sortAscending ? '↑' : '↓';
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filter/Sort button
            UIHelpers.buildSortButton(
              context,
              key: _filterButtonKey,
              onTap: _showSortMenu,
              sortAscending: player.sortAscending,
              tooltip: 'Sorted by $currentSort $sortDirection',
            ),
            
            const SizedBox(width: 8),
            
            // Shuffle button
            UIHelpers.buildIconButton(
              context,
              icon: Icons.shuffle_rounded,
              onTap: _scrollToRandomSong,
              tooltip: 'Shuffle',
            ),
            
            const SizedBox(width: 4),
            
            // Settings button
            UIHelpers.buildIconButton(
              context,
              icon: Icons.settings_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
              tooltip: 'Settings',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Optimized search bar with trailing buttons
                  OptimizedSearchBar(
                    searchController: _searchController,
                    onSearchChanged: (value) => player.setSearchQuery(value),
                    trailingWidget: _buildTrailingButtons(),
                  ),
                  
                  // Song list
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: player.sortedSongs.isEmpty
                          ? UIHelpers.buildEmptyState(
                              context,
                              icon: Icons.music_note_outlined,
                              title: 'No songs found',
                              subtitle: 'Add some music to get started',
                            )
                          : _buildSongList(player),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the song list
  Widget _buildSongList(NPlayer player) {
    return GestureDetector(
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
    );
  }
}