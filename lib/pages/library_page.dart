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
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

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
    print("initState lib/pages/library_page.dart");
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
    final RenderBox? buttonBox = _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;
    
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx - 150,
      buttonPosition.dy + buttonBox.size.height + 8,
      buttonPosition.dx + buttonBox.size.width,
      buttonPosition.dy + buttonBox.size.height + 300,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        _buildPopupMenuItem('title', Icons.abc_rounded, context.read<NPlayer>().sortBy == 'title'),
        _buildPopupMenuItem('artist', Icons.person_rounded, context.read<NPlayer>().sortBy == 'artist'),
        _buildPopupMenuItem('album', Icons.album_rounded, context.read<NPlayer>().sortBy == 'album'),
        
        const PopupMenuDivider(),
        
        _buildPopupMenuItem('favorite', Icons.favorite_rounded, context.read<NPlayer>().sortBy == 'favorite'),
        _buildPopupMenuItem('plays', Icons.play_circle_outline_rounded, context.read<NPlayer>().sortBy == 'plays'),
        
        const PopupMenuDivider(),
        
        _buildPopupMenuItem('duration', Icons.timer_rounded, context.read<NPlayer>().sortBy == 'duration'),
        _buildPopupMenuItem('year', Icons.calendar_today_rounded, context.read<NPlayer>().sortBy == 'year'),
        
        const PopupMenuDivider(),
        
        _buildPopupMenuItem('folder', Icons.folder_rounded, context.read<NPlayer>().sortBy == 'folder'),
        _buildPopupMenuItem('modified', Icons.update_rounded, context.read<NPlayer>().sortBy == 'modified'),
      ],
    ).then((String? value) {
      if (value != null) {
        final player = context.read<NPlayer>();
        if (player.sortBy == value) {
          player.sortSongs(sortBy: value, ascending: !player.sortAscending);
        } else {
          player.sortSongs(sortBy: value);
        }
      }
    });
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
                  // Optimized search bar with integrated controls
                  OptimizedSearchBar(
                    searchController: _searchController,
                    onSearchChanged: (value) => player.setSearchQuery(value),
                    onShowSortMenu: _showSortMenu,
                    onShuffle: _scrollToRandomSong,
                    onSettings: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(
                            onThemeChanged: widget.onThemeChanged,
                          ),
                        ),
                      );
                    },
                    filterButtonKey: _filterButtonKey,
                  ),
                  
                  // Song list
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: player.sortedSongs.isEmpty
                          ? _buildEmptyState()
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

  /// Builds empty state when no songs are available
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some music to get started',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds a popup menu item for sorting options with active state
  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon, bool isActive) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon, 
            size: 18,
            color: isActive ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 10),
          Text(
            _capitalize(value),
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (isActive) ...[
            const Spacer(),
            Icon(
              Icons.check_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  /// Capitalizes the first letter of a string
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
