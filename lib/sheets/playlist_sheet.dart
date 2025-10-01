import 'package:blossom/audio/nplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:blossom/widgets/playlist_artwork.dart';
import 'dart:async';

/// Enhanced bottom sheet for adding songs to playlists
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
  State<PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<PlaylistSheet>
    with TickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TextEditingController _newPlaylistController;
  late final AnimationController _animationController;
  late final AnimationController _searchAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _searchAnimation;

  List<String> _filteredPlaylists = [];
  bool _showNewPlaylistField = false;
  bool _showSearchField = false;
  bool _isCreatingPlaylist = false;
  String _searchQuery = '';
  Timer? _searchDebouncer;

  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _newPlaylistFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _filteredPlaylists = List.from(widget.player.playlists);
    
    // Auto-focus search if many playlists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.player.playlists.length > 10) {
        _toggleSearch();
      }
    });
  }

  void _initializeControllers() {
    _searchController = TextEditingController();
    _newPlaylistController = TextEditingController();
    
    _searchController.addListener(_onSearchChanged);
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    _searchController.dispose();
    _newPlaylistController.dispose();
    _animationController.dispose();
    _searchAnimationController.dispose();
    _searchFocusNode.dispose();
    _newPlaylistFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _filterPlaylists(_searchController.text);
      }
    });
  }

  void _filterPlaylists(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredPlaylists = List.from(widget.player.playlists);
      } else {
        _filteredPlaylists = widget.player.playlists
            .where((playlist) =>
                playlist.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _showSearchField = !_showSearchField;
      if (_showSearchField) {
        _showNewPlaylistField = false;
        _searchAnimationController.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchAnimationController.reverse();
        _searchController.clear();
        _filteredPlaylists = List.from(widget.player.playlists);
      }
    });
  }

  void _toggleNewPlaylist() {
    HapticFeedback.lightImpact();
    setState(() {
      _showNewPlaylistField = !_showNewPlaylistField;
      if (_showNewPlaylistField) {
        _showSearchField = false;
        _searchAnimationController.reverse();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _newPlaylistFocusNode.requestFocus();
        });
      } else {
        _newPlaylistController.clear();
      }
    });
  }

  Future<void> _handlePlaylistAction(String playlist) async {
    HapticFeedback.selectionClick();
    
    // Show confirmation for large selections
    if (widget.selectedSongs.length > 20) {
      final confirmed = await _showConfirmationDialog(
        'Add ${widget.selectedSongs.length} songs to "$playlist"?',
        'This will add all selected songs to the playlist.',
      );
      if (!confirmed) return;
    }

    try {
      widget.onPlaylistAction(widget.player, playlist);
      
      
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {

      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ADD'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _createNewPlaylist() async {
    final name = _newPlaylistController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreatingPlaylist = true);
    HapticFeedback.lightImpact();

    try {
      widget.player.createPlaylist(name);
      
      if (mounted) {
        setState(() {
          _filteredPlaylists = List.from(widget.player.playlists);
          _showNewPlaylistField = false;
          _isCreatingPlaylist = false;
        });
        
        _newPlaylistController.clear();

        // Auto-select the new playlist
        await _handlePlaylistAction(name);
      }
    } catch (e) {

    }
  }

  Widget _buildPlaylistTile(String playlist, int index) {
    final player = widget.player;
    final songs = player.getPlaylistSongs(playlist);
    final imagePath = player.getPlaylistImagePath(playlist);
    final isHighlighted = _searchQuery.isNotEmpty && 
        playlist.toLowerCase().contains(_searchQuery.toLowerCase());

    return AnimatedContainer(
      duration: Duration(milliseconds: 100 + (index * 50)),
      curve: Curves.easeOutCubic,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        elevation: 0,
        color: isHighlighted 
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : Theme.of(context).cardColor,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Hero(
            tag: 'playlist_$playlist',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: PlaylistArtwork(
                  customImagePath: imagePath,
                  songs: songs,
                  size: 48,
                ),
              ),
            ),
          ),
          title: Text(
            playlist,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isHighlighted 
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.add_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          onTap: () => _handlePlaylistAction(playlist),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.playlist_add,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No playlists found'
                : 'No playlists yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Create your first playlist to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _toggleNewPlaylist,
              icon: const Icon(Icons.add),
              label: const Text('Create Playlist'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 600;
    final keyboardVisible = bottomPadding > 0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Container(
              width: isDesktop ? screenSize.width * 0.4 : screenSize.width,
              constraints: BoxConstraints(
                maxWidth: 600,
                minWidth: 300,
                maxHeight: screenSize.height * (keyboardVisible ? 0.6 : 0.8),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 8,
                    ),
                    child: _buildHeader(isDesktop),
                  ),

                  // Search/New Playlist Fields
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Column(
                      children: [
                        if (_showSearchField) _buildSearchField(),
                        if (_showNewPlaylistField) _buildNewPlaylistField(),
                      ],
                    ),
                  ),

                  // Playlist List
                  Flexible(
                    child: _filteredPlaylists.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: bottomPadding + 16,
                              top: 8,
                            ),
                            itemCount: _filteredPlaylists.length,
                            itemBuilder: (context, index) {
                              return _buildPlaylistTile(_filteredPlaylists[index], index);
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to Playlist',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.selectedSongs.length} ${widget.selectedSongs.length == 1 ? 'song' : 'songs'} selected',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _buildActionButtons(isDesktop),
      ],
    );
  }

  Widget _buildActionButtons(bool isDesktop) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          icon: const Icon(Icons.deselect),
          iconSize: isDesktop ? 22 : 20,
          tooltip: 'Deselect all',
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onDeselectAll();
            Navigator.pop(context);
          },
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          icon: Icon(_showSearchField ? Icons.search_off : Icons.search),
          iconSize: isDesktop ? 22 : 20,
          tooltip: _showSearchField ? 'Hide search' : 'Search playlists',
          onPressed: _toggleSearch,
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: Icon(_showNewPlaylistField ? Icons.close : Icons.add),
          iconSize: isDesktop ? 22 : 20,
          tooltip: _showNewPlaylistField ? 'Cancel' : 'New playlist',
          onPressed: _toggleNewPlaylist,
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return SizeTransition(
      sizeFactor: _searchAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search playlists...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filteredPlaylists = List.from(widget.player.playlists);
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }

  Widget _buildNewPlaylistField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newPlaylistController,
              focusNode: _newPlaylistFocusNode,
              decoration: InputDecoration(
                hintText: 'Enter playlist name...',
                prefixIcon: const Icon(Icons.playlist_add),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createNewPlaylist(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isCreatingPlaylist ? null : _createNewPlaylist,
            icon: _isCreatingPlaylist
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isCreatingPlaylist ? 'Creating...' : 'Create'),
          ),
        ],
      ),
    );
  }
}
