import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:blossom/custom/search_bar.dart';
import 'package:blossom/tools/settings.dart';
import 'package:blossom/tools/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:blossom/audio/nplayer.dart';
import 'package:blossom/sheets/bottom_sheet.dart';
import 'package:blossom/sheets/create_playlist_sheet.dart';
import 'package:blossom/widgets/playlist_artwork.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({Key? key}) : super(key: key);

  @override
  PlaylistPageState createState() => PlaylistPageState();
}

class PlaylistPageState extends State<PlaylistPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isMounted = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _saveDebounce;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    _animationController = UIHelpers.createFadeAnimationController(this);
    _fadeAnimation = UIHelpers.createFadeAnimation(_animationController);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
        final saved = Settings.playlistScrollPosition;
        if (saved > 0 && _scrollController.hasClients) {
          _scrollController.jumpTo(saved);
        }
      }
    });
  }

  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      Settings.setPlaylistScrollPosition(_scrollController.offset);
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    _saveDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _selectPlaylistImage(
      BuildContext context, NPlayer player, String playlist) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && _isMounted) {
      File imageFile = File(image.path);
      await player.setPlaylistImage(playlist, imageFile);
      if (mounted) {
        _safeSetState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Selector rebuilds only when the playlist list actually changes (add/delete),
    // not on every position update from NPlayer.
    return Selector<NPlayer, List<String>>(
      selector: (_, player) => player.playlists,
      shouldRebuild: (prev, next) =>
          prev.length != next.length || !listEquals(prev, next),
      builder: (context, playlists, child) {
        final player = context.read<NPlayer>();
        List<String> filteredPlaylists = playlists
            .where((playlist) => playlist
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()))
            .toList();

        return Scaffold(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.1),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Search bar with add playlist button
                  OptimizedSearchBar(
                    searchController: _searchController,
                    onSearchChanged: (value) {
                      if (value.length == 1 && _scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                      _safeSetState(() {});
                    },
                    hintText: 'Search playlists...',
                    showSortButton: false,
                    showShuffleButton: false,
                    showSettingsButton: false,
                    trailingWidget: UIHelpers.buildPrimaryIconButton(
                      context,
                      icon: Icons.add_rounded,
                      onTap: () => _showCreatePlaylistDialog(context, player),
                      tooltip: 'Create Playlist',
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: filteredPlaylists.isEmpty
                          ? UIHelpers.buildEmptyState(
                              context,
                              icon: Icons.playlist_play_rounded,
                              title: 'No playlists yet',
                              subtitle: 'Create a playlist to get started',
                              action: ElevatedButton.icon(
                                onPressed: () =>
                                    _showCreatePlaylistDialog(context, player),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create Playlist'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            )
                          : _buildPlaylistGrid(player, filteredPlaylists),
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

  Widget _buildPlaylistGrid(NPlayer player, List<String> playlists) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        String playlist = playlists[index];
        List<Music> playlistSongs = player.getPlaylistSongs(playlist);
        String? imagePath = player.getPlaylistImagePath(playlist);

        return _PlaylistCard(
          playlist: playlist,
          songCount: playlistSongs.length,
          imagePath: imagePath,
          songs: playlistSongs,
          onTap: () => _showPlaylistBottomSheet(
              context, player, playlist, playlistSongs),
          onPlay: () => player.playPlaylistFromIndex(
            playlistSongs,
            0,
            playlistName: playlist,
          ),
          onDelete: () => _showDeletePlaylistDialog(context, player, playlist),
          onImageTap: () => _selectPlaylistImage(context, player, playlist),
        );
      },
    );
  }

  void _showPlaylistBottomSheet(BuildContext context, NPlayer player,
      String playlist, List<Music> songs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MusicBottomSheet(
          title: playlist,
          subtitle: '${songs.length} songs',
          itemCount: songs.length,
          songs: songs,
          onPlayPressed: (song) {
            final currentSongs = player.getPlaylistSongs(playlist);
            int index = currentSongs.indexWhere((s) => s.path == song.path);
            if (index == -1) index = 0;
            player.playPlaylistFromIndex(
              currentSongs,
              index,
              playlistName: playlist,
            );
            Navigator.pop(context);
          },
          isPlaylist: true,
          playlistName: playlist,
          customImagePath: player.getPlaylistImagePath(playlist),
        );
      },
    );
  }

  void openPlaylist(String playlistName) {
    final player = context.read<NPlayer>();
    final playlists = player.playlists;
    final index = playlists.indexOf(playlistName);
    if (index == -1) return;

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      _safeSetState(() {});
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 600 ? 3 : 2;
    final cardWidth = (width - 16 - (crossAxisCount - 1) * 12) / crossAxisCount;
    final cardHeight = cardWidth / 0.85;
    final offset = (index ~/ crossAxisCount) * (cardHeight + 12);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPlaylistBottomSheet(
        context,
        player,
        playlistName,
        player.getPlaylistSongs(playlistName),
      );
    });
  }

  void _showCreatePlaylistDialog(BuildContext context, NPlayer player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePlaylistSheet(
        player: player,
        onPlaylistCreated: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  void _showDeletePlaylistDialog(
      BuildContext context, NPlayer player, String playlist) {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      isDismissible: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  'Delete Playlist',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Are you sure you want to delete "$playlist"?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    player.deletePlaylist(playlist);
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final String playlist;
  final int songCount;
  final String? imagePath;
  final List<Music> songs;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onImageTap;

  const _PlaylistCard({
    Key? key,
    required this.playlist,
    required this.songCount,
    this.imagePath,
    required this.songs,
    required this.onTap,
    required this.onPlay,
    required this.onDelete,
    required this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onImageTap,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: PlaylistArtwork(
                      customImagePath: imagePath,
                      songs: songs,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: onDelete,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          size: 28,
                          color: songs.isNotEmpty
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.3),
                        ),
                        onPressed: songs.isNotEmpty ? onPlay : null,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
