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
      buttonPosition.dx - 150, // Offset to align better with button
      buttonPosition.dy + buttonBox.size.height + 8, // Position below button with padding
      buttonPosition.dx + buttonBox.size.width,
      buttonPosition.dy + buttonBox.size.height + 300, // Max height for menu
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        // Primary metadata
        _buildPopupMenuItem('title', Icons.abc_rounded, context.read<NPlayer>().sortBy == 'title'),
        _buildPopupMenuItem('artist', Icons.person_rounded, context.read<NPlayer>().sortBy == 'artist'),
        _buildPopupMenuItem('album', Icons.album_rounded, context.read<NPlayer>().sortBy == 'album'),
        
        const PopupMenuDivider(),
        
        // User engagement (favorite moved here from quick actions)
        _buildPopupMenuItem('favorite', Icons.favorite_rounded, context.read<NPlayer>().sortBy == 'favorite'),
        _buildPopupMenuItem('plays', Icons.play_circle_outline_rounded, context.read<NPlayer>().sortBy == 'plays'),
        
        const PopupMenuDivider(),
        
        // Technical metadata
        _buildPopupMenuItem('duration', Icons.timer_rounded, context.read<NPlayer>().sortBy == 'duration'),
        _buildPopupMenuItem('year', Icons.calendar_today_rounded, context.read<NPlayer>().sortBy == 'year'),
        
        const PopupMenuDivider(),
        
        // File system
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

  /// Builds the integrated search bar with filter functionality
  Widget _buildIntegratedSearchBar(NPlayer player) {
    final currentSort = _capitalize(player.sortBy);
    final sortDirection = player.sortAscending ? '↑' : '↓';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main search row
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => player.setSearchQuery(value),
                    decoration: InputDecoration(
                      hintText: 'Search songs...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // Clear search button (only show when there's text)
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      player.setSearchQuery('');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.clear_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Filter/Sort button integrated into search bar
                Material(
                  key: _filterButtonKey,
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showSortMenu,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            player.sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Subtle current filter indicator
          if (player.sortBy.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sorted by $currentSort $sortDirection',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${player.sortedSongs.length} ${player.sortedSongs.length == 1 ? 'song' : 'songs'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the compact header with settings and shuffle button
  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            'Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Shuffle button moved to header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _scrollToRandomSong,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.shuffle_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Settings button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        // Listen to search controller changes
        _searchController.addListener(() {
          setState(() {});
        });

        return Scaffold(
          // Changed background to be more seamless
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Compact header with shuffle and settings buttons
                  _buildCompactHeader(),
                  
                  // Integrated search bar with filter
                  _buildIntegratedSearchBar(player),
                  
                  // Song list - seamless (shuffle button removed from here)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
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

  /// Builds the song list with your existing SongListBuilder (seamless background)
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
}

/// Capitalizes the first letter of a string
String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
